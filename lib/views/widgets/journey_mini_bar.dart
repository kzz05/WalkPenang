// Walking & Carbon Module — the minimised journey.
//
// Drawn above every route (see JourneyOverlayHost, installed in main.dart's
// MaterialApp.builder) so a journey the tourist has stepped away from is never
// out of sight. It is the only thing on screen that knows a walk is still
// being recorded while they browse Explore or read a place's reviews.

import 'package:flutter/material.dart';

import '../../controllers/journey_session.dart';
import '../../theme/app_theme.dart';

/// Wraps the app's navigator so the bar sits under every screen.
///
/// A Column rather than a Stack: shrinking the routes is what guarantees the
/// bar can never cover Home's bottom nav, a screen's own footer buttons, or
/// the map's zoom controls. Nothing has to know the bar exists to stay clear
/// of it.
class JourneyOverlayHost extends StatelessWidget {
  final Widget child;

  const JourneyOverlayHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: JourneySession.instance,
      builder: (context, _) {
        final session = JourneySession.instance;
        if (!session.isActive || !session.isMinimized) return child;

        return Column(
          children: [
            Expanded(child: child),
            const JourneyMiniBar(),
          ],
        );
      },
    );
  }
}

/// "Walking to Chew Jetty · 12:04 · 0.8 km", tap to go back to it.
///
/// Everything here is drawn *above* the app's Navigator, which means this
/// widget's own context has neither a Navigator nor an Overlay above it.
/// Anything needing either — a Tooltip, showDialog, a SnackBar — has to reach
/// down into the navigator instead of using this context, or it throws "No
/// Overlay widget found" and takes the whole app down with it. That is what
/// [_navigatorContext] is for, and why the end button carries no tooltip.
class JourneyMiniBar extends StatelessWidget {
  const JourneyMiniBar({super.key});

  /// A context inside the app's Navigator, for the things that need one.
  ///
  /// The Overlay's context rather than the Navigator's own: Navigator.of walks
  /// *ancestors*, so handing it the navigator's context would look straight
  /// past the navigator it is standing on.
  static BuildContext? get _navigatorContext =>
      JourneySession.navigatorKey.currentState?.overlay?.context;

  static String _elapsed(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return d.inHours > 0
        ? '${d.inHours}:${two(d.inMinutes.remainder(60))}:'
            '${two(d.inSeconds.remainder(60))}'
        : '${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}';
  }

  /// The same confirmation the Active Walking back arrow shows. Ending from
  /// out here abandons a journey the tourist may have half-forgotten, so it
  /// asks at least as loudly as ending from inside it does.
  Future<void> _confirmEnd() async {
    final context = _navigatorContext;
    if (context == null) return;

    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End Journey?'),
        content: const Text(
          'Are you sure you want to end your current journey?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('No', style: AppType.button.copyWith(fontSize: 14)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Yes, End Journey',
              style: AppType.button.copyWith(
                fontSize: 14,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (shouldEnd ?? false) {
      JourneySession.instance.abandon();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = JourneySession.instance.controller;
    if (controller == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final data = controller.activeWalkingUiData;
        final covered = data.kmCovered;

        return Material(
          color: AppColors.surface,
          child: SafeArea(
            top: false,
            child: InkWell(
              onTap: JourneySession.instance.expand,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Walking to ${data.destinationName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.body.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            // Distance only once the position stream has
                            // produced some: "0.0 km" before the first fix
                            // would be a figure the app has not measured.
                            covered == null
                                ? _elapsed(data.elapsedTime)
                                : '${_elapsed(data.elapsedTime)}  ·  '
                                    '${covered.toStringAsFixed(1)} km',
                            style: AppType.mono.copyWith(
                              fontSize: 11,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _confirmEnd,
                      // No tooltip: a Tooltip needs an Overlay, and there is
                      // none above the navigator. The icon is the standard
                      // dismiss affordance and the dialog names the action
                      // before anything happens.
                      icon: const Icon(Icons.close, size: 20),
                      color: AppColors.onSurface,
                    ),
                    const Icon(Icons.keyboard_arrow_up, size: 22),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
