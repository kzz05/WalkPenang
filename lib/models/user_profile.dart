class UserProfile {
  final String nickname;
  final double weightKg;
  final double heightCm;
  final String units;
  final String? email;
  final String? photoUrl;
  final String? phoneNumber;
  final int points;

  UserProfile({
    required this.nickname,
    required this.weightKg,
    required this.heightCm,
    required this.units,
    this.email,
    this.photoUrl,
    this.phoneNumber,
    this.points = 0,
  });

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
    int? points,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      units: units ?? this.units,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      points: points ?? this.points,
    );
  }

  // 🛡️ CRASH-PROOF PARSER: Prevents int-to-double cast crashes and null crashes
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      nickname: map['nickname'] as String? ?? 'User',
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0.0,
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 0.0,
      units: map['units'] as String? ?? 'metric',
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      points: (map['points'] as num?)?.toInt() ?? 0,
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
      'points': points,
    };
  }

  bool get isComplete =>
      nickname.isNotEmpty && weightKg > 0 && heightCm > 0;
}