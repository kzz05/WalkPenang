import 'package:flutter/material.dart';

import '../controllers/walking_controller.dart';
import '../models/transport_mode.dart';
import '../models/walking_route_summary.dart';
import '../theme/app_theme.dart';
import 'pre_walk_summary_view.dart';
import 'widgets/wp_components.dart';

/// Screen 01 · Transport Mode Selection (UC-W01) v2 — destination pill,
/// Walking/Driving/Public Transport cards, and the Continue CTA.
class WalkingView extends StatefulWidget {
  const WalkingView({super.key});

  @override
  State<WalkingView> createState() => _WalkingViewState();
}

class _WalkingViewState extends State<WalkingView> {
  final WalkingController _controller = WalkingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onContinue() {
    if (_controller.selectedMode != TransportMode.walking) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pre-Walk Summary — to be built')),
      );
      return;
    }

    // TODO(map-gps): seed this from the Map & GPS module's calculated
    // route instead of the Sprint 1 demo fallback.
    _controller.setRouteSummary(WalkingRouteSummary.demo);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreWalkSummaryView(controller: _controller),
      ),
    );
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Design constants that sit alongside [AppColors]/[AppType]/[AppRadius] —
/// values this frame needs that the shared token set doesn't define.
class _Palette {
  const _Palette._();

  static const cardRadius = 16.0;
  static const avatarRadius = 12.0;

  static const selectedTint = Color(0xFFF6E4D2);
  static const iconMuted = Color(0x12111111);
  static const iconMutedText = Color(0xFF666666);
  static const captionMuted = Color(0x59111111);
  static const cardShadow = Color(0x0F000000);

  static const carbonDot = Color(0xFF3E8E5A);
  static const caloriesDot = Color(0xFFE0713C);
  static const completionDot = Color(0xFF5B7FDB);
  static const rewardsDot = Color(0xFFE0A93C);
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
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        boxShadow: [
          BoxShadow(
            color: _Palette.cardShadow,
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
      color: selected ? _Palette.selectedTint : Colors.white,
      borderRadius: BorderRadius.circular(_Palette.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_Palette.cardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_Palette.cardRadius),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? null
                : const [
                    BoxShadow(
                      color: _Palette.cardShadow,
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
                      color: selected ? AppColors.primary : _Palette.iconMuted,
                      borderRadius:
                          BorderRadius.circular(_Palette.avatarRadius),
                    ),
                    child: Text(
                      _avatarLetter,
                      style: AppType.body.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.onPrimary
                            : _Palette.iconMutedText,
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
                        dotColor: _Palette.carbonDot, label: 'CARBON SAVINGS'),
                    _FeatureChip(
                        dotColor: _Palette.caloriesDot, label: 'CALORIES'),
                    _FeatureChip(
                        dotColor: _Palette.completionDot, label: 'COMPLETION'),
                    _FeatureChip(
                        dotColor: _Palette.rewardsDot, label: 'REWARDS'),
                  ],
                ),
              ] else if (showUnavailableCaption) ...[
                const SizedBox(height: 10),
                Text(
                  'CARBON · CALORIES · REWARDS NOT AVAILABLE',
                  style: AppType.mono
                      .copyWith(fontSize: 10, color: _Palette.captionMuted),
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
        color: Colors.white,
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
