import 'package:flutter/material.dart';

import 'package:walkpenang/controllers/discovery_controller.dart';
import 'package:walkpenang/controllers/favorites_controller.dart';
import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/search_filters.dart';
import 'package:walkpenang/services/place_repository.dart';
import 'package:walkpenang/theme/discovery_colors.dart';
import 'package:walkpenang/views/place_detail_view.dart';
import 'package:walkpenang/views/widgets/place_grid_card.dart';
import 'package:walkpenang/views/widgets/search_filter_bar.dart';

/// Screen 01 — "Search Food & Attractions" (T-FD02.1 + T-FD02.2).
class DiscoveryFeedView extends StatefulWidget {
  const DiscoveryFeedView({
    super.key,
    required this.controller,
    required this.favorites,
    required this.repository,
  });

  final DiscoveryController controller;
  final FavoritesController favorites;
  final PlaceRepository repository;

  @override
  State<DiscoveryFeedView> createState() => _DiscoveryFeedViewState();
}

class _DiscoveryFeedViewState extends State<DiscoveryFeedView> {
  final ScrollController _scrollController = ScrollController();

  /// Start fetching this far from the bottom so the next page is usually
  /// there before the user reaches the end.
  static const double _loadMoreThreshold = 400;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    widget.controller.addListener(_onPlacesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    widget.controller.removeListener(_onPlacesChanged);
    super.dispose();
  }

  /// T-FD04.1 — attaches Place objects to favourite IDs restored from disk,
  /// so a saved place shows its heart filled as soon as it appears.
  void _onPlacesChanged() {
    widget.favorites.hydrate(widget.controller.places);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double remaining = _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    if (remaining <= _loadMoreThreshold) {
      // The controller ignores this while a fetch is running or when there
      // are no more pages, so calling it often is cheap.
      widget.controller.loadMore();
    }
  }

  void _openDetail(Place place) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PlaceDetailView(
          place: place,
          favorites: widget.favorites,
          repository: widget.repository,
        ),
      ),
    );
  }

  void _toggleFavorite(Place place) {
    final bool added = widget.favorites.toggle(place);
    ScaffoldMessenger.of(context)
    // clearSnackBars drops the whole queue, not just the visible one, so
    // rapid taps can't stack up into a toast that seems to never leave.
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(added ? 'Added to Favorites' : 'Removed from Favorites'),
          duration: const Duration(seconds: 2),
          // Lifts it clear of the bottom navigation bar. Note margin and
          // width are mutually exclusive on a floating SnackBar.
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(
            <Listenable>[widget.controller, widget.favorites],
          ),
          builder: (BuildContext context, _) {
            final DiscoveryController controller = widget.controller;

            return Column(
              children: <Widget>[
                SearchFilterBar(
                  initialFilters: controller.filters,
                  onChanged: controller.updateFilters,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: RefreshIndicator(
                    color: DiscoveryColors.tanDark,
                    onRefresh: controller.refresh,
                    child: _buildBody(context, controller),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, DiscoveryController controller) {
    switch (controller.status) {
      case FeedStatus.initial:
      case FeedStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: DiscoveryColors.tan),
        );

      case FeedStatus.error:
        return _ScrollableMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Feed unavailable',
          message: controller.errorMessage ?? 'Something went wrong.',
          actionLabel: 'Try again',
          onAction: controller.loadInitial,
        );

      case FeedStatus.empty:
        return _ScrollableMessage(
          icon: Icons.search_off_rounded,
          title: 'No matches',
          message: controller.filters.keyword.isEmpty
              ? 'Nothing fits these filters. Try widening the distance or '
              'clearing a category.'
              : 'Nothing matches "${controller.filters.keyword}". Try a '
              'shorter search or clear a filter.',
          actionLabel: 'Clear filters',
          onAction: () => controller.updateFilters(const SearchFilters()),
        );

      case FeedStatus.ready:
      case FeedStatus.loadingMore:
        return _buildGrid(context, controller);
    }
  }

  Widget _buildGrid(BuildContext context, DiscoveryController controller) {
    final List<Place> places = controller.places;
    final bool showFooter =
        controller.status == FeedStatus.loadingMore || !controller.hasMore;

    return CustomScrollView(
      controller: _scrollController,
      // Always scrollable so pull-to-refresh works even on a short list.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Nearby you (${controller.totalCount} '
                  'place${controller.totalCount == 1 ? '' : 's'})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: DiscoveryColors.ink,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              // Tuned so the image plus three text rows fit without overflow
              // at typical phone widths.
              childAspectRatio: 0.82,
            ),
            // builder only creates visible tiles — the lazy-loading half of
            // T-FD02.1, and what keeps image memory bounded on long feeds.
            delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                final Place place = places[index];
                return PlaceGridCard(
                  key: ValueKey<String>(place.id),
                  place: place,
                  isFavorite: widget.favorites.isFavorite(place),
                  onTap: () => _openDetail(place),
                  onFavoriteToggle: () => _toggleFavorite(place),
                );
              },
              childCount: places.length,
            ),
          ),
        ),
        if (showFooter)
          SliverToBoxAdapter(
            child: _FeedFooter(
              isLoading: controller.status == FeedStatus.loadingMore,
              errorMessage: controller.errorMessage,
              onRetry: controller.loadMore,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

/// Spinner while paging, a quiet end marker when exhausted, or a retry if a
/// page failed mid-scroll.
class _FeedFooter extends StatelessWidget {
  const _FeedFooter({
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: DiscoveryColors.tan),
        ),
      );
    }

    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: <Widget>[
            Text(errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          "That's everything nearby",
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: DiscoveryColors.inkMuted),
        ),
      ),
    );
  }
}

/// Full-screen state that still scrolls, so RefreshIndicator can be pulled
/// from it. A plain Center wouldn't respond to the drag.
class _ScrollableMessage extends StatelessWidget {
  const _ScrollableMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icon, size: 44, color: DiscoveryColors.inkMuted),
                    const SizedBox(height: 16),
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: DiscoveryColors.inkMuted),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 200,
                      child: FilledButton(
                        onPressed: onAction,
                        child: Text(actionLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}