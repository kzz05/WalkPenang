// Debug-only UI preview for the Phase 2A Active Walking / Verify Location /
// Journey Completed screens.
//
// This is a SEPARATE app entry point — it does not run as part of the real
// WalkPenang app and is never reached from `lib/main.dart` or `HomeView`.
// Run it directly:
//
//   flutter run -t lib/debug/journey_ui_preview_main.dart
//
// Every sample below is fixed, clearly-labelled preview data — including
// the only "earned reward" values (points/badge names) that appear anywhere
// in this Phase 2A UI work outside of widget tests. None of it is reachable
// from the production app.

import 'package:flutter/material.dart';

import '../models/active_walking_ui_data.dart';
import '../models/journey_completed_ui_data.dart';
import '../models/journey_reward_ui_state.dart';
import '../models/verify_location_ui_data.dart';
import '../theme/app_theme.dart';
import '../views/active_walking_view.dart';
import '../views/journey_completed_view.dart';
import '../views/verify_location_view.dart';

void main() => runApp(const JourneyUiPreviewApp());

class JourneyUiPreviewApp extends StatelessWidget {
  const JourneyUiPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Journey UI Preview (debug only)',
      theme: buildAppTheme(),
      home: const _PreviewMenu(),
    );
  }
}

class _PreviewEntry {
  final String title;
  final WidgetBuilder builder;

  const _PreviewEntry(this.title, this.builder);
}

class _PreviewMenu extends StatelessWidget {
  const _PreviewMenu();

  static const _destination = 'Fort Cornwallis';
  static const _area = 'George Town Heritage Zone';
  static const _radius = 100.0;

  List<_PreviewEntry> get _entries => [
        _PreviewEntry(
          'Active Walking — normal',
          (_) => ActiveWalkingView(
            data: const ActiveWalkingUiData(
              destinationName: _destination,
              elapsedTime: Duration(minutes: 14, seconds: 32),
              plannedDistanceKm: 2.4,
              kmCovered: 1.1,
              minutesRemaining: 18,
              carbonSavedKg: 0.23,
              caloriesBurned: 64,
            ),
            onBack: () {},
            onOpenNavigation: () {},
            onCompleteJourney: () {},
          ),
        ),
        _PreviewEntry(
          'Active Walking — live data unavailable',
          (_) => const ActiveWalkingView(
            data: ActiveWalkingUiData(
              destinationName: _destination,
              elapsedTime: Duration(minutes: 3, seconds: 5),
              plannedDistanceKm: 2.4,
            ),
          ),
        ),
        _PreviewEntry(
          'Active Walking — completing',
          (_) => const ActiveWalkingView(
            data: ActiveWalkingUiData(
              destinationName: _destination,
              elapsedTime: Duration(minutes: 32, seconds: 10),
              plannedDistanceKm: 2.4,
              kmCovered: 2.4,
              isCompleting: true,
            ),
          ),
        ),
        _PreviewEntry(
          'Verify Location — checking',
          (_) => VerifyLocationView(
            data: const VerifyLocationUiData(
              phase: VerifyLocationPhase.checking,
              destinationName: _destination,
              radiusMeters: _radius,
            ),
            onBack: () {},
          ),
        ),
        _PreviewEntry(
          'Verify Location — verified',
          (_) => VerifyLocationView(
            data: const VerifyLocationUiData(
              phase: VerifyLocationPhase.verified,
              destinationName: _destination,
              radiusMeters: _radius,
              currentDistanceMeters: 42,
            ),
            onBack: () {},
            onCompleteJourney: () {},
          ),
        ),
        _PreviewEntry(
          'Verify Location — too far',
          (_) => VerifyLocationView(
            data: const VerifyLocationUiData(
              phase: VerifyLocationPhase.blocked,
              destinationName: _destination,
              radiusMeters: _radius,
              currentDistanceMeters: 260,
              blockReason: VerifyBlockReason.tooFar,
            ),
            onBack: () {},
            onRetry: () {},
            onContinueWalking: () {},
          ),
        ),
        _PreviewEntry(
          'Verify Location — GPS disabled',
          (_) => VerifyLocationView(
            data: const VerifyLocationUiData(
              phase: VerifyLocationPhase.blocked,
              destinationName: _destination,
              radiusMeters: _radius,
              blockReason: VerifyBlockReason.gpsDisabled,
            ),
            onBack: () {},
            onRetry: () {},
            onContinueWalking: () {},
          ),
        ),
        _PreviewEntry(
          'Verify Location — permission denied',
          (_) => VerifyLocationView(
            data: const VerifyLocationUiData(
              phase: VerifyLocationPhase.blocked,
              destinationName: _destination,
              radiusMeters: _radius,
              blockReason: VerifyBlockReason.permissionDenied,
            ),
            onBack: () {},
            onRetry: () {},
            onContinueWalking: () {},
          ),
        ),
        _PreviewEntry(
          'Verify Location — permission permanently denied',
          (_) => VerifyLocationView(
            data: const VerifyLocationUiData(
              phase: VerifyLocationPhase.blocked,
              destinationName: _destination,
              radiusMeters: _radius,
              blockReason: VerifyBlockReason.permissionDeniedForever,
            ),
            onBack: () {},
            onRetry: () {},
            onContinueWalking: () {},
          ),
        ),
        _PreviewEntry(
          'Verify Location — weak signal',
          (_) => VerifyLocationView(
            data: const VerifyLocationUiData(
              phase: VerifyLocationPhase.blocked,
              destinationName: _destination,
              radiusMeters: _radius,
              blockReason: VerifyBlockReason.weakSignal,
            ),
            onBack: () {},
            onRetry: () {},
            onContinueWalking: () {},
          ),
        ),
        _PreviewEntry(
          'Journey Completed — reward unavailable (production default)',
          (_) => JourneyCompletedView(
            data: const JourneyCompletedUiData(
              destinationName: _destination,
              destinationAreaLabel: _area,
              completedDistanceKm: 2.4,
              journeyDuration: Duration(minutes: 33, seconds: 12),
              carbonSavedKg: 0.50,
              caloriesBurned: 140,
            ),
            onBack: () {},
            onReturnHome: () {},
            onViewRewards: () {},
          ),
        ),
        _PreviewEntry(
          'Journey Completed — reward pending',
          (_) => JourneyCompletedView(
            data: const JourneyCompletedUiData(
              destinationName: _destination,
              destinationAreaLabel: _area,
              completedDistanceKm: 2.4,
              journeyDuration: Duration(minutes: 33, seconds: 12),
              carbonSavedKg: 0.50,
              caloriesBurned: 140,
              reward: JourneyRewardUiState.pending(),
            ),
            onBack: () {},
            onReturnHome: () {},
            onViewRewards: () {},
          ),
        ),
        _PreviewEntry(
          // DEBUG-ONLY MOCK DATA — the only place besides widget tests where
          // fabricated points/badge values are allowed to appear.
          'Journey Completed — reward success with new badge',
          (_) => JourneyCompletedView(
            data: const JourneyCompletedUiData(
              destinationName: _destination,
              destinationAreaLabel: _area,
              completedDistanceKm: 2.4,
              journeyDuration: Duration(minutes: 33, seconds: 12),
              carbonSavedKg: 0.50,
              caloriesBurned: 140,
              reward: JourneyRewardUiState.success(
                pointsAwarded: 15,
                newlyEarnedBadgeNames: ['Explorer'],
              ),
            ),
            onBack: () {},
            onReturnHome: () {},
            onViewRewards: () {},
          ),
        ),
        _PreviewEntry(
          'Journey Completed — reward success, no new badge',
          (_) => JourneyCompletedView(
            data: const JourneyCompletedUiData(
              destinationName: _destination,
              destinationAreaLabel: _area,
              completedDistanceKm: 2.4,
              journeyDuration: Duration(minutes: 33, seconds: 12),
              carbonSavedKg: 0.50,
              caloriesBurned: 140,
              reward: JourneyRewardUiState.success(pointsAwarded: 13),
            ),
            onBack: () {},
            onReturnHome: () {},
            onViewRewards: () {},
          ),
        ),
        _PreviewEntry(
          'Journey Completed — reward already awarded',
          (_) => JourneyCompletedView(
            data: const JourneyCompletedUiData(
              destinationName: _destination,
              destinationAreaLabel: _area,
              completedDistanceKm: 2.4,
              journeyDuration: Duration(minutes: 33, seconds: 12),
              carbonSavedKg: 0.50,
              caloriesBurned: 140,
              reward: JourneyRewardUiState.success(
                pointsAwarded: 13,
                alreadyAwarded: true,
              ),
            ),
            onBack: () {},
            onReturnHome: () {},
            onViewRewards: () {},
          ),
        ),
        _PreviewEntry(
          'Journey Completed — reward error',
          (_) => JourneyCompletedView(
            data: const JourneyCompletedUiData(
              destinationName: _destination,
              destinationAreaLabel: _area,
              completedDistanceKm: 2.4,
              journeyDuration: Duration(minutes: 33, seconds: 12),
              carbonSavedKg: 0.50,
              caloriesBurned: 140,
              reward: JourneyRewardUiState.error(
                  'Could not reach the reward service.'),
            ),
            onBack: () {},
            onReturnHome: () {},
            onViewRewards: () {},
            onRetryReward: () {},
          ),
        ),
        _PreviewEntry(
          'Journey Completed — completed distance unavailable',
          (_) => JourneyCompletedView(
            data: const JourneyCompletedUiData(
              destinationName: _destination,
              destinationAreaLabel: _area,
              // completedDistanceKm intentionally omitted (null) — the
              // screen must show "—", never the planned distance.
            ),
            onBack: () {},
            onReturnHome: () {},
            onViewRewards: () {},
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journey UI Preview (debug only)')),
      body: ListView.separated(
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return ListTile(
            title: Text(entry.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: entry.builder),
            ),
          );
        },
      ),
    );
  }
}
