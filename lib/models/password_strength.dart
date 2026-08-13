import '../constants/validation_messages.dart';
import '../utils/validators.dart';

/// How far along the strength meter a password sits.
enum PasswordStrengthLevel {
  /// Nothing typed yet — the meter renders empty rather than red.
  empty,
  weak,
  fair,
  good,
  strong,
}

/// One line of the checklist under the password field.
class PasswordRequirement {
  final String label;
  final bool met;

  const PasswordRequirement(this.label, {required this.met});
}

/// A read-only assessment of a password, produced by [PasswordStrength.of]
/// and rendered by the strength meter.
///
/// [Validators.password] stays the single authority on whether a password is
/// allowed; this class only decides how to *show* that. The two are kept in
/// step by [meetsPolicy], which asks the validator directly — so the meter can
/// never sit on "good" for a password the form will reject.
///
/// The levels above the policy bar ([PasswordStrengthLevel.strong]) are
/// encouragement, not a gate: a user who clears the policy can always submit.
class PasswordStrength {
  final PasswordStrengthLevel level;
  final List<PasswordRequirement> requirements;

  /// Why the validator rejected the password, or null when it accepted it.
  final String? policyError;

  const PasswordStrength._(this.level, this.requirements, this.policyError);

  static final _lowercase = RegExp(r'[a-z]');
  static final _uppercase = RegExp(r'[A-Z]');
  static final _digit = RegExp(r'\d');

  /// Any printable character that is neither a letter, a digit, nor a space.
  static final _symbol = RegExp(r'[^A-Za-z0-9\s]');

  static final _whitespace = RegExp(r'\s');

  /// Grades [password] against the four checklist requirements, then bumps a
  /// fully-compliant password up a level once it reaches the recommended
  /// length.
  factory PasswordStrength.of(String? password) {
    final value = password ?? '';

    final hasLength = value.length >= ValidationMessages.passwordMinLength;
    final hasCases = _lowercase.hasMatch(value) && _uppercase.hasMatch(value);
    final hasDigit = _digit.hasMatch(value);
    final hasSymbol = _symbol.hasMatch(value);

    final requirements = [
      PasswordRequirement(ValidationMessages.requirementLength, met: hasLength),
      PasswordRequirement(ValidationMessages.requirementCases, met: hasCases),
      PasswordRequirement(ValidationMessages.requirementDigit, met: hasDigit),
      PasswordRequirement(ValidationMessages.requirementSymbol, met: hasSymbol),
    ];

    final policyError = Validators.password(value);

    if (value.isEmpty) {
      return PasswordStrength._(
        PasswordStrengthLevel.empty,
        requirements,
        policyError,
      );
    }

    // Spaces and over-long passwords are rejected outright even with every
    // box ticked, so don't flatter them with a high score.
    final blocked = _whitespace.hasMatch(value) ||
        value.length > ValidationMessages.passwordMaxLength;

    final metCount = requirements.where((r) => r.met).length;

    final PasswordStrengthLevel level;
    if (blocked) {
      level = PasswordStrengthLevel.weak;
    } else if (metCount < 4) {
      level =
      metCount <= 1 ? PasswordStrengthLevel.weak : PasswordStrengthLevel.fair;
    } else if (value.length < ValidationMessages.passwordStrongLength) {
      level = PasswordStrengthLevel.good;
    } else {
      level = PasswordStrengthLevel.strong;
    }

    return PasswordStrength._(level, requirements, policyError);
  }

  /// True when the form would accept this password — equivalent to
  /// `Validators.password(value) == null`, and to the meter reading
  /// "good" or "strong".
  bool get meetsPolicy => policyError == null;

  /// How much of the meter to fill, 0.0–1.0.
  double get fraction => switch (level) {
    PasswordStrengthLevel.empty => 0.0,
    PasswordStrengthLevel.weak => 0.25,
    PasswordStrengthLevel.fair => 0.5,
    PasswordStrengthLevel.good => 0.75,
    PasswordStrengthLevel.strong => 1.0,
  };

  /// Caption shown to the right of the meter; empty before anything is typed.
  String get label => switch (level) {
    PasswordStrengthLevel.empty => '',
    PasswordStrengthLevel.weak => ValidationMessages.strengthWeak,
    PasswordStrengthLevel.fair => ValidationMessages.strengthFair,
    PasswordStrengthLevel.good => ValidationMessages.strengthGood,
    PasswordStrengthLevel.strong => ValidationMessages.strengthStrong,
  };
}
