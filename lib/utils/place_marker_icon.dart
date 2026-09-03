import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_theme.dart';

/// Canvas-drawn map pins for UC-007's nearby results and UC-M04/UC-M05's
/// origin and destination markers.
///
/// [BitmapDescriptor.defaultMarkerWithHue] can only recolour Google's stock
/// balloon, which means every pin looks identical apart from its hue and none
/// of them look like they belong to WalkPenang. Drawing them here instead
/// gets a category glyph inside each pin, a selected state, and the app's own
/// palette — with no image assets to ship or keep in sync at three densities.

/// Which of UC-007's two pin families a place belongs to. Anything the Places
/// response typed as neither falls back to [PlaceCategoryPin.other].
enum PlaceCategoryPin { food, attraction, other }

/// Maps [PlaceModel.category] strings onto the drawn pin variants.
PlaceCategoryPin pinCategoryFor(String category) {
  switch (category) {
    case 'food':
      return PlaceCategoryPin.food;
    case 'attraction':
      return PlaceCategoryPin.attraction;
    default:
      return PlaceCategoryPin.other;
  }
}

Color _pinColor(PlaceCategoryPin category) {
  switch (category) {
    case PlaceCategoryPin.food:
      return AppColors.foodPin;
    case PlaceCategoryPin.attraction:
      return AppColors.attractionPin;
    case PlaceCategoryPin.other:
      return AppColors.otherPin;
  }
}

IconData _pinGlyph(PlaceCategoryPin category) {
  switch (category) {
    case PlaceCategoryPin.food:
      return Icons.restaurant;
    case PlaceCategoryPin.attraction:
      return Icons.photo_camera;
    case PlaceCategoryPin.other:
      return Icons.place;
  }
}

/// A nearby-place pin (UC-007). [selected] draws the same pin larger and with
/// a halo, so tapping a card in the results strip visibly picks out its pin
/// on the map. [favorite] recolours the body red — keeping the category glyph
/// — so the tourist can spot their saved places on the map at a glance.
Future<BitmapDescriptor> buildPlacePinIcon({
  required PlaceCategoryPin category,
  bool selected = false,
  bool favorite = false,
}) {
  final Color fill = favorite ? AppColors.danger : _pinColor(category);
  return _buildPin(
    fill: fill,
    glyph: _pinGlyph(category),
    width: selected ? 54 : 40,
    haloColor: selected ? fill.withValues(alpha: 0.25) : null,
  );
}

/// The chosen destination on the route summary and navigation maps — black
/// with the brand terracotta glyph, so it reads as "the goal" rather than as
/// one more nearby option.
Future<BitmapDescriptor> buildDestinationPinIcon() {
  return _buildPin(
    fill: AppColors.surface,
    glyph: Icons.flag,
    glyphColor: AppColors.primary,
    width: 50,
    haloColor: AppColors.primary.withValues(alpha: 0.28),
  );
}

/// Small flat disc marking where the route starts on the summary map.
Future<BitmapDescriptor> buildOriginDotIcon() async {
  const double targetSize = 22;
  const double exportScale = 3;
  const double canvasSize = targetSize * exportScale;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, canvasSize, canvasSize));
  const center = Offset(canvasSize / 2, canvasSize / 2);

  canvas.drawCircle(
    center,
    canvasSize / 2 - exportScale,
    Paint()..color = Colors.white,
  );
  canvas.drawCircle(
    center,
    canvasSize / 2 - exportScale * 2.5,
    Paint()..color = AppColors.surface,
  );

  return _rasterise(recorder, canvasSize, targetSize);
}

/// Shared teardrop-pin painter: shadow, optional halo, white casing, filled
/// body, and a centred Material glyph.
Future<BitmapDescriptor> _buildPin({
  required Color fill,
  required IconData glyph,
  required double width,
  Color glyphColor = Colors.white,
  Color? haloColor,
}) async {
  const double exportScale = 3;
  final double canvasWidth = width * exportScale;
  // Room underneath for the teardrop's tail plus its drop shadow.
  final double canvasHeight = canvasWidth * 1.32;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
  );

  final headRadius = canvasWidth * (haloColor != null ? 0.32 : 0.40);
  final headCenter = Offset(
    canvasWidth / 2,
    canvasWidth * (haloColor != null ? 0.36 : 0.44),
  );
  final tipY = canvasHeight - canvasWidth * 0.12;

  if (haloColor != null) {
    canvas.drawCircle(headCenter, canvasWidth * 0.46, Paint()..color = haloColor);
  }

  // Contact shadow at the tip, so the pin reads as standing on the map
  // rather than floating over it.
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(canvasWidth / 2, tipY - canvasWidth * 0.01),
      width: headRadius * 1.1,
      height: headRadius * 0.34,
    ),
    Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 4),
  );

  // Teardrop: a circular head with two straight flanks meeting at the tip.
  final body = Path()
    ..addOval(Rect.fromCircle(center: headCenter, radius: headRadius))
    ..moveTo(headCenter.dx - headRadius * 0.72, headCenter.dy + headRadius * 0.70)
    ..lineTo(headCenter.dx, tipY)
    ..lineTo(headCenter.dx + headRadius * 0.72, headCenter.dy + headRadius * 0.70)
    ..close();

  canvas.drawPath(
    body,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = exportScale * 2.2
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawPath(body, Paint()..color = fill);

  _paintGlyph(
    canvas,
    glyph,
    centre: headCenter,
    size: headRadius * 1.05,
    color: glyphColor,
  );

  return _rasterise(recorder, canvasWidth, width, height: canvasHeight);
}

/// Draws a Material [IconData] onto [canvas] by rendering its code point in
/// the icon font — the only way to get an `Icons.*` glyph into a
/// [BitmapDescriptor] without shipping a separate PNG for it.
void _paintGlyph(
  Canvas canvas,
  IconData icon, {
  required Offset centre,
  required double size,
  required Color color,
}) {
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    ),
  )..layout();

  painter.paint(
    canvas,
    Offset(centre.dx - painter.width / 2, centre.dy - painter.height / 2),
  );
}

/// Turns the recorded picture into a [BitmapDescriptor] at logical
/// [targetWidth] — drawing at 3x and declaring the logical size keeps the pin
/// crisp on high-density screens without hardcoding a device pixel ratio.
Future<BitmapDescriptor> _rasterise(
  ui.PictureRecorder recorder,
  double canvasWidth,
  double targetWidth, {
  double? height,
}) async {
  final canvasHeight = height ?? canvasWidth;
  final image = await recorder.endRecording().toImage(
    canvasWidth.round(),
    canvasHeight.round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  return BitmapDescriptor.bytes(
    bytes!.buffer.asUint8List(),
    width: targetWidth,
    height: targetWidth * (canvasHeight / canvasWidth),
  );
}
