# Email OTP — setup and deployment

The app no longer verifies email addresses with a Firebase link. It now mails a
6-digit code and checks it server-side.

```
OtpVerificationView  →  OtpVerificationController  →  OtpService
                                                         │
                                          Cloud Functions │ (functions/index.js)
                                                         ▼
                                 sendEmailOtp  ·  verifyEmailOtp
                                          │              │
                                    Gmail SMTP      Admin SDK sets
                                                    emailVerified = true
```

`emailVerified` stays the source of truth, so `LoadingController` and
`OnboardingController` needed no changes — they already branch on it.

## Why the code can't be generated in the app

1. A code generated on the device can be read off the device, so it proves
   nothing about who owns the mailbox.
2. SMTP credentials in an APK are credentials you've given away.
3. Only the Admin SDK can set `emailVerified` on a user.

Firestore never stores the code itself — only an HMAC-SHA256 of it, peppered
with a secret. `firestore.rules` denies all client access to `email_otps`.

---

## Prerequisites

**Cloud Functions require the Blaze plan.** It is pay-as-you-go with a free
monthly allowance (2M invocations) that a student project will not come close
to exhausting, but Google requires a card on file. Upgrade at
Firebase console → ⚙️ → Usage and billing → Modify plan.

There is no way around this: the Spark (free) plan cannot deploy functions.

## 1. Get a Gmail app password

The functions send mail through Gmail SMTP.

1. The sending Google account must have **2-Step Verification** turned on.
2. Go to <https://myaccount.google.com/apppasswords>.
3. Create an app password named `walkpenang`.
4. Copy the 16-character value — spaces don't matter.

> Gmail caps sending at ~500 messages/day. Fine for development and marking.
> For anything real, swap `service: "gmail"` in `functions/index.js` for
> SendGrid, Mailgun, or Resend.

## 2. Install dependencies

```bash
cd functions
npm install
cd ..
```

## 3. Set the three secrets

```bash
firebase functions:secrets:set SMTP_USER    # your.address@gmail.com
firebase functions:secrets:set SMTP_PASS    # the 16-char app password
firebase functions:secrets:set OTP_PEPPER   # any long random string
```

Generate a pepper with:

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

The pepper is what stops a leaked hash from being brute-forced offline — there
are only a million 6-digit codes, so an unpeppered hash falls in under a second.
Set it once and don't change it, or every code in flight becomes invalid.

## 4. Deploy

```bash
firebase deploy --only functions
```

⚠️ **Check `firestore.rules` before deploying it.** The file in this repo grants
each user access to `users/{their own uid}` and denies everything on
`email_otps`. If your console currently runs open test-mode rules, deploying
will tighten them — which is correct, but verify it matches how your teammates'
modules read Firestore first.

```bash
firebase deploy --only firestore:rules
```

## 5. Try it

```bash
flutter run
```

Register with a real address you can read. The code arrives within a few
seconds; type it into the six boxes.

Watch the server side with:

```bash
firebase functions:log --only sendEmailOtp,verifyEmailOtp
```

---

## Behaviour

| Rule | Value | Where |
|---|---|---|
| Code lifetime | 10 minutes | `CODE_TTL_MS` |
| Resend cooldown | 30 seconds | `RESEND_COOLDOWN_MS` (mirrored in the controller) |
| Wrong attempts allowed | 5, then the code dies | `MAX_ATTEMPTS` |
| Code length | 6 digits, `crypto.randomInt` | `generateCode()` |

Every failure path the user can hit — wrong code, expired code, too many
attempts, resend too soon, server unreachable — has a specific message that
renders in the black panel under the digit boxes.

## Troubleshooting

**`unavailable` / "not deployed yet"** — the functions aren't live. Run
`firebase deploy --only functions` and confirm the region is `us-central1`,
which is what `OtpService` connects to.

**No email arrives** — check `firebase functions:log`. Usually a wrong app
password, or 2FA not enabled on the sending account.

**"No code is waiting"** — the document was consumed or expired. Tap resend.

**Verified, but the app still asks for a code** — `OtpService.verifyCode()`
calls `reload()` and `getIdToken(true)` to refresh the cached token. If you
changed that, the client keeps its stale `emailVerified: false`.

## Reverting to email links

The old screens are in git history:

```bash
git show HEAD:lib/views/verify_email_view.dart
git show HEAD:lib/controllers/verify_email_controller.dart
```

Restore both, put `sendVerificationEmail()` back in `AuthService`, and point
`loading_view.dart` and `onboarding_view.dart` at `VerifyEmailView` again.
