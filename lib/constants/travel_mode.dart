/// Travel modes offered for a route (UC-M04 mode comparison / UC-M05 in-app
/// navigation). Motorbike is intentionally omitted — Google's Directions API
/// has no dedicated two-wheeler mode, only `driving`, `walking`, `bicycling`
/// and `transit`.
enum TravelMode { walking, driving, transit }

extension TravelModeApi on TravelMode {
  /// Google Directions API `mode` query parameter value.
  String get apiValue {
    switch (this) {
      case TravelMode.walking:
        return 'walking';
      case TravelMode.driving:
        return 'driving';
      case TravelMode.transit:
        return 'transit';
    }
  }

  /// Short label for the mode-comparison tabs (UC-M04).
  String get label {
    switch (this) {
      case TravelMode.walking:
        return 'Walk';
      case TravelMode.driving:
        return 'Drive';
      case TravelMode.transit:
        return 'Bus';
    }
  }
}
