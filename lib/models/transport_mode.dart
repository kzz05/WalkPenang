enum TransportMode {
  walking,
  driving,
  publicTransport,
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