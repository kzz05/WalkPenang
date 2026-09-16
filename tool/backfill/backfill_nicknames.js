#!/usr/bin/env node
/**
 * One-off backfill: reserves the display name every existing user already has.
 *
 * WHY THIS IS NEEDED
 * ------------------
 * Uniqueness is enforced by the `claimNickname` callable, which reserves
 * `nicknames/{name}`. That covers everyone who registers or renames from now
 * on — but existing users have never called it, so their names sit unreserved.
 * Without this, the first person to type "IanWong" takes it from the account
 * currently using it, and both then appear under the same name.
 *
 * CASE-SENSITIVE, matching the callable: the document id is the name exactly as
 * stored, so "Ianwong" and "IANwong" are separate reservations.
 *
 * SAFETY
 * ------
 * Idempotent — doc id is the name, writes use {merge: true}. Never deletes.
 * Skips a name that is already reserved by a DIFFERENT uid rather than stealing
 * it, and reports the clash: if two existing accounts already share a name, no
 * script can decide which one should keep it, so that needs a human.
 * Pass --dry-run to see what it would do.
 *
 * SETUP — same service account key as the other backfills:
 *   npm install
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node backfill_nicknames.js --dry-run
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node backfill_nicknames.js
 */

const admin = require("firebase-admin");

// The same filter the callable runs, so the backfill cannot reserve a name the
// app itself would refuse.
const {firstMatch} = require("../../functions/profanity");

const USERS_COLLECTION = "users";
const NICKNAMES_COLLECTION = "nicknames";
const NICKNAME_FIELD = "nickname";

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

  let reserved = 0;
  let skippedBlank = 0;
  let skippedProfane = 0;
  const clashes = [];

  for (const doc of users.docs) {
    const data = doc.data() || {};
    const nickname = typeof data[NICKNAME_FIELD] === "string" ?
      data[NICKNAME_FIELD].trim() :
      "";

    if (!nickname) {
      console.log(`  skip   ${doc.id}  (no nickname set)`);
      skippedBlank += 1;
      continue;
    }

    const hit = firstMatch(nickname);
    if (hit) {
      console.log(`  SKIP   ${doc.id}  "${nickname}" (blocked: "${hit}")`);
      skippedProfane += 1;
      continue;
    }

    if (nickname.includes("/")) {
      console.log(`  SKIP   ${doc.id}  "${nickname}" (illegal as a document id)`);
      continue;
    }

    const ref = db.collection(NICKNAMES_COLLECTION).doc(nickname);
    const existing = await ref.get();

    if (existing.exists && (existing.data() || {}).uid !== doc.id) {
      // Two accounts already hold the same name. Whoever is reserved first
      // would win by accident of iteration order, which is not a decision a
      // script should make.
      console.log(
          `  CLASH  "${nickname}" — held by ${existing.data().uid}, ` +
        `also used by ${doc.id}`,
      );
      clashes.push({nickname, held: existing.data().uid, also: doc.id});
      continue;
    }

    console.log(
        `  ${existing.exists ? "ok    " : "RESERVE"} ${doc.id}  "${nickname}"`,
    );

    if (!dryRun && !existing.exists) {
      await ref.set({
        uid: doc.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    if (!existing.exists) reserved += 1;
  }

  console.log(
      `\n${dryRun ? "Would reserve" : "Reserved"} ${reserved} name(s).\n` +
    `  skipped (no nickname):  ${skippedBlank}\n` +
    `  skipped (blocked name): ${skippedProfane}\n` +
    `  clashes needing a human decision: ${clashes.length}`,
  );

  if (clashes.length) {
    console.log(
        "\nResolve each clash by renaming one of the accounts, then re-run.",
    );
  }
  if (dryRun) {
    console.log("\nDry run — nothing was written. Re-run without --dry-run.");
  }
}

main().then(() => process.exit(0), (error) => {
  console.error("\nBackfill failed:", error);
  process.exit(1);
});
