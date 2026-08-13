import '../constants/validation_messages.dart';

/// Every form rule for the user-authentication and edit-profile modules,
/// in one place.
///
/// These are pure functions with no Flutter dependency, so they plug straight
/// into `TextFormField.validator` and are unit-testable without a widget
/// binding. Each returns `null` when the value is acceptable, or the message
/// to show beneath the field.
///
/// Limits and copy both come from [ValidationMessages] — never hard-code a
/// bound or a message at a call site.
class Validators {
  const Validators._();

  // ── Patterns ──────────────────────────────────────────────────────────────

  /// Deliberately stricter than `contains('@')`: requires a local part, a
  /// dotted domain, and an alphabetic TLD of two or more characters.
  static final _email = RegExp(
    r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+"
    r"(?:\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*"
    r'@(?:[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\.)+'
    r'[A-Za-z]{2,}$',
  );

  static final _lowercase = RegExp(r'[a-z]');
  static final _uppercase = RegExp(r'[A-Z]');
  static final _digit = RegExp(r'\d');
  static final _symbol = RegExp(r'[^A-Za-z0-9\s]');
  static final _whitespace = RegExp(r'\s');

  /// Letters (any script, so non-English names work), marks, digits, spaces
  /// and a small set of name punctuation.
  static final _nickname = RegExp(r"^[\p{L}\p{M}0-9 .'_-]+$", unicode: true);
  static final _anyLetter = RegExp(r'\p{L}', unicode: true);

  /// Separators people type inside phone numbers, stripped before matching.
  static final _phoneSeparators = RegExp(r'[\s\-().]');

  /// Malaysian numbers: optional `+60`/`60` country code or a leading `0`,
  /// then an 8–10 digit national number. Covers mobile (`012-345 6789`) and
  /// landline (`04-226 1234`).
  static final _malaysianPhone = RegExp(r'^(?:\+?60|0)[1-9]\d{7,9}$');

  static final _digitsOnly = RegExp(r'^\d+$');

  // ── Email ─────────────────────────────────────────────────────────────────

  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return ValidationMessages.emailRequired;
    if (input.length > ValidationMessages.emailMaxLength) {
      return ValidationMessages.emailTooLong;
    }
    if (!_email.hasMatch(input)) return ValidationMessages.emailInvalid;
    return null;
  }

  // ── Password ──────────────────────────────────────────────────────────────

  /// Enforces the account policy: 8+ characters mixing upper case, lower case,
  /// a number and a symbol, with no whitespace.
  ///
  /// Checks run shortest-fix-first so the user is told the one thing to change
  /// next rather than the whole list at once — the strength meter shows the
  /// full checklist alongside.
  ///
  /// Note this is not trimmed: a password's spaces are part of it, and are
  /// rejected outright rather than silently stripped.
  static String? password(String? value) {
    final input = value ?? '';
    if (input.isEmpty) return ValidationMessages.passwordRequired;
    if (_whitespace.hasMatch(input)) return ValidationMessages.passwordNoSpaces;
    if (input.length < ValidationMessages.passwordMinLength) {
      return ValidationMessages.passwordTooShort;
    }
    if (input.length > ValidationMessages.passwordMaxLength) {
      return ValidationMessages.passwordTooLong;
    }
    if (!_lowercase.hasMatch(input)) {
      return ValidationMessages.passwordNeedsLowercase;
    }
    if (!_uppercase.hasMatch(input)) {
      return ValidationMessages.passwordNeedsUppercase;
    }
    if (!_digit.hasMatch(input)) return ValidationMessages.passwordNeedsDigit;
    if (!_symbol.hasMatch(input)) return ValidationMessages.passwordNeedsSymbol;
    return null;
  }

  // ── Nickname ──────────────────────────────────────────────────────────────

  static String? nickname(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return ValidationMessages.nicknameRequired;
    if (input.length < ValidationMessages.nicknameMinLength) {
      return ValidationMessages.nicknameTooShort;
    }
    if (input.length > ValidationMessages.nicknameMaxLength) {
      return ValidationMessages.nicknameTooLong;
    }
    if (!_nickname.hasMatch(input)) return ValidationMessages.nicknameInvalid;
    // Blocks "123" and "--" while still allowing "Ali 99".
    if (!_anyLetter.hasMatch(input)) {
      return ValidationMessages.nicknameNeedsLetter;
    }
    return null;
  }

  // ── Phone ─────────────────────────────────────────────────────────────────

  static String? phone(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return ValidationMessages.phoneRequired;
    final cleaned = input.replaceAll(_phoneSeparators, '');
    if (!_malaysianPhone.hasMatch(cleaned)) {
      return ValidationMessages.phoneInvalid;
    }
    return null;
  }

  // ── Body metrics ──────────────────────────────────────────────────────────

  /// Height in centimetres. The unit dropdown only changes how figures are
  /// *displayed* elsewhere; UserProfile always stores centimetres, so this
  /// field is always validated as cm.
  static String? heightCm(String? value) => _numberInRange(
    value,
    min: ValidationMessages.heightMinCm,
    max: ValidationMessages.heightMaxCm,
    requiredMessage: ValidationMessages.heightRequired,
    invalidMessage: ValidationMessages.heightInvalid,
    rangeMessage: ValidationMessages.heightOutOfRange,
  );

  /// Weight in kilograms — see the note on [heightCm] about units.
  static String? weightKg(String? value) => _numberInRange(
    value,
    min: ValidationMessages.weightMinKg,
    max: ValidationMessages.weightMaxKg,
    requiredMessage: ValidationMessages.weightRequired,
    invalidMessage: ValidationMessages.weightInvalid,
    rangeMessage: ValidationMessages.weightOutOfRange,
  );

  static String? _numberInRange(
      String? value, {
        required num min,
        required num max,
        required String requiredMessage,
        required String invalidMessage,
        required String rangeMessage,
      }) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return requiredMessage;

    final parsed = double.tryParse(input);
    // `double.tryParse` happily accepts 'Infinity' and 'NaN'.
    if (parsed == null || !parsed.isFinite) return invalidMessage;

    if (parsed < min || parsed > max) return rangeMessage;
    return null;
  }

  // ── OTP ───────────────────────────────────────────────────────────────────

  static String? otp(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return ValidationMessages.otpRequired;
    if (!_digitsOnly.hasMatch(input)) return ValidationMessages.otpNotNumeric;
    if (input.length != ValidationMessages.otpLength) {
      return ValidationMessages.otpIncomplete;
    }
    return null;
  }

  // ── Generic ───────────────────────────────────────────────────────────────

  /// Fallback for fields with no rule beyond "must be filled in".
  static String? required(String? value, String message) =>
      (value?.trim().isEmpty ?? true) ? message : null;
}
