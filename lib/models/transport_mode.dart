/// How the tourist travels to a destination.
///
/// [earnsPoints] carries WalkPenang's central reward rule: **only a walked
/// journey earns check-in points.** Any mode may be recorded so the journey
/// itself is logged, but driving or taking the bus awards nothing — otherwise
/// a tourist could drive between destinations and out-earn someone who walked.
///
/// It is a property of the mode rather than an `if (mode == walking)` written
/// at the award site, because more than one place has to agree: the journey
/// screen promises the outcome before departure and
/// [RewardPoints.forCheckIn] applies it on arrival. A branch in each is a
/// branch that can drift. Adding a fourth mode later forces its reward status
/// to be stated here instead of inheriting whatever the `else` happened to do.
///
/// This mirrors how [WalkingController] already gates the other walking-only
/// benefits — `calculateCarbonSavings` returns 0.0 and `caloriesBurned`
/// returns null for every non-walking mode.
enum TransportMode {
  walking(earnsPoints: true),
  driving(earnsPoints: false),
  publicTransport(earnsPoints: false);

  const TransportMode({required this.earnsPoints});

  /// Whether a completed journey in this mode awards check-in points.
  ///
  /// FR-W01: "Walking-related carbon, calorie, check-in, and reward features
  /// shall only be enabled when Walking is selected."
  final bool earnsPoints;

  /// Parses the value stored on a `check_ins` document.
  ///
  /// Falls back to [walking] rather than throwing, deliberately: check-ins
  /// written before transport modes existed carry no `transportMode` field,
  /// and every one of those journeys *was* a walk — the app offered no other
  /// mode. Any other default would retroactively strip points from history.
  ///
  /// Because this fallback is generous, `firestore.rules` restricts the field
  /// to known values on write — otherwise an unrecognised string would be read
  /// back as "walking" and quietly earn points.
  static TransportMode fromId(String? id) {
    if (id == null) return TransportMode.walking;
    for (final mode in TransportMode.values) {
      if (mode.name == id) return mode;
    }
    return TransportMode.walking;
  }
}

extension TransportModeLabel on TransportMode {
  String get label {
    return switch (this) {
      TransportMode.walking => 'Walking',
      TransportMode.driving => 'Driving',
      TransportMode.publicTransport => 'Public Transport',
    };
  }
}
