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

  // ── Phone ─────────────────────────────────────────────────────────────────

  static const phoneRequired = 'Contact number cannot be empty';
  static const phoneInvalid =
      'Enter a valid Malaysian number, e.g. 012-345 6789 or +60123456789';

  // ── Body metrics ──────────────────────────────────────────────────────────

  static const heightRequired = 'Height is required';
  static const heightInvalid = 'Enter height as a number in cm';
  static const heightOutOfRange =
      'Height must be between $heightMinCm–$heightMaxCm cm';
  static const weightRequired = 'Weight is required';
  static const weightInvalid = 'Enter weight as a number in kg';
  static const weightOutOfRange =
      'Weight must be between $weightMinKg–$weightMaxKg kg';

  // ── OTP ───────────────────────────────────────────────────────────────────

  static const otpRequired = 'Enter the $otpLength-digit code';
  static const otpIncomplete = 'Enter all $otpLength digits';
  static const otpNotNumeric = 'The code is $otpLength digits, numbers only';
}
