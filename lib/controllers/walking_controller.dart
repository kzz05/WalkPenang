import 'package:flutter/foundation.dart';

import '../models/transport_mode.dart';
import '../models/user_profile.dart';
import '../models/walking_route_summary.dart';

/// Where the Start Journey action is in its lifecycle — drives the
/// PreWalkSummaryView button's loading/idle state.
enum JourneyStartStatus { idle, loading, success }

class WalkingController extends ChangeNotifier {
  TransportMode? _selectedMode;
  WalkingRouteSummary? _routeSummary;
  UserProfile? _userProfile;
  JourneyStartStatus _journeyStartStatus = JourneyStartStatus.idle;
  String? _journeyStartError;

  TransportMode? get selectedMode => _selectedMode;

  bool get hasSelectedMode => _selectedMode != null;

  bool get walkingFeaturesEnabled => _selectedMode == TransportMode.walking;

  WalkingRouteSummary? get routeSummary => _routeSummary;

  /// The signed-in user's profile, as supplied by whichever screen opened
  /// the Walking module (see [WalkingView]) — reused here rather than
  /// querying ProfileStore/Firestore directly, so this module stays a
  /// consumer of the existing User Authentication & Profile Module.
  UserProfile? get userProfile => _userProfile;

  JourneyStartStatus get journeyStartStatus => _journeyStartStatus;

  String? get journeyStartError => _journeyStartError;

  /// Walking-only carbon savings (kg CO2) for [distanceKm] — 0.0 for any
  /// other selected transport mode, reusing [WalkingBenefits]'s
  /// distance-based formula and edge-case handling.
  double calculateCarbonSavings(double distanceKm) {
    if (_selectedMode != TransportMode.walking) return 0.0;
    return WalkingBenefits.calculateCarbonSavingsKg(distanceKm);
  }

  /// Carbon savings for the current [routeSummary], ready to be persisted
  /// once a journey completes. 0.0 when there's no route yet.
  double get carbonSavedKg =>
      calculateCarbonSavings(_routeSummary?.distanceKm ?? 0.0);

  /// Walking-only calorie estimate (US-W04) for the current [routeSummary]
  /// and [userProfile] — null (not 0) whenever the calculation isn't valid:
  /// Walking isn't the selected mode, the route distance is missing/zero/
  /// negative/non-finite, or the profile's body weight is missing/zero/
  /// negative/non-finite. Callers must treat null as "show the missing/
  /// invalid weight state", never as a zero calorie estimate.
  double? get caloriesBurned {
    if (_selectedMode != TransportMode.walking) return null;

    final distanceKm = _routeSummary?.distanceKm;
    if (distanceKm == null || !distanceKm.isFinite || distanceKm <= 0) {
      return null;
    }

    final bodyWeightKg = _userProfile?.weightKg;
    if (bodyWeightKg == null || !bodyWeightKg.isFinite || bodyWeightKg <= 0) {
      return null;
    }

    return WalkingBenefits.calculateCaloriesBurned(distanceKm, bodyWeightKg);
  }

  void selectMode(TransportMode mode) {
    if (_selectedMode == mode) return;

    _selectedMode = mode;
    notifyListeners();
  }

  /// Called by [WalkingView] with the currently signed-in user's profile —
  /// and again by [PreWalkSummaryView] after Edit Profile hands back an
  /// updated one — so [caloriesBurned] can be (re)computed. Mirrors
  /// [setRouteSummary]'s seam.
  void setUserProfile(UserProfile? profile) {
    _userProfile = profile;
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
