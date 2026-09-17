import 'package:test/test.dart';
import 'package:walkpenang/constants/country_dial_codes.dart';
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

    test('rejects a profane name', () {
      expect(Validators.nickname('fuck'), ValidationMessages.nicknameProfane);
      expect(Validators.nickname('Bodoh'), ValidationMessages.nicknameProfane);
      expect(
        Validators.nickname('sh1t'),
        ValidationMessages.nicknameProfane,
        reason: 'leetspeak must not be a way around it',
      );
    });

    test('the profanity check runs last, after the fixable rules', () {
      // A name that is both too short AND profane should be told about the
      // length first — that is the problem the user can act on.
      expect(Validators.nickname('A'), ValidationMessages.nicknameTooShort);
    });

    test('does not reject legitimate names that brush the wordlist', () {
      // Regression guard on the whole point of word-boundary matching. The
      // full suite lives in profanity_filter_test.dart; these are here so a
      // change to Validators cannot quietly break it.
      expect(Validators.nickname('Assalamualaikum'), isNull);
      expect(Validators.nickname('Cassandra'), isNull);
      expect(Validators.nickname('Bassam'), isNull);
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
    final malaysia = countryByIso('MY');
    final unitedStates = countryByIso('US');

    // Rules now come from Google's libphonenumber metadata via
    // phone_numbers_parser, so the digits must match a range the country
    // really allocates rather than merely being a plausible length.

    test('accepts real Malaysian numbers', () {
      expect(Validators.phoneNational('1112013343', malaysia), isNull);
      expect(Validators.phoneNational('123456789', malaysia), isNull);
      // Separators the user types are stripped before checking.
      expect(Validators.phoneNational('12-345 6789', malaysia), isNull);
      expect(Validators.phoneNational('(12) 345-6789', malaysia), isNull);
    });

    test('accepts a Penang landline', () {
      expect(Validators.phoneNational('42261234', malaysia), isNull);
    });

    test('accepts a foreign number — the point of the country picker', () {
      // '+1 415 555 0100' was asserted INVALID before the picker existed,
      // which locked every non-Malaysian visitor out of the field.
      expect(Validators.phoneNational('4155550100', unitedStates), isNull);
      expect(Validators.phoneNational('412345678', countryByIso('AU')), isNull);
      expect(Validators.phoneNational('7400123456', countryByIso('GB')), isNull);
      expect(Validators.phoneNational('91234567', countryByIso('SG')), isNull);
    });

    test('rejects empty input', () {
      expect(Validators.phoneNational(null, malaysia),
          ValidationMessages.phoneRequired);
      expect(Validators.phoneNational('  ', malaysia),
          ValidationMessages.phoneRequired);
    });

    test('accepts a trunk zero and does not complain about it', () {
      // Most countries write the national number with a leading 0 that is
      // dropped when dialling in from abroad. libphonenumber resolves it, so
      // the tourist may type their number the way they always write it.
      expect(Validators.phoneNational('0123456789', malaysia), isNull);
      expect(Validators.phoneNational('012-345 6789', malaysia), isNull);
      expect(Validators.phoneNational('0412345678', countryByIso('AU')), isNull);
    });

    test('keeps a leading zero where it is part of the number', () {
      // Italy is the counter-example: 06 is Rome's area code, not a prefix to
      // be stripped. Deferring to the library is what gets both cases right.
      expect(Validators.phoneNational('0612345678', countryByIso('IT')), isNull);
    });

    test('rejects digits that are not a real number for that country', () {
      // The whole reason for adopting libphonenumber — the old length-only
      // rule waved these through.
      expect(Validators.phoneNational('1234567890', malaysia),
          ValidationMessages.phoneInvalidForCountry('Malaysia'));
      expect(Validators.phoneNational('1234567890', unitedStates),
          ValidationMessages.phoneInvalidForCountry('United States'));
      expect(Validators.phoneNational('12', malaysia),
          ValidationMessages.phoneInvalidForCountry('Malaysia'));
    });

    test('the same digits can be valid in one country and not another', () {
      const digits = '91234567';
      expect(Validators.phoneNational(digits, countryByIso('SG')), isNull);
      expect(Validators.phoneNational(digits, countryByIso('GB')),
          ValidationMessages.phoneInvalidForCountry('United Kingdom'));
    });

    test('rejects anything that is not digits', () {
      expect(Validators.phoneNational('not a number', malaysia),
          ValidationMessages.phoneInvalid);
      // The dial code comes from the picker; typing it again is not allowed.
      expect(Validators.phoneNational('+60123456789', malaysia),
          ValidationMessages.phoneInvalid);
      expect(Validators.phoneNational('12a45678', malaysia),
          ValidationMessages.phoneInvalid);
    });

    test('an absurdly long string is rejected, not thrown on', () {
      expect(Validators.phoneNational('9' * 40, malaysia), isNotNull);
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

  group('height — imperial', () {
    test('accepts realistic feet and inches', () {
      expect(Validators.heightFeet('5'), isNull);
      expect(Validators.heightImperial('5', '8'), isNull);
      expect(Validators.heightImperial('6', '0'), isNull);
      expect(Validators.heightImperial('5', '11.5'), isNull);
    });

    test('rejects empty and non-numeric input', () {
      expect(Validators.heightFeet(''), ValidationMessages.heightRequired);
      expect(Validators.heightFeet('tall'),
          ValidationMessages.heightFeetInvalid);
      expect(Validators.heightImperial('5', ''),
          ValidationMessages.heightRequired);
      expect(Validators.heightImperial('5', 'eight'),
          ValidationMessages.heightInchesInvalid);
    });

    test('inches must be a remainder, not a whole height', () {
      expect(Validators.heightImperial('5', '12'),
          ValidationMessages.heightInchesOutOfRange);
      expect(Validators.heightImperial('5', '-1'),
          ValidationMessages.heightInchesOutOfRange);
    });

    test('reports the combined range under the inches box', () {
      // 0'6" and 9'0" are each individually well-formed; only the total is
      // out of range, which is why the check lives on the second field.
      expect(Validators.heightImperial('0', '6'),
          ValidationMessages.heightOutOfRangeImperial);
      expect(Validators.heightImperial('9', '0'),
          ValidationMessages.heightOutOfRangeImperial);
    });

    test('stays quiet about inches while the feet box is the problem', () {
      // The feet field is already showing its own message; saying it twice
      // under two fields reads as two separate faults.
      expect(Validators.heightImperial('tall', '8'), isNull);
    });

    test('the bounds themselves are inclusive', () {
      expect(
        Validators.heightImperial(
          '${ValidationMessages.heightMinFeet}',
          '${ValidationMessages.heightMinInches}',
        ),
        isNull,
      );
      expect(
        Validators.heightImperial(
          '${ValidationMessages.heightMaxFeet}',
          '${ValidationMessages.heightMaxInches}',
        ),
        isNull,
      );
    });
  });

  group('weight — imperial', () {
    test('accepts realistic weights in pounds', () {
      expect(Validators.weightLb('150'), isNull);
      expect(Validators.weightLb('150.5'), isNull);
    });

    test('rejects empty, non-numeric and out-of-range input', () {
      expect(Validators.weightLb(''), ValidationMessages.weightRequired);
      expect(Validators.weightLb('heavy'), ValidationMessages.weightInvalidLb);
      expect(Validators.weightLb('0'), ValidationMessages.weightOutOfRangeLb);
      expect(Validators.weightLb('5000'), ValidationMessages.weightOutOfRangeLb);
    });

    test('the bounds themselves are inclusive', () {
      expect(Validators.weightLb('${ValidationMessages.weightMinLb}'), isNull);
      expect(Validators.weightLb('${ValidationMessages.weightMaxLb}'), isNull);
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
