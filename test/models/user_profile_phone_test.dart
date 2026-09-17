// ---------------------------------------------------------------------------
// user_profile_phone_test.dart
// Profile — phone numbers saved before the country picker must survive
// ---------------------------------------------------------------------------
//
// `phoneNumber` used to hold whatever the tourist typed, trimmed and nothing
// else: "012-345 6789", "(012) 345-6789" and "+60123456789" were all stored
// verbatim. The field now holds bare national digits with the country beside
// it, so every existing document has to be re-read into that shape on load.
// Every one of them passed the old Malaysia-only validator, which is what
// makes the migration knowable rather than a guess.

import 'package:test/test.dart';
import 'package:walkpenang/constants/unit_system.dart';
import 'package:walkpenang/models/user_profile.dart';

void main() {
  Map<String, dynamic> legacy(String phone) => <String, dynamic>{
        'nickname': 'Ian',
        'weightKg': 68.0,
        'heightCm': 173.0,
        'units': 'metric',
        'phoneNumber': phone,
      };

  group('migrating a number stored before the picker existed', () {
    test('strips the trunk zero', () {
      final profile = UserProfile.fromMap(legacy('0123456789'));
      expect(profile.phoneNumber, '123456789');
      expect(profile.phoneCountryIso, 'MY');
    });

    test('strips the separators the old field allowed', () {
      expect(UserProfile.fromMap(legacy('012-345 6789')).phoneNumber,
          '123456789');
      expect(UserProfile.fromMap(legacy('(012) 345-6789')).phoneNumber,
          '123456789');
    });

    test('strips a written-out country code', () {
      expect(UserProfile.fromMap(legacy('+60123456789')).phoneNumber,
          '123456789');
      expect(UserProfile.fromMap(legacy('60123456789')).phoneNumber,
          '123456789');
      expect(UserProfile.fromMap(legacy('+60 12-345 6789')).phoneNumber,
          '123456789');
    });

    test('handles a Penang landline', () {
      expect(UserProfile.fromMap(legacy('04-226 1234')).phoneNumber,
          '42261234');
    });

    test('every legacy shape of one number lands on the same digits', () {
      const shapes = [
        '0123456789',
        '012-345 6789',
        '(012) 345-6789',
        '+60123456789',
        '60123456789',
        '+60 12-345 6789',
      ];
      final migrated =
          shapes.map((s) => UserProfile.fromMap(legacy(s)).phoneNumber).toSet();
      expect(migrated, {'123456789'});
    });
  });

  group('a profile already using the picker is left alone', () {
    test('keeps its stored country and digits', () {
      final profile = UserProfile.fromMap(<String, dynamic>{
        'nickname': 'Visitor',
        'weightKg': 68.0,
        'heightCm': 173.0,
        'units': 'imperial',
        'phoneNumber': '4155550100',
        'phoneCountryIso': 'US',
      });
      expect(profile.phoneNumber, '4155550100');
      expect(profile.phoneCountryIso, 'US');
      expect(profile.phoneCountry.dialCode, '1');
    });

    test('does not invent a country for a profile with no number', () {
      final profile = UserProfile.fromMap(<String, dynamic>{
        'nickname': 'Ian',
        'weightKg': 68.0,
        'heightCm': 173.0,
        'units': 'metric',
      });
      expect(profile.phoneNumber, isNull);
      expect(profile.phoneCountryIso, isNull);
      expect(profile.phoneDisplay, isNull);
    });
  });

  group('round-tripping through Firestore', () {
    test('toMap carries the country so the migration runs only once', () {
      final original = UserProfile.fromMap(legacy('012-345 6789'));
      final restored = UserProfile.fromMap(original.toMap());
      expect(restored.phoneNumber, '123456789');
      expect(restored.phoneCountryIso, 'MY');
      // The second read must not strip anything further — "123456789" does not
      // start with 0 or 60, but a number that did would be mangled twice.
      expect(original.toMap()['phoneCountryIso'], 'MY');
    });

    test('a national number that begins with 60 survives a second read', () {
      final stored = UserProfile.fromMap(<String, dynamic>{
        'nickname': 'Visitor',
        'weightKg': 68.0,
        'heightCm': 173.0,
        'units': 'metric',
        'phoneNumber': '601234567',
        'phoneCountryIso': 'SG',
      });
      expect(UserProfile.fromMap(stored.toMap()).phoneNumber, '601234567');
    });
  });

  group('display', () {
    test('composes the dial code with the national number', () {
      final profile = UserProfile.fromMap(legacy('0123456789'));
      expect(profile.phoneDisplay, '+60 123456789');
    });

    test('exposes the stored units as an enum', () {
      expect(UserProfile.fromMap(legacy('0123456789')).unitSystem,
          UnitSystem.metric);
    });
  });
}
