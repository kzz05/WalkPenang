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
enum BadgeGlyph {
  compassRose,
  firstFootprint,
  footprints,
  landmark,
  pearl,
  crown,
  summitFlag,
  leaf,
  star,
  gem,
}

/// Which glyph each badge carries (badge visual specification).
///
/// Presentation only — the milestone rules never branch on badge ID. A badge
/// this map does not know about still renders, with the compass rose, so a
/// badge seeded into Firestore ahead of this file still shows up in the
/// gallery rather than crashing it.
BadgeGlyph glyphFor(String badgeId) {
  switch (badgeId) {
    case RewardConstants.firstStepsBadgeId:
      return BadgeGlyph.firstFootprint;
    case RewardConstants.trailblazerBadgeId:
      return BadgeGlyph.footprints;
    case RewardConstants.sightseerBadgeId:
      return BadgeGlyph.landmark;
    case RewardConstants.pearlPathfinderBadgeId:
      return BadgeGlyph.pearl;
    case RewardConstants.penangWandererBadgeId:
      return BadgeGlyph.crown;
    case RewardConstants.centuryWalkerBadgeId:
      return BadgeGlyph.summitFlag;
    case RewardConstants.greenStriderBadgeId:
      return BadgeGlyph.leaf;
    case RewardConstants.pointCollectorBadgeId:
      return BadgeGlyph.star;
    case RewardConstants.rewardLegendBadgeId:
      return BadgeGlyph.gem;
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
      case BadgeGlyph.firstFootprint:
        _paintFirstFootprint(canvas, paint);
      case BadgeGlyph.landmark:
        _paintLandmark(canvas, paint);
      case BadgeGlyph.pearl:
        _paintPearl(canvas, paint);
      case BadgeGlyph.summitFlag:
        _paintSummitFlag(canvas, paint);
      case BadgeGlyph.leaf:
        _paintLeaf(canvas, paint);
      case BadgeGlyph.star:
        _paintStar(canvas, paint);
      case BadgeGlyph.gem:
        _paintGem(canvas, paint);
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

  /// One footprint, offset from the core by [dx] and [dy] and tilted by
  /// [tilt] radians. Shared by First Steps and Trailblazer.
  void _paintFoot(
    Canvas canvas,
    Paint paint,
    double dx,
    double dy,
    double tilt, {
    double scale = 1,
  }) {
    const c = _BadgeGeometry.core;

    canvas.save();
    canvas.translate(c.dx + dx, c.dy + dy);
    canvas.rotate(tilt);
    canvas.scale(scale);

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

  /// First Steps — a single footprint, centred and enlarged.
  ///
  /// The same drawing as Trailblazer's pair rather than an unrelated shape:
  /// the two badges are the first and second rungs of the same walking
  /// ladder, and sharing the motif makes that readable at a glance.
  void _paintFirstFootprint(Canvas canvas, Paint paint) {
    _paintFoot(canvas, paint, 0, -1, 0, scale: 1.35);
  }

  /// Trailblazer — a staggered pair of footprints.
  void _paintFootprints(Canvas canvas, Paint paint) {
    _paintFoot(canvas, paint, -11, -4, -0.18);
    _paintFoot(canvas, paint, 11, 5, 0.18);
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

  /// Sightseer — a tiered pagoda, the silhouette every Penang itinerary
  /// opens with.
  void _paintLandmark(Canvas canvas, Paint paint) {
    const c = _BadgeGeometry.core;

    // Tower body first, so the eaves drawn over it read as overhanging.
    canvas.drawRect(
      Rect.fromLTRB(c.dx - 7, c.dy - 14, c.dx + 7, c.dy + 20),
      paint,
    );

    void eave(double y, double half) {
      final path = Path()
        ..moveTo(c.dx - half, y)
        ..lineTo(c.dx + half, y)
        ..lineTo(c.dx + half * 0.42, y - 7)
        ..lineTo(c.dx - half * 0.42, y - 7)
        ..close();
      canvas.drawPath(path, paint);
    }

    eave(c.dy + 20, 23);
    eave(c.dy + 6, 18);
    eave(c.dy - 8, 13);

    final light = Paint()..color = _light;
    canvas.drawCircle(Offset(c.dx, c.dy - 18), 3.2, light);
    canvas.drawRect(
      Rect.fromLTRB(c.dx - 3.5, c.dy + 11, c.dx + 3.5, c.dy + 20),
      light,
    );
  }

  /// Pearl Pathfinder — a pearl above an open, ribbed shell.
  void _paintPearl(Canvas canvas, Paint paint) {
    const c = _BadgeGeometry.core;
    final hinge = Offset(c.dx, c.dy + 12);

    // The lower half of an ellipse, so the shell's flat edge faces the pearl.
    canvas.drawArc(
      Rect.fromCenter(center: hinge, width: 46, height: 36),
      0,
      3.141592653589793,
      true,
      paint,
    );

    // Ribs fanning from the hinge to the shell edge. The endpoints are
    // written out rather than swept with sin and cos, which keeps this file
    // free of a dart:math import and the geometry checkable by eye.
    final rib = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _light;
    for (final end in const [
      Offset(-21, 7),
      Offset(-13, 15),
      Offset(0, 18),
      Offset(13, 15),
      Offset(21, 7),
    ]) {
      canvas.drawLine(hinge, hinge + end, rib);
    }

    final pearl = Offset(c.dx, c.dy - 6);
    canvas.drawCircle(pearl, 10.5, paint);
    canvas.drawCircle(pearl, 8, Paint()..color = _light);
    canvas.drawCircle(
      Offset(pearl.dx - 2.6, pearl.dy - 3),
      2.4,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  /// Century Walker — a flag planted on the taller of two peaks.
  void _paintSummitFlag(Canvas canvas, Paint paint) {
    const c = _BadgeGeometry.core;

    final ridge = Path()
      ..moveTo(c.dx - 25, c.dy + 20)
      ..lineTo(c.dx - 7, c.dy - 8)
      ..lineTo(c.dx + 4, c.dy + 6)
      ..lineTo(c.dx + 11, c.dy - 3)
      ..lineTo(c.dx + 25, c.dy + 20)
      ..close();
    canvas.drawPath(ridge, paint);

    // Snow cap on the taller peak.
    final cap = Path()
      ..moveTo(c.dx - 7, c.dy - 8)
      ..lineTo(c.dx + 1, c.dy + 3)
      ..lineTo(c.dx - 3, c.dy + 4)
      ..lineTo(c.dx - 8, c.dy)
      ..lineTo(c.dx - 12, c.dy + 3)
      ..close();
    canvas.drawPath(cap, Paint()..color = _light);

    canvas.drawRect(
      Rect.fromLTRB(c.dx - 8, c.dy - 28, c.dx - 6, c.dy - 8),
      paint,
    );
    final pennant = Path()
      ..moveTo(c.dx - 6, c.dy - 28)
      ..lineTo(c.dx + 10, c.dy - 23)
      ..lineTo(c.dx - 6, c.dy - 18)
      ..close();
    canvas.drawPath(pennant, Paint()..color = _light);
  }

  /// Green Strider — a leaf with its midrib and two veins.
  void _paintLeaf(Canvas canvas, Paint paint) {
    const c = _BadgeGeometry.core;

    final leaf = Path()
      ..moveTo(c.dx, c.dy - 21)
      ..quadraticBezierTo(c.dx + 21, c.dy - 7, c.dx, c.dy + 19)
      ..quadraticBezierTo(c.dx - 21, c.dy - 7, c.dx, c.dy - 21)
      ..close();
    canvas.drawPath(leaf, paint);

    final vein = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = _light;

    canvas.drawLine(Offset(c.dx, c.dy - 16), Offset(c.dx, c.dy + 15), vein);
    canvas.drawLine(Offset(c.dx, c.dy - 4), Offset(c.dx + 9, c.dy - 10), vein);
    canvas.drawLine(Offset(c.dx, c.dy + 6), Offset(c.dx - 9, c.dy + 1), vein);
  }

  /// A five-pointed star centred on the core, [outer] to the tips and
  /// [inner] to the valleys between them.
  ///
  /// The vertex directions are written out as unit offsets rather than swept
  /// with sin and cos, for the same reason the shell ribs are.
  static Path _starPath(double outer, double inner) {
    const c = _BadgeGeometry.core;
    const tips = [
      Offset(0, -1),
      Offset(0.9511, -0.3090),
      Offset(0.5878, 0.8090),
      Offset(-0.5878, 0.8090),
      Offset(-0.9511, -0.3090),
    ];
    const valleys = [
      Offset(0.5878, -0.8090),
      Offset(0.9511, 0.3090),
      Offset(0, 1),
      Offset(-0.9511, 0.3090),
      Offset(-0.5878, -0.8090),
    ];

    final path = Path();
    for (var i = 0; i < tips.length; i++) {
      final tip = Offset(c.dx + tips[i].dx * outer, c.dy + tips[i].dy * outer);
      if (i == 0) {
        path.moveTo(tip.dx, tip.dy);
      } else {
        path.lineTo(tip.dx, tip.dy);
      }
      path.lineTo(
        c.dx + valleys[i].dx * inner,
        c.dy + valleys[i].dy * inner,
      );
    }
    return path..close();
  }

  /// Point Collector — a star with a second, lighter star inset.
  void _paintStar(Canvas canvas, Paint paint) {
    canvas.drawPath(_starPath(23, 9.5), paint);
    canvas.drawPath(_starPath(11, 4.5), Paint()..color = _light);
  }

  /// Reward Legend — a brilliant-cut gem, faceted in the light tone.
  void _paintGem(Canvas canvas, Paint paint) {
    const c = _BadgeGeometry.core;
    const top = -17.0;
    const girdle = -5.0;
    const culet = 21.0;
    const halfCrown = 12.0;
    const halfGirdle = 21.0;

    final gem = Path()
      ..moveTo(c.dx - halfCrown, c.dy + top)
      ..lineTo(c.dx + halfCrown, c.dy + top)
      ..lineTo(c.dx + halfGirdle, c.dy + girdle)
      ..lineTo(c.dx, c.dy + culet)
      ..lineTo(c.dx - halfGirdle, c.dy + girdle)
      ..close();
    canvas.drawPath(gem, paint);

    final facet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _light;

    // The girdle, then the crown and pavilion facets that land on it.
    canvas.drawLine(Offset(c.dx - halfGirdle, c.dy + girdle),
        Offset(c.dx + halfGirdle, c.dy + girdle), facet);
    canvas.drawLine(Offset(c.dx - halfCrown, c.dy + top),
        Offset(c.dx - halfCrown, c.dy + girdle), facet);
    canvas.drawLine(Offset(c.dx + halfCrown, c.dy + top),
        Offset(c.dx + halfCrown, c.dy + girdle), facet);
    canvas.drawLine(Offset(c.dx - halfCrown, c.dy + girdle),
        Offset(c.dx, c.dy + culet), facet);
    canvas.drawLine(Offset(c.dx + halfCrown, c.dy + girdle),
        Offset(c.dx, c.dy + culet), facet);
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
