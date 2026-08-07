// ---------------------------------------------------------------------------
// badge_emblem.dart
// Module 5 — Reward & Achievement
// Use Case : UC510 Unlock badges
// FR       : FR-R05 Badge Gallery
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// The badge artwork itself, drawn to the badge visual specification: a
// hexagonal shield, a 12-ray sunburst clipped to the inner shield, a centred
// glyph, a sparkle accent, and a notched ribbon carrying the badge name.
//
// Drawn with CustomPainter against the spec's 120 x 140 coordinate space
// rather than loaded from assets/badges/*.svg. Same geometry, same three-tone
// palette per badge, but it needs no flutter_svg dependency and no asset
// files, so the gallery renders on a fresh clone with nothing else set up.
// BadgeModel still carries assetPath, so swapping to SVG later is a change to
// this file alone.
//
// Locked state is produced here at render time by greyscaling and fading the
// same drawing — there is never a second artwork per badge.

import 'package:flutter/material.dart';

import '../../models/badge_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/reward_constants.dart';

/// The glyph at the centre of a badge.
enum BadgeGlyph { compassRose, footprints, crown }

/// Which glyph each badge carries (badge visual specification).
///
/// Presentation only — the milestone rules never branch on badge ID. A badge
/// this map does not know about still renders, with the compass rose.
BadgeGlyph glyphFor(String badgeId) {
  switch (badgeId) {
    case RewardConstants.trailblazerBadgeId:
      return BadgeGlyph.footprints;
    case RewardConstants.penangWandererBadgeId:
      return BadgeGlyph.crown;
    default:
      return BadgeGlyph.compassRose;
  }
}

/// One badge, drawn at [size] wide. Height follows the 120:140 aspect.
class BadgeEmblem extends StatelessWidget {
  final BadgeModel badge;

  /// Width in logical pixels. The artwork scales from the spec's 120-unit box.
  final double size;

  /// A locked badge is greyscaled and faded rather than swapped for a
  /// different asset, which is how FR-R05 distinguishes the two states.
  final bool locked;

  /// Whether to draw the ribbon banner with the badge name. Suppressed on the
  /// small gallery tiles, where the name is already the caption underneath.
  final bool showRibbon;

  const BadgeEmblem({
    super.key,
    required this.badge,
    this.size = 96,
    this.locked = false,
    this.showRibbon = true,
  });

  /// Luminance-weighted greyscale. Applied to the drawing rather than baked
  /// into a second asset.
  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final scale = size / _BadgeGeometry.viewWidth;
    final height = _BadgeGeometry.viewHeight * scale;

    Widget artwork = SizedBox(
      width: size,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _BadgeEmblemPainter(
                hue: Color(badge.hue),
                glyph: glyphFor(badge.id),
                showRibbon: showRibbon,
              ),
            ),
          ),
          if (showRibbon)
            Positioned(
              left: _BadgeGeometry.ribbonTextLeft * scale,
              top: _BadgeGeometry.ribbonTextTop * scale,
              width: _BadgeGeometry.ribbonTextWidth * scale,
              height: _BadgeGeometry.ribbonTextHeight * scale,
              // The name is a real Text rather than a TextPainter inside the
              // painter, so it picks up the app type ramp and is not left
              // showing a fallback face if Google Fonts resolves late.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  badge.name.toUpperCase(),
                  maxLines: 1,
                  style: AppType.mono.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (locked) {
      artwork = Opacity(
        opacity: RewardTokens.lockedBadgeOpacity,
        child: ColorFiltered(colorFilter: _greyscale, child: artwork),
      );
    }

    return artwork;
  }
}

/// The spec's 120 x 140 coordinate space, named once so the painter and the
/// ribbon label cannot drift apart.
class _BadgeGeometry {
  const _BadgeGeometry._();

  static const double viewWidth = 120;
  static const double viewHeight = 140;

  /// Outer hexagonal shield.
  static const List<Offset> outerShield = [
    Offset(60, 4),
    Offset(102, 26),
    Offset(102, 84),
    Offset(60, 118),
    Offset(18, 84),
    Offset(18, 26),
  ];

  /// Inner shield, inset by roughly 8 units.
  static const List<Offset> innerShield = [
    Offset(60, 14),
    Offset(94, 32),
    Offset(94, 80),
    Offset(60, 106),
    Offset(26, 80),
    Offset(26, 32),
  ];

  /// Centre the sunburst radiates from and the glyph sits on.
  static const Offset core = Offset(60, 55);

  static const Offset sparkle = Offset(38, 42);

  /// The banner sits across the lower third rather than below the shield, so
  /// the shield's bottom point still shows underneath it.
  static const double ribbonTop = 86;
  static const double ribbonBottom = 110;
  static const double ribbonLeft = 6;
  static const double ribbonRight = 114;

  /// Inset from the notches so the name never runs into them.
  static const double ribbonTextLeft = 20;
  static const double ribbonTextTop = 90;
  static const double ribbonTextWidth = 80;
  static const double ribbonTextHeight = 16;
}

class _BadgeEmblemPainter extends CustomPainter {
  final Color hue;
  final BadgeGlyph glyph;
  final bool showRibbon;

  _BadgeEmblemPainter({
    required this.hue,
    required this.glyph,
    required this.showRibbon,
  });

  /// The three tones the spec calls for, derived from the single badge hue so
  /// a palette change is one constant in reward_constants.dart.
  Color get _dark => _shift(hue, 0.62);
  Color get _mid => hue;
  Color get _light => _lighten(hue, 0.42);

  static Color _shift(Color base, double factor) {
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness * factor).clamp(0.0, 1.0)).toColor();
  }

  static Color _lighten(Color base, double amount) {
    final hsl = HSLColor.fromColor(base);
    final lightness = hsl.lightness + (1 - hsl.lightness) * amount;
    return hsl.withLightness(lightness.clamp(0.0, 1.0)).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Everything below is authored in the spec's 120 x 140 space and scaled
    // once here, so the geometry constants stay readable against the spec.
    canvas.save();
    canvas.scale(
      size.width / _BadgeGeometry.viewWidth,
      size.height / _BadgeGeometry.viewHeight,
    );

    final outer = _polygon(_BadgeGeometry.outerShield);
    final inner = _polygon(_BadgeGeometry.innerShield);

    canvas.drawPath(outer, Paint()..color = _dark);
    canvas.drawPath(inner, Paint()..color = _mid);

    _paintSunburst(canvas, inner);
    _paintGlyph(canvas);
    _paintSparkle(canvas);

    if (showRibbon) _paintRibbon(canvas);

    canvas.restore();
  }

  Path _polygon(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  /// Twelve rays in alternating tones, clipped to the inner shield so they
  /// stop at its edge instead of spilling over the outline.
  void _paintSunburst(Canvas canvas, Path innerShield) {
    canvas.save();
    canvas.clipPath(innerShield);

    const rayCount = 12;
    const sweep = 2 * 3.141592653589793 / rayCount;
    const radius = 90.0;
    const centre = _BadgeGeometry.core;
    final paint = Paint()..color = _light.withValues(alpha: 0.55);

    for (var i = 0; i < rayCount; i += 2) {
      final start = i * sweep;
      final path = Path()
        ..moveTo(centre.dx, centre.dy)
        ..arcTo(
          Rect.fromCircle(center: centre, radius: radius),
          start,
          sweep,
          false,
        )
        ..close();
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  void _paintGlyph(Canvas canvas) {
    final paint = Paint()..color = _dark;
    switch (glyph) {
      case BadgeGlyph.compassRose:
        _paintCompassRose(canvas, paint);
      case BadgeGlyph.footprints:
        _paintFootprints(canvas, paint);
      case BadgeGlyph.crown:
        _paintCrown(canvas, paint);
    }
  }

  /// Explorer — a four-point star with shorter diagonal points and a hub.
  void _paintCompassRose(Canvas canvas, Paint paint) {
    const c = _BadgeGeometry.core;
    const long = 22.0;
    const short = 12.0;
    const waist = 5.0;

    final cardinal = Path()
      ..moveTo(c.dx, c.dy - long)
      ..lineTo(c.dx + waist, c.dy - waist)
      ..lineTo(c.dx + long, c.dy)
      ..lineTo(c.dx + waist, c.dy + waist)
      ..lineTo(c.dx, c.dy + long)
      ..lineTo(c.dx - waist, c.dy + waist)
      ..lineTo(c.dx - long, c.dy)
      ..lineTo(c.dx - waist, c.dy - waist)
      ..close();
    canvas.drawPath(cardinal, paint);

    // The diagonals are a second, smaller star rotated 45 degrees, drawn in
    // the light tone so the cardinal points still read as the primary axis.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(3.141592653589793 / 4);
    final diagonal = Path()
      ..moveTo(0, -short)
      ..lineTo(3, -3)
      ..lineTo(short, 0)
      ..lineTo(3, 3)
      ..lineTo(0, short)
      ..lineTo(-3, 3)
      ..lineTo(-short, 0)
      ..lineTo(-3, -3)
      ..close();
    canvas.drawPath(diagonal, Paint()..color = _light);
    canvas.restore();

    canvas.drawCircle(c, 3.4, Paint()..color = _light);
  }

  /// Trailblazer — a staggered pair of footprints.
  void _paintFootprints(Canvas canvas, Paint paint) {
    const c = _BadgeGeometry.core;

    void foot(double dx, double dy, double tilt) {
      canvas.save();
      canvas.translate(c.dx + dx, c.dy + dy);
      canvas.rotate(tilt);

      // Sole.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(0, 2), width: 13, height: 20),
          const Radius.circular(6.5),
        ),
        paint,
      );
      // Toes, largest inboard.
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(-3, -12), width: 6, height: 5),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(3.5, -11), width: 5, height: 4.5),
        paint,
      );
      canvas.restore();
    }

    foot(-11, -4, -0.18);
    foot(11, 5, 0.18);
  }

  /// Penang Wanderer — a three-peaked crown on a banded base.
  void _paintCrown(Canvas canvas, Paint paint) {
    const c = _BadgeGeometry.core;
    final left = c.dx - 21;
    final right = c.dx + 21;
    final top = c.dy - 16;
    final base = c.dy + 10;

    final crown = Path()
      ..moveTo(left, base)
      ..lineTo(left, top + 4)
      ..lineTo(c.dx - 10.5, top + 15)
      ..lineTo(c.dx, top)
      ..lineTo(c.dx + 10.5, top + 15)
      ..lineTo(right, top + 4)
      ..lineTo(right, base)
      ..close();
    canvas.drawPath(crown, paint);

    // Jewel band across the base, in the light tone.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, base + 3, right, base + 10),
        const Radius.circular(2),
      ),
      paint,
    );
    final jewel = Paint()..color = _light;
    for (final dx in [-12.0, 0.0, 12.0]) {
      canvas.drawCircle(Offset(c.dx + dx, base + 6.5), 2.2, jewel);
    }
  }

  /// The four-point sparkle accent, white at 90%.
  void _paintSparkle(Canvas canvas) {
    const s = _BadgeGeometry.sparkle;
    const long = 7.0;
    const waist = 1.6;

    final path = Path()
      ..moveTo(s.dx, s.dy - long)
      ..quadraticBezierTo(s.dx + waist, s.dy - waist, s.dx + long, s.dy)
      ..quadraticBezierTo(s.dx + waist, s.dy + waist, s.dx, s.dy + long)
      ..quadraticBezierTo(s.dx - waist, s.dy + waist, s.dx - long, s.dy)
      ..quadraticBezierTo(s.dx - waist, s.dy - waist, s.dx, s.dy - long)
      ..close();

    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  /// Ribbon banner across the lower third, notched at both ends.
  void _paintRibbon(Canvas canvas) {
    const top = _BadgeGeometry.ribbonTop;
    const bottom = _BadgeGeometry.ribbonBottom;
    const left = _BadgeGeometry.ribbonLeft;
    const right = _BadgeGeometry.ribbonRight;
    const middle = (top + bottom) / 2;
    const notch = 11.0;

    final ribbon = Path()
      ..moveTo(left, top)
      ..lineTo(right, top)
      ..lineTo(right - notch, middle)
      ..lineTo(right, bottom)
      ..lineTo(left, bottom)
      ..lineTo(left + notch, middle)
      ..close();

    canvas.drawPath(ribbon, Paint()..color = _dark);

    // Hairline in the mid tone, so the ribbon reads as part of the badge
    // rather than a black bar laid over it.
    canvas.drawPath(
      ribbon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _mid,
    );
  }

  @override
  bool shouldRepaint(covariant _BadgeEmblemPainter old) =>
      old.hue != hue || old.glyph != glyph || old.showRibbon != showRibbon;
}
