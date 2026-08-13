import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:walkpenang/controllers/favorites_controller.dart';
import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/services/place_repository.dart';
import 'package:walkpenang/theme/discovery_colors.dart';
import 'package:walkpenang/views/place_detail_view.dart';

/// Screen 04 — "My Favorites" (T-FD04.2).
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
                    separatorBuilder:
                        (BuildContext context, int index) =>
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

    // Captured before the callback: reaching for ScaffoldMessenger.of inside
    // onPressed risks a stale context once the list has rebuilt.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    messenger.clearSnackBars();

    final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller =
    messenger.showSnackBar(
      SnackBar(
        content: Text('Removed ${place.name}'),
        // Effectively disabled — the Timer below owns the lifetime instead.
        // SnackBar's own duration is chained to its exit animation, which
        // never fires if the device has animations turned off.
        duration: const Duration(days: 1),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        action: SnackBarAction(
          label: 'Undo',
          textColor: DiscoveryColors.tan,
          onPressed: () => favorites.add(place),
        ),
      ),
    );

    // Hard guarantee that it goes away, animations or not.
    Timer(const Duration(seconds: 2), controller.close);
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

  /// 'Food · 2 days ago'. Favourites restored from disk have no real
  /// timestamp, so they fall back to just the category.
  String _subtitle() {
    if (savedAt == null || savedAt!.millisecondsSinceEpoch == 0) {
      return place.category.sheetLabel;
    }
    return '${place.category.chipLabel} · ${_ago(savedAt!)}';
  }

  static String _ago(DateTime time) {
    final Duration delta = DateTime.now().difference(time);
    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
    if (delta.inHours < 24) {
      return '${delta.inHours} hour${delta.inHours == 1 ? '' : 's'} ago';
    }
    if (delta.inDays < 7) {
      return '${delta.inDays} day${delta.inDays == 1 ? '' : 's'} ago';
    }
    final int weeks = delta.inDays ~/ 7;
    return '$weeks week${weeks == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Dismissible(
      key: ValueKey<String>('dismiss-${place.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: DiscoveryColors.errorBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: DiscoveryColors.errorInk,
        ),
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
                        Container(
                          width: 52,
                          height: 52,
                          color: DiscoveryColors.cream,
                        ),
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
                        _subtitle(),
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