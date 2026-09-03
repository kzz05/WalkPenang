import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:walkpenang/controllers/favorites_controller.dart';
import 'package:walkpenang/models/favorite_place.dart';
import 'package:walkpenang/services/place_repository.dart';
import 'package:walkpenang/theme/app_theme.dart';
import 'package:walkpenang/views/place_detail_view.dart';

/// Screen 04 — "My Favorites" (T-FD04.2).
///
/// The list and the header count both read [FavoritesController.favorites] — a
/// single list of [FavoritePlace] — so the header can't say one number while
/// the list shows another.
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
            final List<FavoritePlace> places = favorites.favorites;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'My Favorites (${favorites.count})',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                      if (favorites.count > 0)
                        TextButton(
                          onPressed: () => _confirmClearAll(context),
                          child: Text('Clear all', style: AppType.button),
                        ),
                    ],
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
                            final FavoritePlace place = places[index];
                            return _FavoriteTile(
                              key: ValueKey<String>(place.id),
                              place: place,
                              onRemove: () => _remove(context, place),
                              onTap: () => _openDetail(context, place),
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

  void _openDetail(BuildContext context, FavoritePlace place) {
    // Use the full Place if the user has browsed it this session; otherwise a
    // minimal stand-in the detail screen enriches once its own fetch lands.
    final resolved = favorites.fullPlace(place.id) ?? place.toPlace();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PlaceDetailView(
          place: resolved,
          favorites: favorites,
          repository: repository,
        ),
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Clear all favorites?'),
            content: const Text(
              'This removes every saved place. This cannot be undone.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: AppType.button),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: AppColors.card,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.mdAll,
                  ),
                ),
                child: Text('Clear all', style: AppType.button),
              ),
            ],
          ),
        ) ??
        false;

    if (ok) {
      favorites.clear();
    }
  }

  void _remove(BuildContext context, FavoritePlace place) {
    favorites.remove(place.id);

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
          textColor: AppColors.primary,
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
    required this.onRemove,
    required this.onTap,
  });

  final FavoritePlace place;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  /// 'Food · 2 days ago'. A favourite with no real timestamp falls back to
  /// just the category.
  String _subtitle() {
    if (place.savedAt.millisecondsSinceEpoch == 0) {
      return place.categoryLabel;
    }
    return '${place.categoryLabel} · ${_ago(place.savedAt)}';
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
          color: AppColors.dangerTint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: AppColors.danger,
        ),
      ),
      child: Material(
        color: AppColors.backgroundDeep,
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
                    imageUrl: place.photoUrl ?? '',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    placeholder: (BuildContext context, String url) =>
                        Container(
                      width: 52,
                      height: 52,
                      color: AppColors.background,
                    ),
                    errorWidget:
                        (BuildContext context, String url, Object error) =>
                            Container(
                      width: 52,
                      height: 52,
                      color: AppColors.backgroundDeep,
                      child: const Icon(
                        Icons.photo_outlined,
                        size: 18,
                        color: AppColors.muted,
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
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  iconSize: 18,
                  color: AppColors.muted,
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
              color: AppColors.muted,
            ),
            const SizedBox(height: 16),
            Text('No favourites yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap the heart on any place to save it here for later.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
