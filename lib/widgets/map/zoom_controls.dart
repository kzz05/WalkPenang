import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../theme/app_theme.dart';

/// Custom +/- zoom controls for a [GoogleMap]. Used in place of the platform's
/// native zoom buttons (Android-only, and hidden until the map is touched) so
/// every screen gets the same always-visible control on both Android and iOS.
///
/// [onZoomBy], when supplied, hands the zoom back to the caller (with +1 or -1
/// zoom levels) instead of animating the camera here. The navigation screen
/// needs that: its camera is driven by the follow loop, so a zoom applied
/// behind that loop's back would be overwritten on the very next GPS frame.
class ZoomControls extends StatelessWidget {
  final GoogleMapController? mapController;
  final ValueChanged<double>? onZoomBy;

  /// Dark variant for the night-styled navigation map.
  final bool isDark;

  const ZoomControls({
    super.key,
    required this.mapController,
    this.onZoomBy,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = isDark ? const Color(0xFF1C1F22) : Colors.white;
    final foreground = isDark ? Colors.white : AppColors.onPrimary;
    final divider = isDark ? const Color(0x1FFFFFFF) : AppColors.outline;

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.smAll,
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomButton(
            icon: Icons.add,
            color: foreground,
            tooltip: 'Zoom in',
            onPressed: () => _zoom(1, CameraUpdate.zoomIn()),
          ),
          Divider(height: 1, thickness: 1, color: divider),
          _ZoomButton(
            icon: Icons.remove,
            color: foreground,
            tooltip: 'Zoom out',
            onPressed: () => _zoom(-1, CameraUpdate.zoomOut()),
          ),
        ],
      ),
    );
  }

  void _zoom(double levels, CameraUpdate update) {
    final handler = onZoomBy;
    if (handler != null) {
      handler(levels);
      return;
    }
    mapController?.animateCamera(
      update,
      duration: const Duration(milliseconds: 220),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _ZoomButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 46,
          height: 44,
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}
