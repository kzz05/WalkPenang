import 'package:flutter/foundation.dart';

import '../models/transport_mode.dart';

class WalkingController extends ChangeNotifier {
  TransportMode? _selectedMode;

  TransportMode? get selectedMode => _selectedMode;

  bool get hasSelectedMode => _selectedMode != null;

  bool get walkingFeaturesEnabled =>
      _selectedMode == TransportMode.walking;

  void selectMode(TransportMode mode) {
    if (_selectedMode == mode) return;

    _selectedMode = mode;
    notifyListeners();
  }
}