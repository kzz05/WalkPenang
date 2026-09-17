import 'package:phone_numbers_parser/phone_numbers_parser.dart' as lib;

import '../constants/country_dial_codes.dart';

/// What libphonenumber makes of a number the tourist typed.
class PhoneCheck {
  /// True only when the digits match a range the selected country actually
  /// allocates — not merely a plausible length.
  final bool isValid;

  /// The number in its canonical national form: the trunk prefix resolved the
  /// way that country resolves it. Malaysia's `0123456789` becomes
  /// `123456789`; Rome's `0612345678` keeps its zero, because there the zero
  /// is part of the number rather than a dialling prefix.
  ///
  /// Falls back to the input when the number could not be parsed.
  final String nationalNumber;

  const PhoneCheck({required this.isValid, required this.nationalNumber});
}

/// The one place that talks to `phone_numbers_parser`.
///
/// Everything else in the app deals in our own [Country], so replacing the
/// library — or the rules — means editing this file and nothing else. It also
/// keeps the package out of [Validators], which stays a set of pure string
/// functions.
class PhoneNumberRules {
  const PhoneNumberRules._();

  /// Maps our ISO code onto the library's enum.
  ///
  /// Returns null rather than throwing for a code the library does not carry.
  /// `country_dial_codes_test.dart` asserts that never happens for a country
  /// in our own table, so a null here means genuinely unknown input.
  static lib.IsoCode? isoCodeFor(Country country) {
    final wanted = country.isoCode.toUpperCase();
    for (final iso in lib.IsoCode.values) {
      if (iso.name == wanted) return iso;
    }
    return null;
  }

  /// The country's dialling prefix according to the library, without the `+`.
  ///
  /// Used by the parity test that lets [kCountries] keep literal dial codes
  /// rather than looking every one of them up on each render.
  static String? dialCodeFor(Country country) {
    final iso = isoCodeFor(country);
    if (iso == null) return null;
    return lib.PhoneNumber(isoCode: iso, nsn: '').countryCode;
  }

  /// Validates [input] as a national number dialled within [country].
  static PhoneCheck check(String input, Country country) {
    final trimmed = input.trim();
    final iso = isoCodeFor(country);
    if (iso == null || trimmed.isEmpty) {
      return PhoneCheck(isValid: false, nationalNumber: trimmed);
    }
    try {
      final parsed = lib.PhoneNumber.parse(trimmed, callerCountry: iso);
      return PhoneCheck(isValid: parsed.isValid(), nationalNumber: parsed.nsn);
    } catch (_) {
      // parse() reports malformed input by throwing. A half-typed number is
      // the normal case here — autovalidation runs on every keystroke — so it
      // is simply "not valid yet", never an error the tourist should see.
      return PhoneCheck(isValid: false, nationalNumber: trimmed);
    }
  }
}
