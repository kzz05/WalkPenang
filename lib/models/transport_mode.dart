/// The one transport-mode enum in the app.
///
/// It serves both modules that need the concept:
///
///   • Walking & Carbon (UC-W01) picks a mode for a journey, and the chosen
///     mode is persisted on the check-in record and gates the reward award.
///   • Map & GPS (UC-M04/UC-M05) fetches a route per mode for the
///     comparison tabs, and drives in-app navigation for the selected one.
///
/// The Map module used to carry its own `TravelMode {walking, driving,
/// transit}`. The two were merged into this one because a tourist was being
/// asked to choose a mode twice, on two screens, in two vocabularies — and
/// because only this enum's values reach Firestore, so it is the one whose
/// names have to stay stable.
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
///
/// Motorbike is intentionally absent: Google's Directions API has no
/// dedicated two-wheeler mode, only `driving`, `walking`, `bicycling` and
/// `transit`.
enum TransportMode {
  walking(earnsPoints: true),
  driving(earnsPoints: false),

  /// Bus, train, ferry — anything Google calls `transit`. Named for what the
  /// tourist sees rather than for the API, since this value is written to
  /// Firestore and read back by the reward module.
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
  /// Full name, for the Walking module's mode cards (UC-W01).
  String get label {
    return switch (this) {
      TransportMode.walking => 'Walking',
      TransportMode.driving => 'Driving',
      TransportMode.publicTransport => 'Public Transport',
    };
  }

  /// Compact name, for the Map module's mode-comparison tabs (UC-M04) where
  /// three labels share a row.
  String get shortLabel {
    return switch (this) {
      TransportMode.walking => 'Walk',
      TransportMode.driving => 'Drive',
      TransportMode.publicTransport => 'Bus',
    };
  }

  /// Google Directions API `mode` query parameter value. Note this is where
  /// `publicTransport` becomes `transit` — the only place the two
  /// vocabularies meet.
  String get apiValue {
    return switch (this) {
      TransportMode.walking => 'walking',
      TransportMode.driving => 'driving',
      TransportMode.publicTransport => 'transit',
    };
  }
}
