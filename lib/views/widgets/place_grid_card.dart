import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/theme/app_theme.dart';
import 'package:walkpenang/views/widgets/favorite_heart_button.dart';
import 'package:walkpenang/views/widgets/star_rating.dart';

/// T-FD02.1 — one tile in the discovery grid (screen 01).
///
/// [CachedNetworkImage] gives disk caching for free plus the two states that
/// matter offline: [placeholder] while bytes arrive, [errorWidget] when they
/// never do. Both reserve the same height, so the grid never reflows.
class PlaceGridCard extends StatelessWidget {
  const PlaceGridCard({
    super.key,
    required this.place,
    required this.isFavorite,
    this.onTap,
    this.onFavoriteToggle,
    this.imageHeight = 96,
  });

  final Place place;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool openNow = place.isOpenAt(DateTime.now());

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              children: <Widget>[
                CachedNetworkImage(
                  imageUrl: place.imageUrl,
                  height: imageHeight,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder: (BuildContext context, String url) => Container(
                    height: imageHeight,
                    color: AppColors.backgroundDeep,
                  ),
                  errorWidget:
                      (BuildContext context, String url, Object error) =>
                      Container(
                        height: imageHeight,
                        color: place.category.color,
                        child: const Center(
                          child: Icon(
                            Icons.photo_outlined,
                            color: AppColors.muted,
                            size: 22,
                          ),
                        ),
                      ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _CategoryBadge(category: place.category),
                ),
                if (onFavoriteToggle != null)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: FavoriteHeartButton(
                      isFavorite: isFavorite,
                      onToggle: onFavoriteToggle!,
                      size: 18,
                      onImage: true,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    place.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.onPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${place.distanceLabel} · ${openNow ? 'Open now' : 'Closed'}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: openNow ? AppColors.muted : AppColors.danger,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: <Widget>[
                      StarRating(rating: place.rating, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        place.rating.toStringAsFixed(1),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final PlaceCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: category.color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category.badge,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.onPrimary,
        ),
      ),
    );
  }
}
