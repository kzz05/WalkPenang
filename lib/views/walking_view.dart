import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../controllers/walking_controller.dart';
import '../debug/demo_journey_flow_view.dart';
import '../models/transport_mode.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'widgets/wp_components.dart';

/// Screen 01 · Transport Mode Selection (UC-W01) v2 — destination pill,
/// Walking/Driving/Public Transport cards, and the Continue CTA.
class WalkingView extends StatefulWidget {
  final UserProfile profile;

  const WalkingView({super.key, required this.profile});

  @override
  State<WalkingView> createState() => _WalkingViewState();
}

class _WalkingViewState extends State<WalkingView> {
  final WalkingController _controller = WalkingController();

  @override
  void initState() {
    super.initState();
    // Seeds the Walking module with the already-loaded profile (US-W04)
    // rather than querying ProfileStore/Firestore from within this module.
    _controller.setUserProfile(widget.profile);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A journey needs a destination, and this screen has never had one — it
  /// used to seed WalkingRouteSummary.demo, so every walk started here went
  /// to Fort Cornwallis whatever the tourist had actually been looking at.
  ///
  /// Now that the Map module offers Start Journey on a tapped place, the
  /// destination comes from there. This screen keeps UC-W01's mode choice,
  /// and hands the tourist back to the map to pick where they are going.
  void _onContinue() {
    // The Continue button is disabled until a mode is picked, so this is
    // non-null in practice; the fallback keeps the copy sensible regardless.
    final mode = _controller.selectedMode ?? TransportMode.walking;
    final message = mode == TransportMode.walking
        ? 'Tap a place on the map to see the route, then Start Journey.'
        : '${mode.label} routes are shown on the map, but only walking '
            'earns points and saves carbon.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    // Home is the map, so popping is "go and choose a destination".
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(onBack: () => Navigator.of(context).pop()),
                  const SizedBox(height: 40),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final mode in TransportMode.values) ...[
                            _TransportOptionCard(
                              mode: mode,
                              selected: _controller.selectedMode == mode,
                              walkingFeaturesEnabled:
                                  _controller.walkingFeaturesEnabled,
                              onTap: () => _controller.selectMode(mode),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ContinueButton(
                    mode: _controller.selectedMode,
                    enabled: _controller.hasSelectedMode,
                    onPressed: _onContinue,
                  ),
                  // Debug-only lecturer demo entry point (US-W05) — reuses
                  // the real Active Walking / Verify Location / Journey
                  // Completed views with fake GPS and reward dependencies,
                  // never reachable in a release build. See
                  // lib/debug/demo_journey_flow_view.dart.
                  if (kDebugMode) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DemoJourneyFlowView(),
                          ),
                        ),
                        child: const Text('Demo Walking Journey (debug)'),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Sizes this frame needs that the shared token set doesn't cover. Colours
/// and corner radii come from [AppColors]/[AppRadius] like every other module.
class _Metrics {
  const _Metrics._();

  static const avatarRadius = 12.0;
}

/// Back button, page title, and the destination pill.
class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Choose Transport',
              style: AppType.heading.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _DestinationPill(),
      ],
    );
  }
}

/// White pill showing the journey's destination — static in Sprint 1.
class _DestinationPill extends StatelessWidget {
  const _DestinationPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.mdAll,
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Fort Cornwallis',
            style: AppType.body
                .copyWith(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: WpMonoLabel('George Town Heritage Zone'),
            ),
          ),
        ],
      ),
    );
  }
}

/// One selectable transport mode card. Selecting it stores the mode on
/// [WalkingController]; feature chips only render for Walking, and only
/// once it's the selected mode — driving/public transport always show the
/// "not available" caption instead.
class _TransportOptionCard extends StatelessWidget {
  final TransportMode mode;
  final bool selected;
  final bool walkingFeaturesEnabled;
  final VoidCallback onTap;

  const _TransportOptionCard({
    required this.mode,
    required this.selected,
    required this.walkingFeaturesEnabled,
    required this.onTap,
  });

  String get _avatarLetter => switch (mode) {
        TransportMode.walking => 'W',
        TransportMode.driving => 'D',
        TransportMode.publicTransport => 'B',
      };

  String get _subtitle => switch (mode) {
        TransportMode.walking => 'ECO · HEALTH · REWARDS',
        TransportMode.driving => 'FASTEST ROUTE',
        TransportMode.publicTransport => 'RAPID PENANG',
      };

  @override
  Widget build(BuildContext context) {
    final showChips = selected && walkingFeaturesEnabled;
    final showUnavailableCaption = mode != TransportMode.walking;

    return Material(
      color: selected ? AppColors.backgroundDeep : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? null
                : const [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.outline,
                      borderRadius:
                          BorderRadius.circular(_Metrics.avatarRadius),
                    ),
                    child: Text(
                      _avatarLetter,
                      style: AppType.body.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.onPrimary : AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mode.label,
                          style: AppType.body.copyWith(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        WpMonoLabel(_subtitle),
                      ],
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 12),
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          size: 14, color: AppColors.onPrimary),
                    ),
                  ],
                ],
              ),
              if (showChips) ...[
                const SizedBox(height: 10),
                const Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _FeatureChip(
                        dotColor: AppColors.carbon, label: 'CARBON SAVINGS'),
                    _FeatureChip(
                        dotColor: AppColors.calories, label: 'CALORIES'),
                    _FeatureChip(
                        dotColor: AppColors.completion, label: 'COMPLETION'),
                    _FeatureChip(dotColor: AppColors.rewards, label: 'REWARDS'),
                  ],
                ),
              ] else if (showUnavailableCaption) ...[
                const SizedBox(height: 10),
                Text(
                  'CARBON · CALORIES · REWARDS NOT AVAILABLE',
                  style: AppType.mono
                      .copyWith(fontSize: 10, color: AppColors.subtle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A single enabled-feature pill inside the selected Walking card.
class _FeatureChip extends StatelessWidget {
  final Color dotColor;
  final String label;

  const _FeatureChip({required this.dotColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppType.mono.copyWith(
              fontSize: 9,
              letterSpacing: 0.8,
              color: AppColors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom pill CTA — disabled until a mode is picked, labeled with the
/// selected mode once one is.
class _ContinueButton extends StatelessWidget {
  final TransportMode? mode;
  final bool enabled;
  final VoidCallback onPressed;

  const _ContinueButton({
    required this.mode,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = mode == null
        ? 'Select a transport mode'
        : 'Continue with ${mode!.label}';

    return Material(
      color: enabled ? AppColors.primary : AppColors.placeholder,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppType.body.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      AppColors.onPrimary.withValues(alpha: enabled ? 1 : 0.4),
                ),
              ),
              if (enabled) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: AppColors.onPrimary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
