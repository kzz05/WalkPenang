/**
 * WalkPenang — content moderation.
 *
 * Three functions:
 *
 *   moderateReview      Firestore trigger  — removes a profane review
 *   moderateNickname    Firestore trigger  — reverts a profane display name
 *   moderateProfileImage  callable         — screens a photo before it is public
 *
 * WHY THE TEXT ONES ARE TRIGGERS AND THE IMAGE ONE IS NOT
 *
 * Reviews and nicknames are written straight to Firestore by the client, so
 * the only way to enforce anything after a bypass is to react to the write.
 * That is eventually consistent: a bypassing client's text is visible for the
 * seconds until the trigger fires. It does not survive, which is the point.
 *
 * A photo cannot be handled that way. `photoUrl` is copied into
 * `leaderboard/{uid}`, which every signed-in user can read, and the download
 * URL is stable across uploads, so `cached_network_image` would keep serving a
 * withdrawn photo from other people's devices indefinitely. A few seconds of
 * exposure is not acceptable for that, so images are quarantined instead: the
 * client uploads to `pending_profile_images/`, which no client can read, and
 * this function promotes the file to `profile_images/` only once it is clean.
 * Storage rules make `profile_images/` unwritable by clients, so quarantine is
 * the only way in.
 *
 * WHAT THE IMAGE CHECK DOES NOT COVER
 *
 * Cloud Vision SafeSearch exposes five signals — adult, racy, medical,
 * violence, spoof. Nudity and gore map onto those. There is NO
 * offensive-gesture signal, so a raised middle finger passes. No comparable
 * off-the-shelf API has one; detecting it would need a custom-trained gesture
 * model. This is a known, documented gap, not an oversight.
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentWritten} =
    require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

const {firstMatch} = require("./profanity");

/** Callables live here, matching the OTP functions the app already calls. */
const REGION = "us-central1";

/**
 * Firestore triggers live where the database lives.
 *
 * The walkpenang-5cefb database is in asia-southeast1, and a trigger in
 * us-central1 means every review write crosses the Pacific twice before the
 * moderation check runs — latency on exactly the path where the window between
 * "published" and "removed" should be as short as possible. Deploying them here
 * also stops the CLI warning about trigger/function region mismatch.
 *
 * The callable above stays in us-central1 on purpose: the Flutter client uses
 * the default FirebaseFunctions.instance, which resolves to us-central1.
 */
const TRIGGER_REGION = "asia-southeast1";

/** Where the client uploads. No client can read this prefix. */
const PENDING_PREFIX = "pending_profile_images";

/** Where moderated photos live. No client can write this prefix. */
const PUBLIC_PREFIX = "profile_images";

/** One tourist per display name. See claimNickname and ensureNicknameReserved. */
const NICKNAMES_COLLECTION = "nicknames";

/**
 * SafeSearch verdicts that reject a photo.
 *
 * POSSIBLE is deliberately not included: on a corpus of ordinary selfies it
 * fires often enough that legitimate photos would be refused, and a moderation
 * system that rejects real users' faces is worse than one that misses an edge
 * case.
 */
const REJECT_LIKELIHOODS = new Set(["LIKELY", "VERY_LIKELY"]);

/**
 * Where the Gemini check runs, and which model.
 *
 * Vertex mode rather than the Gemini Developer API: it authenticates with this
 * function's own service account, so there is no API key to keep as a secret,
 * and it reads the image straight from gs:// exactly as the Vision client does.
 *
 * The SDK is @google/genai, NOT @google-cloud/vertexai. The latter was the
 * obvious choice by name and is the one most examples still show, but it was
 * deprecated on 2025-06-24 with a stated removal date of 2026-06-24 — already
 * in the past. It still installs and runs, which is precisely what makes it a
 * trap.
 *
 * Swap GEMINI_MODEL if the deploy reports an unknown model for this region —
 * it is deliberately the only place the id appears.
 */
const VERTEX_LOCATION = "us-central1";
const GEMINI_MODEL = "gemini-2.5-flash";

/**
 * What Gemini is asked to judge, and — just as importantly — what it must NOT
 * reject.
 *
 * SafeSearch cannot see gestures: it classifies adult, racy, medical, violence
 * and spoof, and a raised middle finger is none of those. That gap is the whole
 * reason this second check exists.
 *
 * The permit list is not padding. A profile picture IS a photo of a person's
 * face, often close-up, sometimes in swimwear on a Penang beach. A model that
 * refuses those is worse than no check at all — the same reasoning that keeps
 * the profanity wordlist matching on whole words.
 */
const GEMINI_PROMPT = [
  "You are moderating a profile picture for a tourism app.",
  "",
  "REJECT the image if it contains any of:",
  "- an offensive or obscene hand gesture (raised middle finger, and similar)",
  "- nudity, partial nudity, or sexual content",
  "- blood, gore, injury, or graphic violence",
  "- hate symbols or extremist imagery",
  "- text that is profane or abusive",
  "",
  "ALLOW everything else. In particular, ALLOW:",
  "- an ordinary photo of a person, including a close-up face or selfie",
  "- people in everyday or beach clothing, including swimwear",
  "- ordinary hand gestures such as a wave, thumbs up, peace sign or OK sign",
  "- pets, food, scenery, cartoons, avatars, or an empty/abstract image",
  "",
  "If you are unsure, ALLOW. Wrongly rejecting a real person's photo is worse",
  "than letting a borderline one through.",
  "",
  "Answer with JSON only, in exactly this shape:",
  '{"allowed": true|false, "category": "gesture|nudity|violence|hate|' +
    'profanity|other", "reason": "<short explanation>"}',
  "Use category \"other\" when allowed is true.",
].join("\n");

/** Categories Gemini may return, and how each is described to the tourist. */
const GEMINI_CATEGORIES = {
  gesture: "an offensive gesture",
  nudity: "nudity or sexual content",
  violence: "violent or graphic content",
  hate: "hate or extremist imagery",
  profanity: "offensive text",
  other: "content unsuitable for a profile picture",
};

/**
 * Asks Gemini whether the image at gcsUri is suitable.
 *
 * Throws on any transport, quota or parse failure so the caller can fail
 * closed — a verdict that could not be obtained must never read as "allowed".
 *
 * @param {string} gcsUri gs:// URI of the pending image
 * @return {Promise<{allowed: boolean, category: string, reason: string}>} verdict
 */
async function geminiVerdict(gcsUri) {
  const {GoogleGenAI} = require("@google/genai");

  const ai = new GoogleGenAI({
    vertexai: true,
    project: process.env.GCLOUD_PROJECT,
    location: VERTEX_LOCATION,
  });

  const response = await ai.models.generateContent({
    model: GEMINI_MODEL,
    contents: [
      {
        role: "user",
        parts: [
          {fileData: {fileUri: gcsUri, mimeType: "image/jpeg"}},
          {text: GEMINI_PROMPT},
        ],
      },
    ],
    config: {
      temperature: 0,
      // JSON mime type, but no responseSchema: sending one alongside a gs://
      // image made Vertex return a bare 500 INTERNAL on every request. The
      // shape is stated in the prompt instead and validated below, which lands
      // in the same place — a reply that is not the expected shape throws, and
      // the caller fails closed.
      responseMimeType: "application/json",
    },
  });

  const text = response.text;
  if (!text) throw new Error("Gemini returned no content");

  const parsed = JSON.parse(text);
  if (typeof parsed.allowed !== "boolean") {
    throw new Error("Gemini verdict had no boolean 'allowed'");
  }
  if (!Object.prototype.hasOwnProperty.call(GEMINI_CATEGORIES,
      parsed.category)) {
    // Unknown category is not fatal — the verdict is what matters, and the
    // caller maps an unrecognised category to the generic wording.
    parsed.category = "other";
  }
  return parsed;
}

/**
 * Categories checked, and how each is described back to the user.
 *
 * `medical` is included because gore and injury imagery frequently lands there
 * rather than under `violence`. `spoof` is excluded — it flags memes and
 * doctored images, which are not what this is for.
 */
const CHECKED_CATEGORIES = {
  adult: "nudity or sexual content",
  racy: "suggestive content",
  violence: "violent or graphic content",
  medical: "graphic medical content",
};

/**
 * Removes a review whose text or author name is profane.
 *
 * The client already refused this text in ReviewSubmissionModal.validate, so
 * reaching here means the check was bypassed. Deleting rather than redacting:
 * a review is one person's short opinion, and a redacted stub on a place page
 * is noise nobody can act on.
 */
exports.moderateReview = onDocumentCreated(
    {document: "reviews/{reviewId}", region: TRIGGER_REGION},
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const review = snapshot.data() || {};
      const hit = firstMatch(review.body) || firstMatch(review.authorName);
      if (!hit) return;

      await snapshot.ref.delete();
      logger.warn("Removed a profane review", {
        reviewId: event.params.reviewId,
        userId: review.userId || "(unowned)",
        placeId: review.placeId,
        term: hit,
      });
    },
);

/**
 * Reverts a profane nickname, and clears the public copy of it.
 *
 * The name lives in two places: `users/{uid}.nickname`, which only its owner
 * can read, and `leaderboard/{uid}.displayName`, which every signed-in user
 * can. Clearing only the first would leave the offending name on the public
 * board until the tourist's next check-in republished it.
 */
exports.moderateNickname = onDocumentWritten(
    {document: "users/{uid}", region: TRIGGER_REGION},
    async (event) => {
      const after = event.data && event.data.after;
      if (!after || !after.exists) return;

      const nickname = (after.data() || {}).nickname;
      const hit = firstMatch(nickname);
      if (!hit) return;

      const before = event.data.before;
      const previous = before && before.exists ?
        (before.data() || {}).nickname :
        null;

      // Fall back to the previous name when it was clean, so a tourist who
      // edits a good name into a bad one keeps the good one rather than
      // losing their identity entirely.
      const replacement = previous && !firstMatch(previous) ? previous : "";

      await after.ref.update({nickname: replacement});

      // "Walker" is kDefaultWalkerName in leaderboard_entry_model.dart — the
      // same fallback FirestoreLeaderboardDao uses for a blank nickname.
      await admin.firestore()
          .collection("leaderboard")
          .doc(event.params.uid)
          .set({displayName: replacement || "Walker"}, {merge: true})
          .catch(() => {
            // No leaderboard row yet is the normal case for a tourist who has
            // not walked. Nothing to clean up.
          });

      logger.warn("Reverted a profane nickname", {
        uid: event.params.uid,
        term: hit,
        revertedTo: replacement || "(cleared)",
      });
    },
);

/**
 * Screens the caller's pending profile photo and promotes it if it is clean.
 *
 * Takes no arguments on purpose — it operates on the calling uid's own pending
 * object, so nobody can aim it at another user's upload.
 *
 * Vision reads the image straight from GCS by URI, so this function never
 * downloads the bytes; a multi-megabyte photo costs no function memory.
 *
 * @return {Promise<{photoUrl: string}>} the public download URL
 */
exports.moderateProfileImage = onCall(
    {region: REGION, memory: "512MiB", timeoutSeconds: 60},
    async (request) => {
      const uid = request.auth && request.auth.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "Sign in first.");
      }

      // Required lazily so the two OTP functions in index.js do not pay the
      // Vision client's cold-start cost.
      const vision = require("@google-cloud/vision");

      const bucket = admin.storage().bucket();
      const pendingPath = `${PENDING_PREFIX}/${uid}.jpg`;
      const pending = bucket.file(pendingPath);

      const [exists] = await pending.exists();
      if (!exists) {
        throw new HttpsError(
            "not-found",
            "No photo was uploaded. Try again.",
        );
      }

      let result;
      try {
        const client = new vision.ImageAnnotatorClient();
        [result] = await client.safeSearchDetection(
            `gs://${bucket.name}/${pendingPath}`,
        );
      } catch (error) {
        // Fail closed: an unscreened photo must not reach the public prefix
        // just because the API was unavailable.
        await pending.delete().catch(() => {});
        logger.error("SafeSearch call failed", {uid, error: error.message});
        throw new HttpsError(
            "unavailable",
            "Could not check the photo right now. Please try again.",
        );
      }

      const annotation = result.safeSearchAnnotation || {};

      // Logged on every path, approvals included. Without this an approval was
      // just {"message":"Profile photo approved"}, so "why did this pass?"
      // could only be answered by reading the code — which is exactly the
      // question a middle-finger photo getting through produced.
      const safeSearch = {
        adult: annotation.adult || "UNKNOWN",
        racy: annotation.racy || "UNKNOWN",
        violence: annotation.violence || "UNKNOWN",
        medical: annotation.medical || "UNKNOWN",
      };

      const tripped = Object.keys(CHECKED_CATEGORIES).find((category) =>
        REJECT_LIKELIHOODS.has(annotation[category]),
      );

      if (tripped) {
        await pending.delete().catch(() => {});
        logger.warn("Rejected a profile photo", {
          uid,
          by: "safesearch",
          category: tripped,
          likelihood: annotation[tripped],
          safeSearch,
        });
        throw new HttpsError(
            "invalid-argument",
            `This photo looks like it contains ${CHECKED_CATEGORIES[tripped]}. ` +
            "Please choose a different one.",
        );
      }

      // SafeSearch is clean. It cannot see gestures, so ask Gemini — this is
      // the check that catches a raised middle finger, which no SafeSearch
      // category covers. Run second because SafeSearch is cheaper and faster,
      // so the common rejection never reaches the model.
      let gemini;
      try {
        gemini = await geminiVerdict(`gs://${bucket.name}/${pendingPath}`);
      } catch (error) {
        // Fail closed, like the SafeSearch path above. A Vertex outage
        // blocking new photos is recoverable by retrying; an unscreened photo
        // reaching profile_images/ is not — the URL lands in the world-readable
        // leaderboard row and in every device's image cache.
        await pending.delete().catch(() => {});
        logger.error("Gemini check failed", {uid, error: error.message});
        throw new HttpsError(
            "unavailable",
            "Could not check the photo right now. Please try again.",
        );
      }

      if (!gemini.allowed) {
        await pending.delete().catch(() => {});
        logger.warn("Rejected a profile photo", {
          uid,
          by: "gemini",
          category: gemini.category,
          reason: gemini.reason,
          safeSearch,
        });
        // The model's own reason is logged but not shown: it is free text from
        // a model and may be oddly worded or describe what it saw.
        const described = GEMINI_CATEGORIES[gemini.category] ||
          GEMINI_CATEGORIES.other;
        throw new HttpsError(
            "invalid-argument",
            `This photo looks like it contains ${described}. ` +
            "Please choose a different one.",
        );
      }

      // Clean — promote it. A fresh token means the new URL differs from the
      // old one, which is what busts cached_network_image's disk cache on
      // every other device.
      const token = admin.firestore().collection("_").doc().id;
      const publicPath = `${PUBLIC_PREFIX}/${uid}.jpg`;

      await pending.copy(bucket.file(publicPath), {
        metadata: {
          contentType: "image/jpeg",
          metadata: {firebaseStorageDownloadTokens: token},
        },
      });
      await pending.delete().catch(() => {});

      const photoUrl =
        `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
        `${encodeURIComponent(publicPath)}?alt=media&token=${token}`;

      logger.info("Profile photo approved", {
        uid,
        safeSearch,
        gemini: {category: gemini.category, reason: gemini.reason},
      });
      return {photoUrl};
    },
);

/**
 * Mirrors a tourist's display name and photo into `public_profiles/{uid}`.
 *
 * WHY THIS COLLECTION EXISTS
 *
 * A review has to show its author's CURRENT name and picture — rename yourself
 * and every review you ever wrote should follow. The obvious source,
 * `users/{uid}`, is owner-only in firestore.rules and holds email, phone
 * number, weight and height, so it can never be read by a stranger. This is the
 * two-field projection that can.
 *
 * `leaderboard/{uid}` could not serve the same purpose: publishEntry skips
 * anyone with zero points, so a tourist who reviewed a place but never walked
 * has no row, and it requires sign-in to read while reviews are world-readable.
 *
 * WHY IT IS A SEPARATE TRIGGER FROM moderateNickname
 *
 * That function returns early when the nickname is clean. Mirroring from inside
 * it would propagate only PROFANE edits — precisely backwards. Both trigger on
 * the same document write, which is fine and keeps each one about one thing.
 *
 * The two compose correctly on a revert: moderateNickname writes the clean name
 * back to `users/{uid}`, and that write re-fires this trigger, so the
 * projection ends up correct without either function knowing about the other.
 */
exports.syncPublicProfile = onDocumentWritten(
    {document: "users/{uid}", region: TRIGGER_REGION},
    async (event) => {
      const uid = event.params.uid;
      const ref = admin.firestore().collection("public_profiles").doc(uid);

      const after = event.data && event.data.after;

      // The tourist deleted their account. Leaving the projection behind would
      // keep their name and face on reviews after the profile it mirrors is
      // gone.
      if (!after || !after.exists) {
        await ref.delete().catch(() => {});
        await releaseNicknamesOf(uid);
        return;
      }

      const data = after.data() || {};
      const nickname = typeof data.nickname === "string" ?
        data.nickname.trim() :
        "";
      const photoUrl = typeof data.photoUrl === "string" ?
        data.photoUrl.trim() :
        "";

      // Checked here as well as in moderateNickname, on purpose. Without it
      // there is a window where a profane name sits in a world-readable
      // document until the revert lands and re-fires this trigger. The check is
      // two string comparisons; the window is not worth keeping.
      const clean = !nickname || !firstMatch(nickname);

      // "Walker" is kDefaultWalkerName in leaderboard_entry_model.dart and
      // PublicProfile.defaultName, so a blank name reads the same everywhere.
      await ref.set(
          {
            displayName: clean && nickname ? nickname : "Walker",
            photoUrl: photoUrl || null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
      );

      if (clean && nickname) {
        await ensureNicknameReserved(uid, nickname);
      }
    },
);

/**
 * Drops every reservation held by [uid]. Used when the account is deleted.
 *
 * @param {string} uid the account whose reservations should be freed
 * @return {Promise<void>} resolves once they are gone
 */
async function releaseNicknamesOf(uid) {
  const db = admin.firestore();
  try {
    const held = await db
        .collection(NICKNAMES_COLLECTION)
        .where("uid", "==", uid)
        .get();
    await Promise.all(held.docs.map((doc) => doc.ref.delete()));
  } catch (error) {
    logger.error("Could not release nicknames", {uid, error: error.message});
  }
}

/**
 * Makes sure [nickname] is reserved for [uid], healing any gap left by a write
 * that did not go through claimNickname.
 *
 * WHY THIS EXISTS
 *
 * claimNickname protects a name from the moment it is claimed — but a name
 * already sitting in users/{uid} before the reservation system existed was
 * never registered, so the server saw it as free and a second account could
 * take it. That is not hypothetical: two accounts ended up holding "IanWong",
 * because the reservation backfill had only been dry-run.
 *
 * This hook removes the dependency on that one operational step. Any name that
 * reaches users/{uid} by ANY route is protected on the next write.
 *
 * WHAT IT MUST NEVER DO
 *
 * Steal. If the name is held by a different account, that account keeps it and
 * this logs a warning. Two accounts genuinely holding one name is a state only
 * a human can arbitrate — a background trigger silently reassigning names would
 * be far worse than the gap it is closing.
 *
 * @param {string} uid the account the name belongs to
 * @param {string} nickname the name as stored on the profile
 * @return {Promise<void>} resolves once the reservation is settled
 */
async function ensureNicknameReserved(uid, nickname) {
  if (nickname.includes("/") || nickname === "." || nickname === "..") return;

  const db = admin.firestore();
  const wanted = db.collection(NICKNAMES_COLLECTION).doc(nickname);

  try {
    await db.runTransaction(async (tx) => {
      const existing = await tx.get(wanted);
      const owner = existing.exists ? (existing.data() || {}).uid : null;

      if (owner && owner !== uid) {
        // Somebody else holds it. Leave it alone — see the note above.
        logger.warn("Nickname already held by another account", {
          uid,
          nickname,
          heldBy: owner,
        });
        return;
      }

      // All reads before any write, as Firestore transactions require.
      const held = await tx.get(
          db.collection(NICKNAMES_COLLECTION).where("uid", "==", uid),
      );

      // A rename that bypassed claimNickname would otherwise strand the old
      // name, reserved to somebody who no longer uses it.
      held.docs.forEach((doc) => {
        if (doc.id !== nickname) tx.delete(doc.ref);
      });

      if (!existing.exists) {
        tx.set(wanted, {
          uid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });
  } catch (error) {
    // Never fail the profile sync over this. The public profile is already
    // written by the time this runs, and a missed reservation is healed by the
    // next write to the document.
    logger.error("Could not reserve nickname", {
      uid,
      nickname,
      error: error.message,
    });
  }
}

/**
 * Shape rules, mirrored from Validators.nickname / ValidationMessages.
 *
 * Re-checked here rather than trusted from the client for the usual reason:
 * the form's checks are a courtesy to the person typing, not a control. They
 * also keep a name that the app would refuse from occupying a reservation.
 */
const NICKNAME_MIN = 2;
const NICKNAME_MAX = 30;
const NICKNAME_PATTERN = /^[\p{L}\p{M}0-9 .'_-]+$/u;
const NICKNAME_HAS_LETTER = /\p{L}/u;

/**
 * Reserves the caller's display name, releasing whichever one they held.
 *
 * CASE-SENSITIVE BY DECISION. The document id is the name exactly as typed and
 * Firestore ids are case-sensitive, so "Ianwong" and "IANwong" are different
 * names and both may exist. Only an exact clash is refused.
 *
 * WHY A TRANSACTION
 *
 * A client that read nicknames/{name} and then wrote it would race any other
 * client doing the same: two simultaneous registrations could both see the
 * name free and both write it, and the second silently wins. Reading and
 * writing inside one transaction makes exactly one caller succeed.
 *
 * WHY THE OLD NAME IS FOUND BY QUERY
 *
 * The previous reservation is located with `where uid == caller` rather than by
 * reading users/{uid}.nickname. The profile write happens AFTER this call and
 * can fail — an orphaned reservation pointing at a name the profile no longer
 * claims would then lock the tourist out of renaming. Querying the reservations
 * themselves keeps this collection self-consistent whatever happens downstream.
 */
exports.claimNickname = onCall(
    {region: REGION},
    async (request) => {
      const uid = request.auth && request.auth.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "Sign in first.");
      }

      const raw = request.data && request.data.nickname;
      const nickname = typeof raw === "string" ? raw.trim() : "";

      if (nickname.length < NICKNAME_MIN || nickname.length > NICKNAME_MAX) {
        throw new HttpsError(
            "invalid-argument",
            `Name must be ${NICKNAME_MIN}-${NICKNAME_MAX} characters.`,
        );
      }
      if (!NICKNAME_PATTERN.test(nickname) ||
          !NICKNAME_HAS_LETTER.test(nickname)) {
        throw new HttpsError(
            "invalid-argument",
            "Name can only use letters, numbers, spaces and . ' - _",
        );
      }
      if (firstMatch(nickname)) {
        throw new HttpsError(
            "invalid-argument",
            "Please choose a different name.",
        );
      }
      // A name is a document id here, so it must not contain a slash or be a
      // path traversal token. The pattern above already excludes "/", and the
      // letter requirement excludes "." and "..", but assert it rather than
      // rely on that reasoning holding if the pattern is ever widened.
      if (nickname.includes("/") || nickname === "." || nickname === "..") {
        throw new HttpsError("invalid-argument", "That name cannot be used.");
      }

      const db = admin.firestore();
      const wanted = db.collection(NICKNAMES_COLLECTION).doc(nickname);

      await db.runTransaction(async (tx) => {
        const existing = await tx.get(wanted);
        if (existing.exists && (existing.data() || {}).uid !== uid) {
          throw new HttpsError(
              "already-exists",
              "That name is already taken. Try a different one.",
          );
        }

        // Every read must happen before any write in a Firestore transaction.
        const held = await tx.get(
            db.collection(NICKNAMES_COLLECTION).where("uid", "==", uid),
        );

        held.docs.forEach((doc) => {
          if (doc.id !== nickname) tx.delete(doc.ref);
        });

        tx.set(wanted, {
          uid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      logger.info("Nickname claimed", {uid, nickname});
      return {claimed: nickname};
    },
);

/**
 * Whether [nickname] is free for the caller. Reads only; reserves nothing.
 *
 * Feeds the inline "that name is already taken" message that appears under the
 * field as the tourist types. claimNickname remains the authority — this exists
 * so the answer arrives before Save rather than after it.
 *
 * A name reserved to the CALLER counts as available. Otherwise opening your own
 * profile and not touching your name would report it as taken, which is both
 * wrong and alarming.
 *
 * Auth-gated, so an anonymous caller cannot probe the collection. A signed-in
 * caller learns whether one specific name exists, which is the same thing the
 * register form tells them anyway; nicknames/ itself stays unreadable by every
 * client, so the collection cannot be enumerated.
 */
exports.checkNicknameAvailable = onCall(
    {region: REGION},
    async (request) => {
      const uid = request.auth && request.auth.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "Sign in first.");
      }

      const raw = request.data && request.data.nickname;
      const nickname = typeof raw === "string" ? raw.trim() : "";

      // Shape is the client's job here — an unusable name is simply not
      // "available", and the synchronous validator has already told the user
      // why. Guarding the document id is still required.
      if (!nickname ||
          nickname.includes("/") ||
          nickname === "." ||
          nickname === "..") {
        return {available: false};
      }

      const doc = await admin.firestore()
          .collection(NICKNAMES_COLLECTION)
          .doc(nickname)
          .get();

      const owner = doc.exists ? (doc.data() || {}).uid : null;
      return {available: owner === null || owner === uid};
    },
);
