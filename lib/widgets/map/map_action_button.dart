import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The floating circular control used for every map overlay action — recentre,
/// compass mode, exit navigation.
///
/// One widget rather than a copy per screen, so the filled/outlined convention
/// stays consistent: filled blue means "this mode is currently on", white
/// means "tap to turn it on".
class MapActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  /// Filled (active) vs. white (inactive).
  final bool isActive;

  /// Optional label shown beside the icon, turning the circle into a pill —
  /// used where the action needs naming the first time a tourist sees it
  /// (e.g. "Re-centre" once they've panned away from their position).
  final String? label;

  final Color activeColor;
  final String? tooltip;

  const MapActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.label,
    this.activeColor = AppColors.navigationBlue,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isActive ? Colors.white : AppColors.onPrimary;
    final hasLabel = label != null;

    final button = Material(
      color: isActive ? activeColor : Colors.white,
      shape: hasLabel
          ? const StadiumBorder()
          : const CircleBorder(),
      elevation: 3,
      shadowColor: const Color(0x33000000),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: hasLabel ? 16 : 12,
            vertical: 12,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 22),
              if (hasLabel) ...[
                const SizedBox(width: 8),
                // Flexible, because this pill is centred inside the full map
                // width: at a large text scale "Search this area" is wider
                // than a narrow screen, and a MainAxisSize.min Row would
                // overflow rather than let the label give way.
                Flexible(
                  child: Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.button.copyWith(
                      color: foreground,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
