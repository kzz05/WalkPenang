#!/usr/bin/env node
/**
 * One-off backfill: writes a `leaderboard/{uid}` row for every user who has
 * already earned points but is not on the board.
 *
 * WHY THIS EXISTS
 * ---------------
 * The leaderboard is a read model. `FirestoreLeaderboardDao.fetchTopEntries`
 * queries the `leaderboard` collection and never looks at `users/`, so points
 * on a user document are invisible to the board until something mirrors them
 * across. Two things were supposed to do that, and for a long time neither
 * did for anybody but the signed-in tourist:
 *
 *   - Publish on award was wired out: JourneySession built its RewardController
 *     without a leaderboardDao, so _publishStanding returned immediately on
 *     every check-in. (Fixed in lib/controllers/journey_session.dart.)
 *   - Publish on screen open only ever writes your own row, because
 *     firestore.rules allows `create, update` on leaderboard/{userId} only
 *     `if isOwner(userId)`.
 *
 * That rule is also why this cannot be a Dart client script like
 * tool/seed_places.dart: no signed-in client may write another user's row.
 * The Admin SDK bypasses rules, so this runs as admin.
 *
 * SAFETY
 * ------
 * Idempotent — the document id is the uid and writes use {merge: true}, so
 * re-running produces the same rows. It never deletes, never touches `users/`,
 * and skips anyone with no points (matching the DAO's own `totalPoints <= 0`
 * guard, which exists so a wall of zeroes does not enrol people who have not
 * walked). Pass --dry-run to see what it would write without writing.
 *
 * SETUP
 * -----
 *   1. Download a service account key (project is owned by a teammate; the
 *      console account with access is /u/2):
 *      https://console.firebase.google.com/u/2/project/walkpenang-5cefb/settings/serviceaccounts/adminsdk
 *   2. npm install            (in this directory)
 *   3. GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node backfill_leaderboard.js --dry-run
 *      GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node backfill_leaderboard.js
 *
 * The key grants full rule-bypassing access to the whole database. Keep it
 * outside the repo; .gitignore covers the usual filenames as a backstop.
 */

const admin = require("firebase-admin");

// Mirrored from lib/utils/reward_constants.dart and
// lib/models/leaderboard_entry_model.dart. Kept as literals because this is a
// throwaway Node script that cannot import the Dart constants — the parity
// test in test/reward/ asserts these names still match what the app writes.
const USERS_COLLECTION = "users";
const LEADERBOARD_COLLECTION = "leaderboard";
const DISPLAY_NAME_FIELD = "displayName";
const NICKNAME_FIELD = "nickname";
const PHOTO_URL_FIELD = "photoUrl";
const TOTAL_POINTS_FIELD = "totalPoints";
const TOTAL_CHECK_INS_FIELD = "totalCheckIns";
const TOTAL_DISTANCE_METRES_FIELD = "totalDistanceMetres";
const UPDATED_AT_FIELD = "updatedAt";

/** lib/models/leaderboard_entry_model.dart:24 */
const DEFAULT_WALKER_NAME = "Walker";

const dryRun = process.argv.includes("--dry-run");

/** Reads an int field defensively, the way RewardModel.fromMap does. */
function readInt(data, field) {
  const value = data[field];
  return typeof value === "number" && Number.isFinite(value)
    ? Math.trunc(value)
    : 0;
}

/**
 * Same normalisation as FirestoreLeaderboardDao.publishEntry: a blank nickname
 * would otherwise land in the collection as an empty name and every client
 * would have to defend against it.
 */
function normaliseName(raw) {
  const trimmed = typeof raw === "string" ? raw.trim() : "";
  return trimmed.length === 0 ? DEFAULT_WALKER_NAME : trimmed;
}

function normalisePhotoUrl(raw) {
  const trimmed = typeof raw === "string" ? raw.trim() : "";
  return trimmed.length === 0 ? null : trimmed;
}

async function main() {
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.error(
      "GOOGLE_APPLICATION_CREDENTIALS is not set.\n" +
        "Point it at a service account key — see the header of this file."
    );
    process.exit(1);
  }

  admin.initializeApp({credential: admin.credential.applicationDefault()});
  const db = admin.firestore();

  console.log(
    `${dryRun ? "DRY RUN — " : ""}reading ${USERS_COLLECTION}/ ...`
  );

  const users = await db.collection(USERS_COLLECTION).get();
  console.log(`  ${users.size} user document(s) found.\n`);

  let written = 0;
  let skippedNoPoints = 0;
  let alreadyOnBoard = 0;

  for (const doc of users.docs) {
    const data = doc.data() || {};
    const totalPoints = readInt(data, TOTAL_POINTS_FIELD);

    if (totalPoints <= 0) {
      skippedNoPoints += 1;
      continue;
    }

    const existing = await db
      .collection(LEADERBOARD_COLLECTION)
      .doc(doc.id)
      .get();
    if (existing.exists) alreadyOnBoard += 1;

    const row = {
      [DISPLAY_NAME_FIELD]: normaliseName(data[NICKNAME_FIELD]),
      [PHOTO_URL_FIELD]: normalisePhotoUrl(data[PHOTO_URL_FIELD]),
      [TOTAL_POINTS_FIELD]: totalPoints,
      [TOTAL_CHECK_INS_FIELD]: readInt(data, TOTAL_CHECK_INS_FIELD),
      [TOTAL_DISTANCE_METRES_FIELD]: readInt(
        data,
        TOTAL_DISTANCE_METRES_FIELD
      ),
    };

    console.log(
      `  ${existing.exists ? "update" : "CREATE"} ${doc.id}  ` +
        `${row[DISPLAY_NAME_FIELD]} — ${totalPoints} pts, ` +
        `${row[TOTAL_CHECK_INS_FIELD]} check-ins`
    );

    if (!dryRun) {
      await db
        .collection(LEADERBOARD_COLLECTION)
        .doc(doc.id)
        .set(
          {
            ...row,
            [UPDATED_AT_FIELD]:
              admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true}
        );
    }
    // Counted in both modes, so a dry run reports the same number the real
    // run will write instead of a placeholder.
    written += 1;
  }

  console.log(
    `\n${dryRun ? "Would write" : "Wrote"} ${written} row(s).\n` +
      `  skipped (no points): ${skippedNoPoints}\n` +
      `  already had a row:   ${alreadyOnBoard}`
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
  }
);
