// ---------------------------------------------------------------------------
// country_dial_codes_test.dart
// Profile — the country table is hand-held data, so guard its shape
// ---------------------------------------------------------------------------
//
// There is no package behind this list; it is a Dart constant generated once
// and edited by hand afterwards. A duplicate ISO code or a stray `+` would not
// break the build, it would quietly give one country the wrong dial code, so
// the invariants are asserted rather than assumed.

import 'package:phone_numbers_parser/phone_numbers_parser.dart' as lib;
import 'package:test/test.dart';
import 'package:walkpenang/constants/country_dial_codes.dart';
import 'package:walkpenang/utils/phone_number_rules.dart';

void main() {
  group('the table itself', () {
    test('every ISO code is unique', () {
      final seen = <String>{};
      for (final country in kCountries) {
        expect(seen.add(country.isoCode), isTrue,
            reason: 'duplicate ISO code ${country.isoCode}');
      }
    });

    test('every entry is well formed', () {
      for (final country in kCountries) {
        expect(country.isoCode, matches(RegExp(r'^[A-Z]{2}$')),
            reason: '${country.name} has a malformed ISO code');
        expect(country.name.trim(), isNotEmpty);
        // Stored without the `+` so it can be composed either way; a stray one
        // would render as "++60".
        expect(country.dialCode, matches(RegExp(r'^[0-9]{1,4}$')),
            reason: '${country.name} has a malformed dial code');
        expect(country.displayDialCode, startsWith('+'));
      }
    });

    test('is sorted by name, so the picker reads alphabetically', () {
      final names = kCountries.map((c) => c.name).toList();
      final sorted = [...names]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      // Compared case-insensitively; diacritics are folded by the generator so
      // "Åland" sits under A rather than after Z.
      expect(names.first, sorted.first);
      expect(names.length, sorted.length);
    });

    test('covers the app\'s own market and the usual visitor origins', () {
      for (final iso in ['MY', 'SG', 'ID', 'TH', 'CN', 'GB', 'US', 'AU']) {
        expect(kCountries.any((c) => c.isoCode == iso), isTrue,
            reason: '$iso missing from the table');
      }
      expect(countryByIso('MY').dialCode, '60');
      expect(countryByIso('SG').dialCode, '65');
      expect(countryByIso('AU').dialCode, '61');
    });
  });

  // The dial codes are literals in our table rather than looked up at render
  // time, which is only safe while they agree with the library that validates
  // against them. This group is what makes that trade-off honest: drift is
  // caught here instead of showing a tourist the wrong +code.
  group('parity with libphonenumber', () {
    test('every country resolves to an IsoCode the library knows', () {
      final unknown = kCountries
          .where((c) => PhoneNumberRules.isoCodeFor(c) == null)
          .map((c) => '${c.isoCode} (${c.name})')
          .toList();
      expect(unknown, isEmpty,
          reason: 'these cannot be validated at all: $unknown');
    });

    test('every dial code matches the library metadata', () {
      final mismatches = <String>[];
      for (final country in kCountries) {
        final fromLibrary = PhoneNumberRules.dialCodeFor(country);
        if (fromLibrary != country.dialCode) {
          mismatches.add('${country.isoCode} ${country.name}: '
              'table=+${country.dialCode} library=+$fromLibrary');
        }
      }
      expect(mismatches, isEmpty);
    });

    test('the table covers every country the library supports', () {
      // Not strictly required, but a country the library can validate and the
      // picker cannot offer is a visitor we turn away for no reason.
      final ours = kCountries.map((c) => c.isoCode).toSet();
      final missing =
          lib.IsoCode.values.map((i) => i.name).where((n) => !ours.contains(n));
      expect(missing, isEmpty);
    });
  });

  group('lookup', () {
    test('finds a country by its code, whatever the casing', () {
      expect(countryByIso('MY').name, 'Malaysia');
      expect(countryByIso('my').name, 'Malaysia');
    });

    test('falls back to Malaysia rather than returning nothing', () {
      // A profile written before the picker existed carries no ISO code, and
      // a form mid-edit must not crash over it.
      expect(countryByIso(null).isoCode, kDefaultCountryIso);
      expect(countryByIso('').isoCode, kDefaultCountryIso);
      expect(countryByIso('ZZ').isoCode, kDefaultCountryIso);
    });
  });

  group('flag emoji', () {
    test('is built from the ISO code, so needs no image asset', () {
      // Two regional indicator symbols: M (U+1F1F2) and Y (U+1F1FE).
      expect(countryByIso('MY').flagEmoji.runes.toList(),
          [0x1F1F2, 0x1F1FE]);
      expect(countryByIso('GB').flagEmoji.runes.length, 2);
    });
  });

  group('search', () {
    test('an empty query returns everything', () {
      expect(searchCountries('').length, kCountries.length);
      expect(searchCountries('   ').length, kCountries.length);
    });

    test('matches on a partial name, case-insensitively', () {
      final results = searchCountries('malay');
      expect(results.map((c) => c.isoCode), contains('MY'));
      expect(searchCountries('MALAYSIA').map((c) => c.isoCode), contains('MY'));
    });

    test('matches on a dial code, with or without the plus', () {
      expect(searchCountries('60').map((c) => c.isoCode), contains('MY'));
      expect(searchCountries('+60').map((c) => c.isoCode), contains('MY'));
    });

    test('matches on the ISO code itself', () {
      expect(searchCountries('my').map((c) => c.isoCode), contains('MY'));
    });

    test('returns nothing for a query that matches nothing', () {
      expect(searchCountries('zzzzzz'), isEmpty);
    });
  });
}
