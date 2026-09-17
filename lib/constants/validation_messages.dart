/// The rules that govern every form field in the authentication and
/// edit-profile screens, plus the copy shown when a field breaks one.
///
/// Limits and messages sit together deliberately: the messages interpolate the
/// limits, so the wording can never drift from the rule it describes.
/// [Validators] is the only place these are applied — views and controllers
/// reference this class instead of inlining string literals or magic numbers.
class ValidationMessages {
  const ValidationMessages._();

  // ── Limits ────────────────────────────────────────────────────────────────

  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 64;

  /// Length at which the strength meter stops saying "good" and says "strong".
  /// Anything shorter still passes the policy — this is the recommendation,
  /// not the requirement.
  static const int passwordStrongLength = 12;

  static const int nicknameMinLength = 2;
  static const int nicknameMaxLength = 30;

  /// The longest address allowed by RFC 5321.
  static const int emailMaxLength = 254;

  // Whole numbers so the messages below can interpolate them directly; the
  // parsed field value is a double and compares against them as `num`.
  static const int heightMinCm = 50;
  static const int heightMaxCm = 250;
  static const int weightMinKg = 20;
  static const int weightMaxKg = 300;

  // The same limits expressed in imperial. Each is rounded *inwards* from the
  // metric bound — up for a minimum, down for a maximum — so that a value the
  // imperial message says is allowed always converts to a metric value inside
  // the range above. Rounding outwards would let the form reject 44 lb while
  // the message beneath it claimed 44 lb was fine.
  //   1ft 8in = 20in = 50.8 cm  (>= 50)      8ft 2in = 98in = 248.9 cm (<= 250)
  //   45 lb   = 20.41 kg        (>= 20)      661 lb  = 299.8 kg        (<= 300)
  // `unit_conversion_test.dart` asserts these four still bracket correctly.
  static const int heightMinFeet = 1;
  static const int heightMinInches = 8;
  static const int heightMaxFeet = 8;
  static const int heightMaxInches = 2;
  static const int weightMinLb = 45;
  static const int weightMaxLb = 661;

  /// Inches are entered as the remainder beside whole feet.
  static const int inchesPerFoot = 12;

  /// E.164 caps a full international number at 15 digits including the country
  /// code. libphonenumber enforces the real per-country rule; this is only the
  /// ceiling on what the keyboard will accept, so a stuck key cannot produce a
  /// hundred-digit field.
  static const int phoneMaxE164Digits = 15;

  static const int otpLength = 6;

  // ── Email ─────────────────────────────────────────────────────────────────

  static const emailRequired = 'Email address is required';
  static const emailInvalid = 'Enter a valid email address, e.g. name@mail.com';
  static const emailTooLong = 'Email address is too long';

  // ── Password ──────────────────────────────────────────────────────────────

  static const passwordRequired = 'Password is required';
  static const passwordTooShort = 'Use at least $passwordMinLength characters';
  static const passwordTooLong =
      'Password cannot be longer than $passwordMaxLength characters';
  static const passwordNoSpaces = 'Password cannot contain spaces';
  static const passwordNeedsLowercase = 'Add at least one lowercase letter';
  static const passwordNeedsUppercase = 'Add at least one uppercase letter';
  static const passwordNeedsDigit = 'Add at least one number';
  static const passwordNeedsSymbol = 'Add at least one symbol, e.g. ! ? @ #';

  /// Checklist labels beside the strength meter. Short enough to fit one line.
  static const requirementLength = '$passwordMinLength+ characters';
  static const requirementCases = 'Upper & lowercase';
  static const requirementDigit = 'A number';
  static const requirementSymbol = 'A symbol';

  /// Strength meter captions.
  static const strengthWeak = 'weak';
  static const strengthFair = 'fair';
  static const strengthGood = 'good';
  static const strengthStrong = 'strong';
  static const strengthHint =
      '$passwordStrongLength+ characters is recommended';

  // ── Nickname ──────────────────────────────────────────────────────────────

  static const nicknameRequired = 'Name cannot be empty';
  static const nicknameTooShort =
      'Name must be at least $nicknameMinLength characters';
  static const nicknameTooLong =
      'Name cannot be longer than $nicknameMaxLength characters';
  static const nicknameInvalid =
      "Name can only use letters, numbers, spaces and . ' - _";
  static const nicknameNeedsLetter = 'Name must contain at least one letter';

  /// Deliberately does not repeat the term back at the user: quoting it puts
  /// the profanity on screen, and naming exactly what was caught tells someone
  /// probing the filter precisely which spelling to try next.
  static const nicknameProfane =
      'Please choose a different name — that one is not allowed';

  /// Shown when another account already holds this exact name.
  ///
  /// Matching is case-sensitive by decision, so "Ianwong" and "IANwong" are
  /// different names and only an exact clash is refused. The message says
  /// "already taken" rather than naming the holder — who owns a name is not
  /// something a stranger needs to be told.
  static const nicknameTaken =
      'That name is already taken. Try a different one';

  // ── Phone ─────────────────────────────────────────────────────────────────

  static const phoneRequired = 'Contact number cannot be empty';

  /// Country-neutral: the dial code is chosen from the picker beside the
  /// field, so the number itself is only ever bare digits.
  static const phoneInvalid = 'Enter your number using digits only';

  /// Shown when libphonenumber says the digits are not a number that country
  /// allocates. Names the country because the same digits can be perfectly
  /// valid one entry up or down the picker.
  ///
  /// Longest case is `Saint Vincent and the Grenadines` at 53 characters,
  /// inside the width budget `field_error_wrapping_test.dart` enforces.
  static String phoneInvalidForCountry(String country) =>
      'Enter a valid $country number';

  // ── Body metrics ──────────────────────────────────────────────────────────

  static const heightRequired = 'Height is required';
  static const heightInvalid = 'Enter height as a number in cm';
  static const heightOutOfRange =
      'Height must be between $heightMinCm–$heightMaxCm cm';
  static const weightRequired = 'Weight is required';
  static const weightInvalid = 'Enter weight as a number in kg';
  static const weightOutOfRange =
      'Weight must be between $weightMinKg–$weightMaxKg kg';

  // Imperial equivalents. Feet and inches are two fields, so each gets its own
  // "this box alone is wrong" message and the combined range check reports
  // under the inches box, where the second half of the answer is typed.
  static const heightFeetInvalid = 'Enter feet as a whole number';
  static const heightInchesInvalid = 'Enter inches as a number';
  static const heightInchesOutOfRange =
      'Inches must be 0–${inchesPerFoot - 1}';
  static const heightOutOfRangeImperial =
      'Height must be between ${heightMinFeet}ft ${heightMinInches}in '
      'and ${heightMaxFeet}ft ${heightMaxInches}in';
  static const weightInvalidLb = 'Enter weight as a number in lb';
  static const weightOutOfRangeLb =
      'Weight must be between $weightMinLb–$weightMaxLb lb';

  // ── OTP ───────────────────────────────────────────────────────────────────

  static const otpRequired = 'Enter the $otpLength-digit code';
  static const otpIncomplete = 'Enter all $otpLength digits';
  static const otpNotNumeric = 'The code is $otpLength digits, numbers only';
}
