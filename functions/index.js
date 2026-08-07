/**
 * WalkPenang — email OTP verification.
 *
 * Two callable functions replace Firebase's built-in email *link* verification
 * with a 6-digit code:
 *
 *   sendEmailOtp()          → generates a code, emails it, stores only a hash
 *   verifyEmailOtp({code})  → checks the code, then flips emailVerified
 *
 * Why this has to live on a server:
 *
 *   1. A code generated in the app could simply be read out of the app by
 *      whoever is holding the phone, which verifies nothing.
 *   2. Sending mail needs SMTP credentials, which must never ship in an APK.
 *   3. Only the Admin SDK can set `emailVerified` on a user.
 *
 * The payoff for keeping `emailVerified` as the source of truth is that the
 * rest of the app is untouched — LoadingController and OnboardingController
 * already branch on `user.emailVerified`, and they keep working as-is.
 */

const crypto = require("crypto");
const nodemailer = require("nodemailer");

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

const admin = require("firebase-admin");

admin.initializeApp();

// ── Secrets (set with `firebase functions:secrets:set NAME`) ────────────────
const SMTP_USER = defineSecret("SMTP_USER");
const SMTP_PASS = defineSecret("SMTP_PASS");

/**
 * Peppers the stored hash. Without it, a leaked hash could be brute-forced
 * offline in under a second — there are only a million 6-digit codes.
 */
const OTP_PEPPER = defineSecret("OTP_PEPPER");

// ── Tunables ────────────────────────────────────────────────────────────────
const CODE_TTL_MS = 10 * 60 * 1000; // code is good for 10 minutes
const RESEND_COOLDOWN_MS = 30 * 1000; // matches the timer in the app
const MAX_ATTEMPTS = 5; // wrong guesses before the code dies

const COLLECTION = "email_otps";

/** HMAC so the stored value is useless without the pepper. */
function hashCode(code, uid, pepper) {
  return crypto
      .createHmac("sha256", pepper)
      .update(`${uid}:${code}`)
      .digest("hex");
}

/** Cryptographically random, unlike Math.random(). */
function generateCode() {
  return String(crypto.randomInt(0, 1000000)).padStart(6, "0");
}

/** Constant-time compare, so timing can't leak the code. */
function safeEqual(a, b) {
  const bufA = Buffer.from(a, "utf8");
  const bufB = Buffer.from(b, "utf8");
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

function buildTransport(user, pass) {
  return nodemailer.createTransport({
    service: "gmail",
    auth: {user, pass},
  });
}

function emailTemplate(code) {
  return {
    subject: `${code} is your WalkPenang verification code`,
    text:
      `Your WalkPenang verification code is ${code}.\n\n` +
      "It expires in 10 minutes. If you didn't request this, ignore this email.",
    html: `
      <div style="font-family:system-ui,-apple-system,Segoe UI,sans-serif;
                  background:#FFF3EA;padding:32px;border-radius:10px;
                  max-width:420px;margin:0 auto;color:#111111">
        <p style="font-family:ui-monospace,SFMono-Regular,Menlo,monospace;
                  font-size:11px;letter-spacing:1.6px;text-transform:uppercase;
                  color:#8A6A55;margin:0 0 8px">WalkPenang · verification</p>
        <h1 style="font-size:26px;margin:0 0 20px">Your code</h1>
        <div style="background:#000000;color:#ffffff;border-radius:10px;
                    padding:20px;text-align:center;font-size:34px;
                    letter-spacing:10px;font-weight:700">${code}</div>
        <p style="font-size:15px;line-height:1.5;margin:20px 0 0">
          Enter this in the app to finish signing in. It expires in 10 minutes.
        </p>
        <p style="font-size:13px;color:#8A6A55;margin:16px 0 0">
          Didn't request it? You can safely ignore this email.
        </p>
      </div>`,
  };
}

/**
 * Issues a fresh code and emails it to the signed-in user's own address.
 *
 * The address is read from the auth record rather than from the request, so a
 * caller can't have codes mailed to somebody else's inbox.
 */
exports.sendEmailOtp = onCall(
    {secrets: [SMTP_USER, SMTP_PASS, OTP_PEPPER], region: "us-central1"},
    async (request) => {
      const uid = request.auth && request.auth.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "Sign in first.");
      }

      const user = await admin.auth().getUser(uid);
      if (!user.email) {
        throw new HttpsError(
            "failed-precondition",
            "This account has no email address.",
        );
      }
      if (user.emailVerified) {
        return {alreadyVerified: true, email: user.email};
      }

      const db = admin.firestore();
      const ref = db.collection(COLLECTION).doc(uid);
      const now = Date.now();

      // Throttle resends so the mailbox can't be flooded.
      const existing = await ref.get();
      if (existing.exists) {
        const sentAt = existing.data().sentAt || 0;
        const waited = now - sentAt;
        if (waited < RESEND_COOLDOWN_MS) {
          throw new HttpsError(
              "resource-exhausted",
              `Wait ${Math.ceil((RESEND_COOLDOWN_MS - waited) / 1000)}s ` +
            "before requesting another code.",
          );
        }
      }

      const code = generateCode();

      await ref.set({
        codeHash: hashCode(code, uid, OTP_PEPPER.value()),
        expiresAt: now + CODE_TTL_MS,
        sentAt: now,
        attempts: 0,
      });

      const {subject, text, html} = emailTemplate(code);
      try {
        await buildTransport(SMTP_USER.value(), SMTP_PASS.value()).sendMail({
          from: `WalkPenang <${SMTP_USER.value()}>`,
          to: user.email,
          subject,
          text,
          html,
        });
      } catch (err) {
        // Don't leave a live code behind for an email that never went out.
        await ref.delete();
        logger.error("OTP send failed", {uid, error: err.message});
        throw new HttpsError(
            "internal",
            "Could not send the verification email. Try again shortly.",
        );
      }

      logger.info("OTP sent", {uid});
      return {sent: true, email: user.email, expiresInMs: CODE_TTL_MS};
    },
);

/**
 * Checks a submitted code and, on success, marks the account verified.
 */
exports.verifyEmailOtp = onCall(
    {secrets: [OTP_PEPPER], region: "us-central1"},
    async (request) => {
      const uid = request.auth && request.auth.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "Sign in first.");
      }

      const code = String((request.data && request.data.code) || "").trim();
      if (!/^\d{6}$/.test(code)) {
        throw new HttpsError("invalid-argument", "Enter all 6 digits.");
      }

      const db = admin.firestore();
      const ref = db.collection(COLLECTION).doc(uid);
      const snapshot = await ref.get();

      if (!snapshot.exists) {
        throw new HttpsError(
            "not-found",
            "No code is waiting. Request a new one.",
        );
      }

      const {codeHash, expiresAt, attempts} = snapshot.data();

      if (Date.now() > expiresAt) {
        await ref.delete();
        throw new HttpsError(
            "deadline-exceeded",
            "That code expired. Request a new one.",
        );
      }

      if (attempts >= MAX_ATTEMPTS) {
        await ref.delete();
        throw new HttpsError(
            "resource-exhausted",
            "Too many wrong attempts. Request a new code.",
        );
      }

      const submitted = hashCode(code, uid, OTP_PEPPER.value());
      if (!safeEqual(submitted, codeHash)) {
        const used = attempts + 1;
        await ref.update({attempts: used});
        const left = MAX_ATTEMPTS - used;
        throw new HttpsError(
            "permission-denied",
            left > 0 ?
          `Incorrect code. ${left} attempt${left === 1 ? "" : "s"} left.` :
          "Too many wrong attempts. Request a new code.",
        );
      }

      // 🔑 Only the Admin SDK can do this, which is the whole reason the
      // verification step has to happen server-side.
      await admin.auth().updateUser(uid, {emailVerified: true});
      await ref.delete();

      logger.info("OTP verified", {uid});
      return {verified: true};
    },
);
