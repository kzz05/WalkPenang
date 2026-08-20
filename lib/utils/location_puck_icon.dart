import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Google Maps' own location blue, reused so the puck matches the native
/// "blue dot" tourists already recognise.
const Color _navigationBlue = Color(0xFF4285F4);

/// Draws the heading-aware "blue dot" location puck used in place of
/// [GoogleMap]'s built-in `myLocationEnabled` marker, which gives apps no
/// control over — or even guaranteed presence of — a direction indicator.
/// [Marker.rotation] then points this bitmap at the tourist's live heading.
///
/// [withAccuracyCone] adds the translucent fan behind the dot that Google
/// Maps shows when a compass heading (as opposed to just a GPS fix) is
/// available — used on the map screen, where the tourist may be stationary,
/// but skipped on the in-app navigation screen, where the dot is only ever
/// shown while moving and the plain arrow reads more clearly at close zoom.
Future<BitmapDescriptor> buildLocationPuckIcon({
  bool withAccuracyCone = false,
}) async {
  final double targetSize = withAccuracyCone ? 64 : 26;
  const double exportScale = 3;
  final double canvasSize = targetSize * exportScale;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, canvasSize, canvasSize),
  );
  final center = Offset(canvasSize / 2, canvasSize / 2);
  final dotRadius = withAccuracyCone ? canvasSize * 0.16 : canvasSize / 2 - exportScale;

  if (withAccuracyCone) {
    // Wide translucent sector pointing "up" (the bitmap's own rotation then
    // carries it to the live heading), fading out towards its edge the way
    // Google's native compass-accuracy cone does.
    final cone = Path()..moveTo(center.dx, center.dy);
    const coneHalfAngleRad = 0.55; // ~63 degrees either side of "up"
    const steps = 24;
    for (var i = 0; i <= steps; i++) {
      final angle = -1.5708 - coneHalfAngleRad + (2 * coneHalfAngleRad) * i / steps;
      cone.lineTo(
        center.dx + canvasSize * 0.46 * math.cos(angle),
        center.dy + canvasSize * 0.46 * math.sin(angle),
      );
    }
    cone.close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = ui.Gradient.radial(center, canvasSize * 0.46, [
          _navigationBlue.withValues(alpha: 0.35),
          _navigationBlue.withValues(alpha: 0.0),
        ]),
    );
  }

  canvas.drawCircle(center, dotRadius, Paint()..color = _navigationBlue);
  canvas.drawCircle(
    center,
    dotRadius,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = exportScale * 1.5,
  );

  // Small white chevron pointing "up" — Marker.rotation handles pointing it
  // towards the tourist's actual heading.
  final arrowScale = withAccuracyCone ? 0.55 : 1.0;
  final arrowCenter = withAccuracyCone
      ? Offset(center.dx, center.dy - canvasSize * 0.02)
      : center;
  final arrow = Path()
    ..moveTo(arrowCenter.dx, arrowCenter.dy - dotRadius * 0.58 * arrowScale)
    ..lineTo(
      arrowCenter.dx + dotRadius * 0.62 * arrowScale,
      arrowCenter.dy + dotRadius * 0.46 * arrowScale,
    )
    ..lineTo(arrowCenter.dx, arrowCenter.dy + dotRadius * 0.12 * arrowScale)
    ..lineTo(
      arrowCenter.dx - dotRadius * 0.62 * arrowScale,
      arrowCenter.dy + dotRadius * 0.46 * arrowScale,
    )
    ..close();
  canvas.drawPath(arrow, Paint()..color = Colors.white);

  final image = await recorder.endRecording().toImage(
    canvasSize.toInt(),
    canvasSize.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  return BitmapDescriptor.bytes(
    bytes!.buffer.asUint8List(),
    width: targetSize,
    height: targetSize,
  );
}
