import '../constants/country_dial_codes.dart';
import '../constants/validation_messages.dart';
import 'phone_number_rules.dart';
import 'profanity_filter.dart';

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
    // Last, so the user is told about a fixable shape problem before being
    // told the name is disallowed outright.
    if (!ProfanityFilter.isClean(input)) {
      return ValidationMessages.nicknameProfane;
    }
    return null;
  }

  // ── Phone ─────────────────────────────────────────────────────────────────

  /// The national number, with the country supplied by the picker beside the
  /// field.
  ///
  /// The rule is Google's libphonenumber metadata, via [PhoneNumberRules] —
  /// the digits must match a range the country actually allocates, not merely
  /// be a plausible length. A trunk `0` is accepted and resolved per country
  /// rather than rejected: the library drops Malaysia's, and keeps Rome's,
  /// where the zero is part of the number.
  static String? phoneNational(String? value, Country country) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return ValidationMessages.phoneRequired;

    final cleaned = input.replaceAll(_phoneSeparators, '');
    if (!_digitsOnly.hasMatch(cleaned)) return ValidationMessages.phoneInvalid;

    if (!PhoneNumberRules.check(cleaned, country).isValid) {
      return ValidationMessages.phoneInvalidForCountry(country.name);
    }
    return null;
  }

  // ── Body metrics ──────────────────────────────────────────────────────────

  /// Height in centimetres — the unit the profile always stores. The imperial
  /// pair below converts before deferring to the same bounds, so this is the
  /// only place the height rule is actually expressed.
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

  /// The feet box on its own — format and sign only.
  ///
  /// The real limit is the combined height, reported under the inches box by
  /// [heightImperial], because `5 ft` on its own is neither right nor wrong
  /// until you know the inches beside it.
  static String? heightFeet(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return ValidationMessages.heightRequired;
    final parsed = int.tryParse(input);
    if (parsed == null || parsed < 0) {
      return ValidationMessages.heightFeetInvalid;
    }
    return null;
  }

  /// The inches box, followed by the combined feet + inches range.
  ///
  /// Bounds come from the imperial constants rather than converting to cm and
  /// comparing there, so the rule enforced is exactly the rule the message
  /// states. Those constants are rounded inwards from the cm bounds, so a
  /// height that passes here is always inside the stored range too.
  static String? heightImperial(String? feetText, String? inchesText) {
    final input = inchesText?.trim() ?? '';
    if (input.isEmpty) return ValidationMessages.heightRequired;

    final inches = double.tryParse(input);
    if (inches == null || !inches.isFinite) {
      return ValidationMessages.heightInchesInvalid;
    }
    if (inches < 0 || inches >= ValidationMessages.inchesPerFoot) {
      return ValidationMessages.heightInchesOutOfRange;
    }

    final feet = int.tryParse(feetText?.trim() ?? '');
    // The feet box is already showing its own message; don't say it twice.
    if (feet == null || feet < 0) return null;

    final total = feet * ValidationMessages.inchesPerFoot + inches;
    const min = ValidationMessages.heightMinFeet *
            ValidationMessages.inchesPerFoot +
        ValidationMessages.heightMinInches;
    const max = ValidationMessages.heightMaxFeet *
            ValidationMessages.inchesPerFoot +
        ValidationMessages.heightMaxInches;
    if (total < min || total > max) {
      return ValidationMessages.heightOutOfRangeImperial;
    }
    return null;
  }

  /// Weight in pounds — see the note on [heightImperial] about bounds.
  static String? weightLb(String? value) => _numberInRange(
        value,
        min: ValidationMessages.weightMinLb,
        max: ValidationMessages.weightMaxLb,
        requiredMessage: ValidationMessages.weightRequired,
        invalidMessage: ValidationMessages.weightInvalidLb,
        rangeMessage: ValidationMessages.weightOutOfRangeLb,
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
