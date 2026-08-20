import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../theme/app_theme.dart';

/// Custom +/- zoom controls for a [GoogleMap]. Used in place of the
/// platform's native zoom buttons (Android-only, and hidden until the map is
/// touched) so every screen gets the same always-visible control on both
/// Android and iOS.
class ZoomControls extends StatelessWidget {
  final GoogleMapController? mapController;

  const ZoomControls({super.key, required this.mapController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.smAll,
        boxShadow: [
          BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.onPrimary),
            onPressed: () =>
                mapController?.animateCamera(CameraUpdate.zoomIn()),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.outline),
          IconButton(
            icon: const Icon(Icons.remove, color: AppColors.onPrimary),
            onPressed: () =>
                mapController?.animateCamera(CameraUpdate.zoomOut()),
          ),
        ],
      ),
    );
  }
}
