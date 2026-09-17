// ---------------------------------------------------------------------------
// phone_number_rules_test.dart
// Profile — the libphonenumber wrapper
// ---------------------------------------------------------------------------
//
// PhoneNumberRules is the only file that imports phone_numbers_parser, so this
// is where the library's behaviour gets pinned down: what it does with a trunk
// prefix, and that nothing it throws can reach a form.

import 'package:test/test.dart';
import 'package:walkpenang/constants/country_dial_codes.dart';
import 'package:walkpenang/utils/phone_number_rules.dart';

void main() {
  final malaysia = countryByIso('MY');

  group('iso code mapping', () {
    test('resolves our codes onto the library enum', () {
      expect(PhoneNumberRules.isoCodeFor(malaysia)?.name, 'MY');
      expect(PhoneNumberRules.isoCodeFor(countryByIso('US'))?.name, 'US');
    });

    test('an unknown code returns null instead of throwing', () {
      const unknown = Country(isoCode: 'ZZ', name: 'Nowhere', dialCode: '999');
      expect(PhoneNumberRules.isoCodeFor(unknown), isNull);
      // And check() must survive it, because a form may still call through.
      expect(PhoneNumberRules.check('123456789', unknown).isValid, isFalse);
    });
  });

  group('dial codes', () {
    test('come back without the plus', () {
      expect(PhoneNumberRules.dialCodeFor(malaysia), '60');
      expect(PhoneNumberRules.dialCodeFor(countryByIso('FI')), '358');
    });
  });

  group('trunk prefixes are resolved per country', () {
    test('Malaysia drops the leading zero', () {
      final check = PhoneNumberRules.check('0123456789', malaysia);
      expect(check.isValid, isTrue);
      expect(check.nationalNumber, '123456789');
    });

    test('Australia and Germany drop theirs too', () {
      expect(PhoneNumberRules.check('0412345678', countryByIso('AU'))
          .nationalNumber, '412345678');
      expect(PhoneNumberRules.check('015123456789', countryByIso('DE'))
          .nationalNumber, '15123456789');
    });

    test('Italy keeps its leading zero, because it is part of the number', () {
      // 06 is Rome's area code. A blanket "strip the 0" rule would corrupt it —
      // this is precisely why the library decides rather than a regex.
      final check = PhoneNumberRules.check('0612345678', countryByIso('IT'));
      expect(check.isValid, isTrue);
      expect(check.nationalNumber, '0612345678');
    });

    test('Singapore has no trunk prefix at all', () {
      final check = PhoneNumberRules.check('91234567', countryByIso('SG'));
      expect(check.isValid, isTrue);
      expect(check.nationalNumber, '91234567');
    });
  });

  group('validity is per country, not merely per length', () {
    test('the same digits differ between countries', () {
      expect(PhoneNumberRules.check('91234567', countryByIso('SG')).isValid,
          isTrue);
      expect(PhoneNumberRules.check('91234567', countryByIso('GB')).isValid,
          isFalse);
    });

    test('a plausible-length invention is rejected', () {
      expect(PhoneNumberRules.check('1234567890', malaysia).isValid, isFalse);
      expect(PhoneNumberRules.check('1234567890', countryByIso('US')).isValid,
          isFalse);
    });
  });

  group('nothing a half-typed field contains can throw', () {
    // Autovalidation runs on every keystroke, so check() sees every prefix of
    // every number anyone types, plus whatever a paste puts in the box.
    test('partial, empty and junk input all return safely', () {
      for (final input in <String>[
        '',
        '   ',
        '1',
        '01',
        'abc',
        '()-. ',
        '9' * 40,
      ]) {
        expect(() => PhoneNumberRules.check(input, malaysia), returnsNormally,
            reason: 'threw on "$input"');
        expect(PhoneNumberRules.check(input, malaysia).isValid, isFalse,
            reason: '"$input" should not be valid');
      }
    });

    test('a +-prefixed number parses here but is refused by the validator', () {
      // Two different jobs. This wrapper is a thin view of the library, which
      // happily reads an international prefix. Refusing it is a product rule —
      // the dial code comes from the picker — so it lives in Validators, and
      // validators_test.dart asserts the rejection.
      expect(PhoneNumberRules.check('+60123456789', malaysia).isValid, isTrue);
    });

    test('every prefix of a real number is safe', () {
      const full = '1112013343';
      for (var i = 0; i <= full.length; i++) {
        expect(() => PhoneNumberRules.check(full.substring(0, i), malaysia),
            returnsNormally);
      }
      expect(PhoneNumberRules.check(full, malaysia).isValid, isTrue);
    });
  });
}
