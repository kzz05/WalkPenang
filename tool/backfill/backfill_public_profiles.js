#!/usr/bin/env node
/**
 * One-off backfill: writes `public_profiles/{uid}` for every existing user.
 *
 * WHY THIS IS NEEDED
 * ------------------
 * Reviews resolve their author's name and photo from `public_profiles/{uid}`
 * so that renaming yourself updates reviews you wrote months ago. That
 * projection is maintained going forward by the `syncPublicProfile` Cloud
 * Function, which fires when `users/{uid}` is written.
 *
 * But existing users will not write their profile again any time soon, so
 * without this their past reviews keep showing the stale snapshotted name —
 * which is the exact bug the projection was built to fix. The trigger covers
 * the future; this covers the past.
 *
 * WHY THE ADMIN SDK
 * -----------------
 * `public_profiles` is `allow write: if false` in firestore.rules — no client
 * may write it, so a display name cannot be forged. The Admin SDK bypasses
 * rules, which is the only way in, and is also how the function writes it.
 *
 * SAFETY
 * ------
 * Idempotent — doc id is the uid and writes use {merge: true}. Never deletes,
 * never touches `users/`. Skips a profane nickname rather than publishing it
 * to a world-readable document, matching what syncPublicProfile does. Pass
 * --dry-run to see what it would write.
 *
 * SETUP — same service account key as the leaderboard backfill:
 *   npm install
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node backfill_public_profiles.js --dry-run
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node backfill_public_profiles.js
 */

const admin = require("firebase-admin");

// The same filter the Cloud Function uses, so the backfill cannot publish a
// name the running app would have refused.
const {firstMatch} = require("../../functions/profanity");

const USERS_COLLECTION = "users";
const PUBLIC_PROFILES_COLLECTION = "public_profiles";
const NICKNAME_FIELD = "nickname";
const PHOTO_URL_FIELD = "photoUrl";
const DISPLAY_NAME_FIELD = "displayName";
const UPDATED_AT_FIELD = "updatedAt";

/** PublicProfile.defaultName / kDefaultWalkerName. */
const DEFAULT_WALKER_NAME = "Walker";

const dryRun = process.argv.includes("--dry-run");

async function main() {
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.error(
        "GOOGLE_APPLICATION_CREDENTIALS is not set.\n" +
        "Point it at a service account key — see the header of this file.",
    );
    process.exit(1);
  }

  admin.initializeApp({credential: admin.credential.applicationDefault()});
  const db = admin.firestore();

  console.log(`${dryRun ? "DRY RUN — " : ""}reading ${USERS_COLLECTION}/ ...`);
  const users = await db.collection(USERS_COLLECTION).get();
  console.log(`  ${users.size} user document(s) found.\n`);

  let written = 0;
  let skippedProfane = 0;

  for (const doc of users.docs) {
    const data = doc.data() || {};

    const rawName = typeof data[NICKNAME_FIELD] === "string" ?
      data[NICKNAME_FIELD].trim() :
      "";
    const photoUrl = typeof data[PHOTO_URL_FIELD] === "string" ?
      data[PHOTO_URL_FIELD].trim() :
      "";

    const hit = rawName ? firstMatch(rawName) : null;
    if (hit) {
      // Publishing this would put a profane name in a world-readable document.
      // moderateNickname will deal with the user document itself.
      console.log(`  SKIP   ${doc.id}  (name blocked: "${hit}")`);
      skippedProfane += 1;
      continue;
    }

    const displayName = rawName || DEFAULT_WALKER_NAME;

    const existing = await db
        .collection(PUBLIC_PROFILES_COLLECTION)
        .doc(doc.id)
        .get();

    console.log(
        `  ${existing.exists ? "update" : "CREATE"} ${doc.id}  ` +
        `${displayName}${photoUrl ? "  (has photo)" : "  (no photo)"}`,
    );

    if (!dryRun) {
      await db
          .collection(PUBLIC_PROFILES_COLLECTION)
          .doc(doc.id)
          .set(
              {
                [DISPLAY_NAME_FIELD]: displayName,
                [PHOTO_URL_FIELD]: photoUrl || null,
                [UPDATED_AT_FIELD]:
                  admin.firestore.FieldValue.serverTimestamp(),
              },
              {merge: true},
          );
    }
    written += 1;
  }

  console.log(
      `\n${dryRun ? "Would write" : "Wrote"} ${written} projection(s).\n` +
      `  skipped (profane name): ${skippedProfane}`,
  );

  if (dryRun) {
    console.log("\nDry run — nothing was written. Re-run without --dry-run.");
  }
}

main().then(
    () => process.exit(0),
    (error) => {
      console.error("\nBackfill failed:", error);
      process.exit(1);
    },
);
