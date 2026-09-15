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
      const tripped = Object.keys(CHECKED_CATEGORIES).find((category) =>
        REJECT_LIKELIHOODS.has(annotation[category]),
      );

      if (tripped) {
        await pending.delete().catch(() => {});
        logger.warn("Rejected a profile photo", {
          uid,
          category: tripped,
          likelihood: annotation[tripped],
        });
        throw new HttpsError(
            "invalid-argument",
            `This photo looks like it contains ${CHECKED_CATEGORIES[tripped]}. ` +
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

      logger.info("Profile photo approved", {uid});
      return {photoUrl};
    },
);
