import 'package:test/test.dart';
import 'package:walkpenang/constants/validation_messages.dart';
import 'package:walkpenang/utils/validators.dart';

/// Form rules for the user-authentication and edit-profile modules.
///
/// Validators are pure Dart, so these run without a Flutter binding.
void main() {
  group('email', () {
    test('accepts ordinary addresses', () {
      expect(Validators.email('ianwongjingli@gmail.com'), isNull);
      expect(Validators.email('tang.yue-hann+vm2026@student.edu.my'), isNull);
      expect(Validators.email('a@b.co'), isNull);
    });

    test('trims surrounding whitespace before judging', () {
      expect(Validators.email('  ian@gmail.com  '), isNull);
    });

    test('rejects empty input', () {
      expect(Validators.email(null), ValidationMessages.emailRequired);
      expect(Validators.email(''), ValidationMessages.emailRequired);
      expect(Validators.email('   '), ValidationMessages.emailRequired);
    });

    test('rejects what the old contains-@ rule let through', () {
      // Every one of these passed the previous `v.contains('@')` check.
      expect(Validators.email('@'), ValidationMessages.emailInvalid);
      expect(Validators.email('ian@'), ValidationMessages.emailInvalid);
      expect(Validators.email('@gmail.com'), ValidationMessages.emailInvalid);
      expect(Validators.email('ian@gmail'), ValidationMessages.emailInvalid);
      expect(Validators.email('ian gmail@x.com'),
          ValidationMessages.emailInvalid);
      expect(Validators.email('ian@@gmail.com'),
          ValidationMessages.emailInvalid);
      expect(Validators.email('ian@gmail..com'),
          ValidationMessages.emailInvalid);
    });

    test('rejects an address past the RFC length limit', () {
      final long = '${'a' * 250}@b.co';
      expect(long.length, greaterThan(ValidationMessages.emailMaxLength));
      expect(Validators.email(long), ValidationMessages.emailTooLong);
    });
  });

  group('password', () {
    test('accepts a password meeting every requirement', () {
      expect(Validators.password('Penang2026!'), isNull);
      expect(Validators.password('W@lk1ngPenangIsGreat'), isNull);
    });

    test('rejects empty input', () {
      expect(Validators.password(null), ValidationMessages.passwordRequired);
      expect(Validators.password(''), ValidationMessages.passwordRequired);
    });

    test('reports the single next thing to fix, in order', () {
      expect(Validators.password('Ab1!'), ValidationMessages.passwordTooShort);
      expect(Validators.password('ABCD1234!'),
          ValidationMessages.passwordNeedsLowercase);
      expect(Validators.password('abcd1234!'),
          ValidationMessages.passwordNeedsUppercase);
      expect(Validators.password('Abcdefgh!'),
          ValidationMessages.passwordNeedsDigit);
      expect(Validators.password('Abcd1234'),
          ValidationMessages.passwordNeedsSymbol);
    });

    test('rejects whitespace anywhere, before any other complaint', () {
      expect(Validators.password('Penang 2026!'),
          ValidationMessages.passwordNoSpaces);
      expect(Validators.password(' Penang2026!'),
          ValidationMessages.passwordNoSpaces);
      expect(Validators.password('Penang2026!\t'),
          ValidationMessages.passwordNoSpaces);
      // Short *and* spaced — the space is the message shown.
      expect(Validators.password('A 1!'), ValidationMessages.passwordNoSpaces);
    });

    test('rejects a password past the maximum length', () {
      final long = 'Aa1!${'x' * ValidationMessages.passwordMaxLength}';
      expect(Validators.password(long), ValidationMessages.passwordTooLong);
    });

    test('exactly the minimum length passes', () {
      const atMinimum = 'Abcd123!';
      expect(atMinimum.length, ValidationMessages.passwordMinLength);
      expect(Validators.password(atMinimum), isNull);
    });

    test('rejects the 6-character passwords the old rule allowed', () {
      expect(Validators.password('secret'), isNotNull);
      expect(Validators.password('abc123'), isNotNull);
    });
  });

  group('nickname', () {
    test('accepts ordinary names', () {
      expect(Validators.nickname('Yue Hann'), isNull);
      expect(Validators.nickname("O'Brien"), isNull);
      expect(Validators.nickname('Ali_99'), isNull);
      expect(Validators.nickname('Siti binti Abu-Bakar'), isNull);
    });

    test('accepts non-Latin scripts', () {
      expect(Validators.nickname('陈大文'), isNull);
      expect(Validators.nickname('கண்ணன்'), isNull);
    });

    test('rejects empty and whitespace-only input', () {
      expect(Validators.nickname(null), ValidationMessages.nicknameRequired);
      expect(Validators.nickname('   '), ValidationMessages.nicknameRequired);
    });

    test('enforces the length bounds', () {
      expect(Validators.nickname('A'), ValidationMessages.nicknameTooShort);
      expect(Validators.nickname('Ab'), isNull);
      expect(
        Validators.nickname('a' * (ValidationMessages.nicknameMaxLength + 1)),
        ValidationMessages.nicknameTooLong,
      );
      expect(
        Validators.nickname('a' * ValidationMessages.nicknameMaxLength),
        isNull,
      );
    });

    test('rejects disallowed characters', () {
      expect(Validators.nickname('Yue<script>'),
          ValidationMessages.nicknameInvalid);
      expect(Validators.nickname('ian@home'), ValidationMessages.nicknameInvalid);
      expect(Validators.nickname('drop; table'),
          ValidationMessages.nicknameInvalid);
    });

    test('requires at least one letter', () {
      expect(Validators.nickname('123'), ValidationMessages.nicknameNeedsLetter);
      expect(Validators.nickname('--'), ValidationMessages.nicknameNeedsLetter);
    });
  });

  group('phone', () {
    test('accepts Malaysian mobile numbers in the usual shapes', () {
      expect(Validators.phone('0123456789'), isNull);
      expect(Validators.phone('012-345 6789'), isNull);
      expect(Validators.phone('+60123456789'), isNull);
      expect(Validators.phone('+60 12-345 6789'), isNull);
      expect(Validators.phone('(012) 345-6789'), isNull);
      expect(Validators.phone('60123456789'), isNull);
    });

    test('accepts a Penang landline', () {
      expect(Validators.phone('04-226 1234'), isNull);
    });

    test('rejects empty input', () {
      expect(Validators.phone(null), ValidationMessages.phoneRequired);
      expect(Validators.phone('  '), ValidationMessages.phoneRequired);
    });

    test('rejects malformed numbers', () {
      expect(Validators.phone('12345'), ValidationMessages.phoneInvalid);
      expect(Validators.phone('0'), ValidationMessages.phoneInvalid);
      expect(Validators.phone('00123456789'), ValidationMessages.phoneInvalid);
      expect(Validators.phone('012345678901234'),
          ValidationMessages.phoneInvalid);
      expect(Validators.phone('not a number'), ValidationMessages.phoneInvalid);
      expect(Validators.phone('+1 415 555 0100'),
          ValidationMessages.phoneInvalid);
    });
  });

  group('height', () {
    test('accepts realistic heights', () {
      expect(Validators.heightCm('170'), isNull);
      expect(Validators.heightCm('170.5'), isNull);
      // The edit-profile form seeds the field from a double.
      expect(Validators.heightCm('170.0'), isNull);
      expect(Validators.heightCm('  165 '), isNull);
    });

    test('rejects empty and non-numeric input', () {
      expect(Validators.heightCm(''), ValidationMessages.heightRequired);
      expect(Validators.heightCm('tall'), ValidationMessages.heightInvalid);
      expect(Validators.heightCm('Infinity'), ValidationMessages.heightInvalid);
      expect(Validators.heightCm('NaN'), ValidationMessages.heightInvalid);
    });

    test('rejects values outside the plausible range', () {
      expect(Validators.heightCm('0'), ValidationMessages.heightOutOfRange);
      expect(Validators.heightCm('-170'), ValidationMessages.heightOutOfRange);
      // Passed the old `> 0` rule.
      expect(Validators.heightCm('9999'), ValidationMessages.heightOutOfRange);
      expect(Validators.heightCm('1.7'), ValidationMessages.heightOutOfRange);
    });

    test('the bounds themselves are inclusive', () {
      expect(Validators.heightCm('${ValidationMessages.heightMinCm}'), isNull);
      expect(Validators.heightCm('${ValidationMessages.heightMaxCm}'), isNull);
    });
  });

  group('weight', () {
    test('accepts realistic weights', () {
      expect(Validators.weightKg('62'), isNull);
      expect(Validators.weightKg('62.5'), isNull);
    });

    test('rejects empty, non-numeric and out-of-range input', () {
      expect(Validators.weightKg(''), ValidationMessages.weightRequired);
      expect(Validators.weightKg('heavy'), ValidationMessages.weightInvalid);
      expect(Validators.weightKg('0'), ValidationMessages.weightOutOfRange);
      expect(Validators.weightKg('5000'), ValidationMessages.weightOutOfRange);
    });

    test('the bounds themselves are inclusive', () {
      expect(Validators.weightKg('${ValidationMessages.weightMinKg}'), isNull);
      expect(Validators.weightKg('${ValidationMessages.weightMaxKg}'), isNull);
    });
  });

  group('otp', () {
    test('accepts exactly six digits', () {
      expect(Validators.otp('123456'), isNull);
      expect(Validators.otp('000000'), isNull);
      expect(Validators.otp(' 123456 '), isNull);
    });

    test('rejects empty input', () {
      expect(Validators.otp(null), ValidationMessages.otpRequired);
      expect(Validators.otp(''), ValidationMessages.otpRequired);
    });

    test('rejects the wrong number of digits', () {
      expect(Validators.otp('12345'), ValidationMessages.otpIncomplete);
      expect(Validators.otp('1234567'), ValidationMessages.otpIncomplete);
    });

    test('rejects non-digits the old length-only rule allowed', () {
      expect(Validators.otp('abcdef'), ValidationMessages.otpNotNumeric);
      expect(Validators.otp('12 456'), ValidationMessages.otpNotNumeric);
      expect(Validators.otp('12-456'), ValidationMessages.otpNotNumeric);
    });
  });

  group('required', () {
    test('passes any non-blank value', () {
      expect(Validators.required('x', 'missing'), isNull);
    });

    test('reports the caller-supplied message when blank', () {
      expect(Validators.required(null, 'missing'), 'missing');
      expect(Validators.required('   ', 'missing'), 'missing');
    });
  });
}
