import '../constants/country_dial_codes.dart';
import '../constants/unit_system.dart';

class UserProfile {
  final String nickname;
  final double weightKg;
  final double heightCm;

  /// Display preference only — `'metric'` or `'imperial'`. Read it through
  /// [unitSystem] rather than comparing strings.
  ///
  /// Stored as a bare string because profiles written before [UnitSystem]
  /// existed already hold one, and an enum index would make those unreadable.
  final String units;
  final String? email;
  final String? photoUrl;

  /// The national number only, digits with no dial code and no trunk `0` —
  /// e.g. `1112013343`. Pair it with [phoneCountryIso] to get a full number.
  final String? phoneNumber;

  /// ISO-3166 alpha-2 of the country whose dial code belongs in front of
  /// [phoneNumber]. Null only on a profile that has no phone number at all.
  final String? phoneCountryIso;
  final int points;

  // 📊 Home dashboard totals. They stay at zero until the Walking & Carbon
  // module starts writing to them.
  final double distanceKm;
  final double co2SavedKg;

  UserProfile({
    required this.nickname,
    required this.weightKg,
    required this.heightCm,
    required this.units,
    this.email,
    this.photoUrl,
    this.phoneNumber,
    this.phoneCountryIso,
    this.points = 0,
    this.distanceKm = 0,
    this.co2SavedKg = 0,
  });

  /// The stored [units] string as an enum, defaulting to metric.
  UnitSystem get unitSystem => UnitSystem.fromStorage(units);

  /// The country whose dial code fronts [phoneNumber]; Malaysia when unset.
  Country get phoneCountry => countryByIso(phoneCountryIso);

  /// The full international number for display, e.g. `+60 1112013343`.
  String? get phoneDisplay {
    final national = phoneNumber?.trim() ?? '';
    if (national.isEmpty) return null;
    return '${phoneCountry.displayDialCode} $national';
  }

  // 🧮 Computed BMI Getter
  double get bmi {
    if (heightCm <= 0) return 0.0;
    final heightInMeters = heightCm / 100;
    return weightKg / (heightInMeters * heightInMeters);
  }

  // 🏷️ Computed BMI Category Getter
  String get bmiCategory {
    final currentBmi = bmi;
    if (currentBmi <= 0) return 'Unknown';
    if (currentBmi < 18.5) return 'Underweight';
    if (currentBmi < 25.0) return 'Normal';
    if (currentBmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  // 🔄 copyWith helper method for updating state or partial properties
  UserProfile copyWith({
    String? nickname,
    double? weightKg,
    double? heightCm,
    String? units,
    String? email,
    String? photoUrl,
    String? phoneNumber,
    String? phoneCountryIso,
    int? points,
    double? distanceKm,
    double? co2SavedKg,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      units: units ?? this.units,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      phoneCountryIso: phoneCountryIso ?? this.phoneCountryIso,
      points: points ?? this.points,
      distanceKm: distanceKm ?? this.distanceKm,
      co2SavedKg: co2SavedKg ?? this.co2SavedKg,
    );
  }

  /// Splits a phone number written before the country picker existed.
  ///
  /// Every such number passed the old Malaysia-only validator, so it is one of
  /// `0123456789`, `60123456789`, `+60123456789` or the same with spaces,
  /// dashes, dots or brackets. Strip the decoration, then drop whichever of
  /// the country code or the trunk `0` is in front — what remains is the
  /// national number the new field expects. Lossless for every shape the old
  /// rule accepted.
  static String _nationalFromLegacy(String raw) {
    var digits = raw.replaceAll(RegExp(r'[\s\-().+]'), '');
    if (digits.startsWith('60')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  // 🛡️ CRASH-PROOF PARSER: Prevents int-to-double cast crashes and null crashes
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final storedIso = map['phoneCountryIso'] as String?;
    final storedPhone = (map['phoneNumber'] as String?)?.trim();
    final hasPhone = storedPhone != null && storedPhone.isNotEmpty;

    return UserProfile(
      nickname: map['nickname'] as String? ?? 'User',
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0.0,
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 0.0,
      units: map['units'] as String? ?? 'metric',
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      phoneNumber: !hasPhone
          ? storedPhone
          : storedIso == null || storedIso.isEmpty
              ? _nationalFromLegacy(storedPhone)
              : storedPhone,
      // A profile with a number but no country predates the picker, so it is
      // Malaysian by definition — that was the only shape the app accepted.
      phoneCountryIso: storedIso?.isNotEmpty == true
          ? storedIso
          : (hasPhone ? kDefaultCountryIso : null),
      points: (map['points'] as num?)?.toInt() ?? 0,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      co2SavedKg: (map['co2SavedKg'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'weightKg': weightKg,
      'heightCm': heightCm,
      'units': units,
      'email': email,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'phoneCountryIso': phoneCountryIso,
      'points': points,
      'distanceKm': distanceKm,
      'co2SavedKg': co2SavedKg,
    };
  }

  bool get isComplete =>
      nickname.isNotEmpty && weightKg > 0 && heightCm > 0;
}