/// The one transport-mode enum in the app.
///
/// It serves both modules that need the concept:
///
///   • Walking & Carbon (UC-W01) picks a mode for a journey, and the chosen
///     mode is persisted on the check-in record and gates the reward award —
///     only walking earns points and carbon (FR-W01).
///   • Map & GPS (UC-M04/UC-M05) fetches a route per mode for the
///     comparison tabs, and drives in-app navigation for the selected one.
///
/// The Map module used to carry its own `TravelMode {walking, driving,
/// transit}`. The two were merged into this one because a tourist was being
/// asked to choose a mode twice, on two screens, in two vocabularies — and
/// because only this enum's values reach Firestore, so it is the one whose
/// names have to stay stable.
///
/// Motorbike is intentionally absent: Google's Directions API has no
/// dedicated two-wheeler mode, only `driving`, `walking`, `bicycling` and
/// `transit`.
enum TransportMode {
  walking,
  driving,

  /// Bus, train, ferry — anything Google calls `transit`. Named for what the
  /// tourist sees rather than for the API, since this value is written to
  /// Firestore and read back by the reward module.
  publicTransport,
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
