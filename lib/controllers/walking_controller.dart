import 'package:flutter/foundation.dart';

import '../models/transport_mode.dart';
import '../models/walking_route_summary.dart';

/// Where the Start Journey action is in its lifecycle — drives the
/// PreWalkSummaryView button's loading/idle state.
enum JourneyStartStatus { idle, loading, success }

class WalkingController extends ChangeNotifier {
  TransportMode? _selectedMode;
  WalkingRouteSummary? _routeSummary;
  JourneyStartStatus _journeyStartStatus = JourneyStartStatus.idle;
  String? _journeyStartError;

  TransportMode? get selectedMode => _selectedMode;

  bool get hasSelectedMode => _selectedMode != null;

  bool get walkingFeaturesEnabled => _selectedMode == TransportMode.walking;

  WalkingRouteSummary? get routeSummary => _routeSummary;

  JourneyStartStatus get journeyStartStatus => _journeyStartStatus;

  String? get journeyStartError => _journeyStartError;

  void selectMode(TransportMode mode) {
    if (_selectedMode == mode) return;

    _selectedMode = mode;
    notifyListeners();
  }

  /// Called with the calculated route once it's available — today that's
  /// [WalkingRouteSummary.demo] seeded by [WalkingView], but this is the
  /// seam the Map & GPS module should call into once it can resolve a
  /// destination and calculate a real walking route.
  void setRouteSummary(WalkingRouteSummary? summary) {
    _routeSummary = summary;
    notifyListeners();
  }

  /// Validates the current route and starts the journey. Resolves once the
  /// attempt finishes — check [journeyStartStatus] and [journeyStartError]
  /// afterwards to see whether it succeeded.
  Future<void> startJourney() async {
    final summary = _routeSummary;
    if (summary == null) {
      _journeyStartError =
          'Route details are missing. Go back and choose a destination again.';
      notifyListeners();
      return;
    }

    if (!summary.isValid) {
      _journeyStartError =
          "We couldn't calculate this route. Please try again.";
      notifyListeners();
      return;
    }

    _journeyStartError = null;
    _journeyStartStatus = JourneyStartStatus.loading;
    notifyListeners();

    // Placeholder for the async confirmation a real backend/Map & GPS call
    // would need before handing off to the Active Walking Journey screen.
    await Future.delayed(const Duration(milliseconds: 500));

    _journeyStartStatus = JourneyStartStatus.success;
    notifyListeners();
  }

  /// Resets journey-start status back to idle after the caller has handled
  /// a success (e.g. shown its SnackBar), so it doesn't fire again.
  void acknowledgeJourneyStart() {
    _journeyStartStatus = JourneyStartStatus.idle;
  }
}
