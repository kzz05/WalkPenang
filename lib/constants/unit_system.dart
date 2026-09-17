/// The measurement system the tourist reads their own body metrics in.
///
/// This is a *display* preference only. [UserProfile] always stores
/// centimetres and kilograms — BMI, the calorie model and every reward total
/// are computed from those, so the stored numbers must mean the same thing for
/// every user regardless of what they chose here.
enum UnitSystem {
  metric,
  imperial;

  /// The string persisted to `users/{uid}.units`.
  ///
  /// Kept as a bare string on the wire rather than an index so that documents
  /// written before this enum existed still read correctly, and so a glance at
  /// Firestore says `metric` rather than `0`.
  String get storageValue => name;

  /// Parses the stored preference, defaulting to metric.
  ///
  /// Anything unrecognised — a null from a profile written before the field
  /// existed, or a typo — falls back rather than throwing. A bad preference
  /// should show the wrong unit label at worst, never block a profile from
  /// loading.
  static UnitSystem fromStorage(String? value) {
    for (final system in UnitSystem.values) {
      if (system.name == value) return system;
    }
    return UnitSystem.metric;
  }
}
