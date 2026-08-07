import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:walkpenang/controllers/favorites_controller.dart';
import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/review.dart';
import 'package:walkpenang/views/place_detail_view.dart';
import 'package:walkpenang/services/place_repository.dart';
import 'package:walkpenang/theme/discovery_colors.dart';

/// Screen 04 — "My Favorites".
class FavoritesView extends StatelessWidget {
  const FavoritesView({
    super.key,
    required this.favorites,
    required this.repository,
  });

  final FavoritesController favorites;
  final PlaceRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: favorites,
          builder: (BuildContext context, _) {
            final List<Place> places = favorites.places;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Text(
                    'My Favorites (${favorites.count})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: DiscoveryColors.ink,
                    ),
                  ),
                ),
                Expanded(
                  child: places.isEmpty
                      ? const _EmptyFavorites()
                      : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: places.length,
                    separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final Place place = places[index];
                      return _FavoriteTile(
                        key: ValueKey<String>(place.id),
                        place: place,
                        savedAt: favorites.savedAt(place),
                        onRemove: () => _remove(context, place),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                PlaceDetailView(
                                  place: place,
                                  favorites: favorites,
                                  repository: repository,
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _remove(BuildContext context, Place place) {
    favorites.remove(place);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed ${place.name}'),
          action: SnackBarAction(
            label: 'Undo',
            textColor: DiscoveryColors.tan,
            onPressed: () => favorites.add(place),
          ),
        ),
      );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({
    super.key,
    required this.place,
    required this.savedAt,
    required this.onRemove,
    required this.onTap,
  });

  final Place place;
  final DateTime? savedAt;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String subtitle = savedAt == null
        ? place.category.sheetLabel
        : '${place.category.chipLabel} · '
        '${Review(
      id: '',
      placeId: '',
      authorName: '',
      rating: 0,
      body: '',
      createdAt: savedAt!,
    ).relativeTime(DateTime.now())}';

    return Dismissible(
      key: ValueKey<String>('dismiss-${place.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF6D6D6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Color(0xFF8B3A3A)),
      ),
      child: Material(
        color: DiscoveryColors.creamDeep,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: place.imageUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    placeholder: (BuildContext context, String url) =>
                        Container(width: 52, height: 52, color: DiscoveryColors.cream),
                    errorWidget:
                        (BuildContext context, String url, Object error) =>
                        Container(
                          width: 52,
                          height: 52,
                          color: place.category.color,
                          child: const Icon(
                            Icons.photo_outlined,
                            size: 18,
                            color: Colors.white70,
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        place.name,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: DiscoveryColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  iconSize: 18,
                  color: DiscoveryColors.inkMuted,
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.favorite_border_rounded,
              size: 44,
              color: DiscoveryColors.inkMuted,
            ),
            const SizedBox(height: 16),
            Text('No favourites yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap the heart on any place to save it here for later.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: DiscoveryColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
