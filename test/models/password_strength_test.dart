import 'package:test/test.dart';
import 'package:walkpenang/constants/validation_messages.dart';
import 'package:walkpenang/models/password_strength.dart';
import 'package:walkpenang/utils/validators.dart';

/// Grading behind the live strength meter on the sign-in screen.
void main() {
  group('level', () {
    test('nothing typed reads as empty, not weak', () {
      final strength = PasswordStrength.of('');
      expect(strength.level, PasswordStrengthLevel.empty);
      expect(strength.fraction, 0.0);
      expect(strength.label, isEmpty);
    });

    test('null is treated as empty', () {
      expect(PasswordStrength.of(null).level, PasswordStrengthLevel.empty);
    });

    test('one requirement or fewer is weak', () {
      expect(PasswordStrength.of('abc').level, PasswordStrengthLevel.weak);
      expect(PasswordStrength.of('abcdefghij').level,
          PasswordStrengthLevel.weak);
    });

    test('two or three requirements is fair', () {
      expect(PasswordStrength.of('Abcdefgh').level, PasswordStrengthLevel.fair);
      expect(PasswordStrength.of('Abcd1234').level, PasswordStrengthLevel.fair);
    });

    test('all four requirements below the recommended length is good', () {
      final strength = PasswordStrength.of('Abcd123!');
      expect(strength.level, PasswordStrengthLevel.good);
      expect(strength.meetsPolicy, isTrue);
      expect(strength.label, ValidationMessages.strengthGood);
    });

    test('all four plus the recommended length is strong', () {
      const password = 'Penang2026!Walk';
      expect(password.length,
          greaterThanOrEqualTo(ValidationMessages.passwordStrongLength));
      final strength = PasswordStrength.of(password);
      expect(strength.level, PasswordStrengthLevel.strong);
      expect(strength.fraction, 1.0);
      expect(strength.label, ValidationMessages.strengthStrong);
    });

    test('whitespace caps the score at weak however complex the rest is', () {
      // Every checklist box is ticked, but the validator rejects it — so the
      // meter must not encourage it.
      final strength = PasswordStrength.of('Penang 2026! Walk');
      expect(strength.requirements.every((r) => r.met), isTrue);
      expect(strength.level, PasswordStrengthLevel.weak);
      expect(strength.meetsPolicy, isFalse);
      expect(strength.policyError, ValidationMessages.passwordNoSpaces);
    });

    test('an over-long password is weak, not strong', () {
      final long = 'Aa1!${'x' * ValidationMessages.passwordMaxLength}';
      final strength = PasswordStrength.of(long);
      expect(strength.level, PasswordStrengthLevel.weak);
      expect(strength.policyError, ValidationMessages.passwordTooLong);
    });
  });

  group('requirements checklist', () {
    test('lists all four rules in a stable order', () {
      final labels =
      PasswordStrength.of('').requirements.map((r) => r.label).toList();
      expect(labels, [
        ValidationMessages.requirementLength,
        ValidationMessages.requirementCases,
        ValidationMessages.requirementDigit,
        ValidationMessages.requirementSymbol,
      ]);
    });

    test('ticks each rule independently', () {
      final strength = PasswordStrength.of('abcdefgh');
      final met = {
        for (final r in strength.requirements) r.label: r.met,
      };
      expect(met[ValidationMessages.requirementLength], isTrue);
      expect(met[ValidationMessages.requirementCases], isFalse);
      expect(met[ValidationMessages.requirementDigit], isFalse);
      expect(met[ValidationMessages.requirementSymbol], isFalse);
    });

    test('the cases rule needs both upper and lower', () {
      bool casesMet(String password) => PasswordStrength.of(password)
          .requirements
          .firstWhere((r) => r.label == ValidationMessages.requirementCases)
          .met;

      expect(casesMet('ABCDEFGH'), isFalse);
      expect(casesMet('abcdefgh'), isFalse);
      expect(casesMet('Abcdefgh'), isTrue);
    });
  });

  group('agreement with Validators.password', () {
    const samples = [
      '',
      'a',
      'secret',
      'abc123',
      'Abcdefgh',
      'Abcd1234',
      'abcd1234!',
      'ABCD1234!',
      'Abcdefgh!',
      'Abcd123!',
      'Penang2026!',
      'Penang 2026!',
      ' Abcd123!',
      'W@lk1ngPenangIsGreat',
    ];

    test('meetsPolicy matches the validator on every sample', () {
      for (final sample in samples) {
        expect(
          PasswordStrength.of(sample).meetsPolicy,
          Validators.password(sample) == null,
          reason: 'disagreement on "$sample"',
        );
      }
    });

    test('a passing password always reads good or strong, and vice versa', () {
      for (final sample in samples) {
        final strength = PasswordStrength.of(sample);
        final reassuring = strength.level == PasswordStrengthLevel.good ||
            strength.level == PasswordStrengthLevel.strong;
        expect(
          reassuring,
          strength.meetsPolicy,
          reason: 'meter and policy disagree on "$sample"',
        );
      }
    });
  });
}
