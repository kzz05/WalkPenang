import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/place_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/distance_format.dart';
import '../../views/widgets/favorite_heart_button.dart';

/// UC-007 step 7 / UC-M04 step 1 — one result in the map's swipeable strip.
///
/// Every card the tourist sees on the home map is this one widget, rendered
/// repeatedly by the strip's `PageView.builder`, so its layout has to hold at
/// any system font size rather than only at the default one.
///
/// It lives here rather than inside map_view.dart so it can be laid out
/// directly in a test at the exact height the strip gives it — which is how
/// the bottom overflow below was caught and is kept from coming back.
class PlaceResultCard extends StatelessWidget {
  final PlaceModel place;
  final double distanceMeters;
  final bool isSelected;

  /// UC-M04: the tourist has already got a route to this place. The whole card
  /// goes grey to match its pin, so the strip shows at a glance which of the
  /// results have been dealt with.
  final bool isRouted;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback onRoute;

  const PlaceResultCard({
    super.key,
    required this.place,
    required this.distanceMeters,
    required this.isSelected,
    required this.isRouted,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onRoute,
  });

  /// The height one card needs at the ambient text scaling, excluding the
  /// strip's own padding.
  ///
  /// This lives beside the layout it measures rather than in map_view.dart,
  /// because the version that lived there had to be mirrored a second time in
  /// the widget test — and all three drifted. See [heightFor]'s test, which
  /// checks this against the card's *measured* height rather than against
  /// another copy of the formula.
  ///
  /// Each text size goes through the scaler at its own size. That is the whole
  /// point: Android 14+ scales fonts on a curve that compresses large sizes
  /// far more than small ones, so putting a single lumped number through
  /// [TextScaler] — as `124 + scale(60)` used to — badly under-predicts how
  /// much 10-15px text grows. On a real phone at the largest font setting,
  /// `scale(60)` came back as 61: no growth at all, while the card itself grew
  /// by a third and overflowed the box it had been given.
  static double heightFor(TextScaler scaler) {
    // The card's 12/10 padding, its 2px border top and bottom, and the two
    // gaps between the three rows. None of this tracks the font size.
    const double chrome = 12 + 10 + 4 + 7 + 9;

    // The heart's 28px tap target and the Route button's 32px minimum floor
    // these two rows until the text in them outgrows the control beside it.
    final double headerRow = math.max(28, scaler.scale(10) * 1.5);
    final double titleRows = 2 * scaler.scale(15) * 1.9;
    final double actionRow = math.max(32, scaler.scale(12) * 1.5);

    return chrome + headerRow + titleRows + actionRow;
  }

  @override
  Widget build(BuildContext context) {
    final isFood = place.category == 'food';
    final categoryAccent = isFood
        ? AppColors.foodPin
        : place.category == 'attraction'
            ? AppColors.attractionPin
            : AppColors.otherPin;
    // One switch drives the whole card, so a routed place can never end up
    // half grey — the category tint, the title ink and the action all move
    // together.
    final accent = isRouted ? AppColors.routedPin : categoryAccent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isRouted ? AppColors.routedSurface : Colors.white,
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: isSelected ? accent : Colors.transparent,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2B000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
        child: Column(
          // Sized by its own content, not by whatever box it is dropped into.
          // The Spacers this replaces made the card depend on the strip's
          // hard-coded height, which is how it came to overflow the bottom by
          // 18px at the *default* font size, before scaling made it worse.
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderRow(accent, isFood),
            const SizedBox(height: 7),
            // Flexible, so that if the strip ever hands this card less height
            // than [heightFor] asked for, the title gives way instead of the
            // Column overflowing. That distinction matters more than it
            // sounds: an overflowing Column pushes the action row outside the
            // card's bounds, and Flutter does not hit-test what falls outside
            // a parent — which left the Route button visible but dead at the
            // largest system font. A clipped second line is a far better
            // failure than an unusable button.
            Flexible(
              child: Text(
                place.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.body.copyWith(
                  fontSize: 15,
                  color: isRouted ? AppColors.muted : AppColors.onPrimary,
                ),
              ),
            ),
            const SizedBox(height: 9),
            _buildActionRow(),
          ],
        ),
      ),
    );
  }

  /// Category on the left, status and heart on the right.
  ///
  /// Two children and `spaceBetween`, rather than a `Spacer` between four:
  /// a Spacer is itself a flex child, so it used to take half of whatever slack
  /// there was even when it needed none, leaving the label with half the room
  /// it could have had — which is what pushed this row off the right edge.
  Widget _buildHeaderRow(Color accent, bool isFood) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isRouted
                    ? Icons.check_circle
                    : isFood
                        ? Icons.restaurant
                        : Icons.photo_camera,
                size: 13,
                color: accent,
              ),
              const SizedBox(width: 6),
              // The first thing allowed to give way: the pin's colour already
              // carries the category, so the word is the least load-bearing
              // text on the card.
              Flexible(
                child: Text(
                  isFood ? 'FOOD' : 'ATTRACTION',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.mono.copyWith(color: accent),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (place.isOpenNow) ...[
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'OPEN',
                maxLines: 1,
                style: AppType.mono.copyWith(color: AppColors.success),
              ),
            ],
            if (onToggleFavorite != null) ...[
              const SizedBox(width: 6),
              FavoriteHeartButton(
                isFavorite: isFavorite,
                onToggle: onToggleFavorite!,
                size: 18,
                dense: true,
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Rating and distance on the left, the Route action on the right.
  ///
  /// Same shape as the header, and for the same reason: "Route" is what the
  /// card exists for, so it keeps its full width and the read-out beside it
  /// ellipsises instead.
  Widget _buildActionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (place.rating != null) ...[
                const Icon(
                  Icons.star_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 3),
                // Flexible too, so at a very large font on a narrow phone the
                // whole read-out can collapse to nothing and leave the Route
                // button at full size. The rating is the most expendable thing
                // here; the action is the least.
                Flexible(
                  child: Text(
                    place.rating!.toStringAsFixed(1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.monoValue,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (distanceMeters.isFinite)
                Flexible(
                  child: Text(
                    formatDistanceMeters(distanceMeters),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.monoValue.copyWith(color: AppColors.muted),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // UC-M04 step 1: the one action that leaves this screen.
        TextButton(
          onPressed: onRoute,
          style: TextButton.styleFrom(
            backgroundColor: isRouted ? AppColors.routedPin : AppColors.primary,
            foregroundColor: isRouted ? Colors.white : AppColors.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          ),
          child: Text(
            'Route',
            maxLines: 1,
            style: AppType.button.copyWith(
              fontSize: 12,
              color: isRouted ? Colors.white : AppColors.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
