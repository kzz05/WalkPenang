import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_theme.dart';

/// Draws the heading-aware "blue dot" location puck used in place of
/// [GoogleMap]'s built-in `myLocationEnabled` marker, which gives apps no
/// control over — or even guaranteed presence of — a direction indicator.
/// [Marker.rotation] then points the bitmap at the tourist's live heading.
///
/// Two variants, because the two screens need different things from it:
/// [buildLocationPuckIcon] for the browse map (UC-008), where the tourist is
/// often stationary and a wide compass cone communicates "facing this way";
/// and [buildNavigationPuckIcon] for the turn-by-turn screen (UC-M05), where
/// a bigger chevron reads clearly at close zoom on a dark map.

const double _exportScale = 3;

/// UC-008 browse-map puck: blue dot, white casing, and — when
/// [withAccuracyCone] is set — the translucent fan Google Maps shows behind
/// the dot once a compass heading is available.
Future<BitmapDescriptor> buildLocationPuckIcon({
  bool withAccuracyCone = false,
}) async {
  final double targetSize = withAccuracyCone ? 68 : 28;
  final double canvasSize = targetSize * _exportScale;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasSize, canvasSize));
  final center = Offset(canvasSize / 2, canvasSize / 2);
  final dotRadius =
      withAccuracyCone ? canvasSize * 0.155 : canvasSize / 2 - _exportScale * 2;

  if (withAccuracyCone) {
    // Wide translucent sector pointing "up" (the bitmap's own rotation then
    // carries it to the live heading), fading out towards its edge the way
    // Google's native compass-accuracy cone does.
    final cone = Path()..moveTo(center.dx, center.dy);
    const coneHalfAngleRad = 0.55; // ~63 degrees either side of "up"
    const steps = 24;
    for (var i = 0; i <= steps; i++) {
      final angle =
          -math.pi / 2 - coneHalfAngleRad + (2 * coneHalfAngleRad) * i / steps;
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
          AppColors.navigationBlue.withValues(alpha: 0.38),
          AppColors.navigationBlue.withValues(alpha: 0.0),
        ]),
    );
  }

  _drawDot(canvas, center, dotRadius);
  _drawChevron(
    canvas,
    centre: withAccuracyCone
        ? Offset(center.dx, center.dy - canvasSize * 0.015)
        : center,
    radius: dotRadius,
    scale: withAccuracyCone ? 0.6 : 1.0,
  );

  return _rasterise(recorder, canvasSize, targetSize);
}

/// UC-M05 navigation puck: the same blue identity, drawn larger and as a
/// solid chevron so it stays legible against the dark navigation map at
/// street-level zoom.
Future<BitmapDescriptor> buildNavigationPuckIcon() async {
  const double targetSize = 46;
  const double canvasSize = targetSize * _exportScale;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, canvasSize, canvasSize));
  const center = Offset(canvasSize / 2, canvasSize / 2);

  // Soft glow so the puck separates from the dark map underneath it.
  canvas.drawCircle(
    center,
    canvasSize * 0.40,
    Paint()
      ..shader = ui.Gradient.radial(center, canvasSize * 0.40, [
        AppColors.navigationBlue.withValues(alpha: 0.32),
        AppColors.navigationBlue.withValues(alpha: 0.0),
      ]),
  );

  // Arrowhead pointing "up"; Marker.rotation carries it to the live heading.
  final arrow = Path()
    ..moveTo(center.dx, canvasSize * 0.16)
    ..lineTo(canvasSize * 0.79, canvasSize * 0.82)
    ..lineTo(center.dx, canvasSize * 0.63)
    ..lineTo(canvasSize * 0.21, canvasSize * 0.82)
    ..close();

  canvas.drawPath(
    arrow,
    Paint()
      ..color = const Color(0x4D000000)
      ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 6),
  );
  canvas.drawPath(
    arrow,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = _exportScale * 2.4
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawPath(arrow, Paint()..color = AppColors.navigationBlue);

  return _rasterise(recorder, canvasSize, targetSize);
}

void _drawDot(Canvas canvas, Offset center, double radius) {
  canvas.drawCircle(
    center.translate(0, _exportScale * 0.6),
    radius,
    Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 5),
  );
  canvas.drawCircle(center, radius, Paint()..color = AppColors.navigationBlue);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = _exportScale * 1.6,
  );
}

/// Small white chevron pointing "up" inside the dot.
void _drawChevron(
  Canvas canvas, {
  required Offset centre,
  required double radius,
  required double scale,
}) {
  final chevron = Path()
    ..moveTo(centre.dx, centre.dy - radius * 0.58 * scale)
    ..lineTo(centre.dx + radius * 0.62 * scale, centre.dy + radius * 0.46 * scale)
    ..lineTo(centre.dx, centre.dy + radius * 0.12 * scale)
    ..lineTo(centre.dx - radius * 0.62 * scale, centre.dy + radius * 0.46 * scale)
    ..close();
  canvas.drawPath(chevron, Paint()..color = Colors.white);
}

Future<BitmapDescriptor> _rasterise(
  ui.PictureRecorder recorder,
  double canvasSize,
  double targetSize,
) async {
  final image = await recorder.endRecording().toImage(
    canvasSize.round(),
    canvasSize.round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  return BitmapDescriptor.bytes(
    bytes!.buffer.asUint8List(),
    width: targetSize,
    height: targetSize,
  );
}
