import 'package:flutter/material.dart';

import 'package:walk_penang/controllers/discovery_controller.dart';
import 'package:walk_penang/models/place.dart';
import 'package:walk_penang/models/search_filters.dart';
import 'package:walk_penang/widgets/place_card.dart';
import 'package:walk_penang/widgets/search_filter_bar.dart';

/// T-FD02.1 + T-FD02.2 — the feed itself.
class DiscoveryFeedScreen extends StatefulWidget {
  const DiscoveryFeedScreen({super.key, required this.controller});

  final DiscoveryController controller;

  @override
  State<DiscoveryFeedScreen> createState() => _DiscoveryFeedScreenState();
}

class _DiscoveryFeedScreenState extends State<DiscoveryFeedScreen> {
  final ScrollController _scrollController = ScrollController();

  /// Start fetching this far from the bottom so the next page is usually
  /// there before the user reaches the end.
  static const double _loadMoreThreshold = 400;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double remaining = _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    if (remaining <= _loadMoreThreshold) {
      // The controller ignores this when a fetch is already running or when
      // there are no more pages, so calling it often is cheap.
      widget.controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover Penang')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (BuildContext context, _) {
          final DiscoveryController controller = widget.controller;

          return Column(
            children: <Widget>[
              SearchFilterBar(
                initialFilters: controller.filters,
                onChanged: controller.updateFilters,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.refresh,
                  child: _buildBody(context, controller),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, DiscoveryController controller) {
    switch (controller.status) {
      case FeedStatus.initial:
      case FeedStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case FeedStatus.error:
        return _ScrollableMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Feed unavailable',
          message: controller.errorMessage ?? 'Something went wrong.',
          action: FilledButton.tonal(
            onPressed: controller.loadInitial,
            child: const Text('Try again'),
          ),
        );

      case FeedStatus.empty:
        return _ScrollableMessage(
          icon: Icons.search_off_rounded,
          title: 'No matches',
          message: controller.filters.keyword.isEmpty
              ? 'Nothing fits these filters. Try widening the distance or price range.'
              : 'Nothing matches "${controller.filters.keyword}". '
              'Try a shorter search or clear a filter.',
          action: FilledButton.tonal(
            onPressed: () => controller.updateFilters(const SearchFilters()),
            child: const Text('Clear filters'),
          ),
        );

      case FeedStatus.ready:
      case FeedStatus.loadingMore:
        return _buildList(context, controller);
    }
  }

  Widget _buildList(BuildContext context, DiscoveryController controller) {
    final List<Place> places = controller.places;
    final bool showFooter =
        controller.status == FeedStatus.loadingMore || !controller.hasMore;

    return ListView.builder(
      controller: _scrollController,
      // Always scrollable so pull-to-refresh works even on a short list.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      // builder only creates visible rows — this is the lazy loading half of
      // T-FD02.1, and it's what keeps image memory bounded on long feeds.
      itemCount: places.length + (showFooter ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (index >= places.length) {
          return _FeedFooter(
            isLoading: controller.status == FeedStatus.loadingMore,
            errorMessage: controller.errorMessage,
            onRetry: controller.loadMore,
          );
        }

        final Place place = places[index];
        return PlaceCard(
          key: ValueKey<String>(place.id),
          place: place,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Open ${place.name}')),
            );
          },
        );
      },
    );
  }
}

/// Footer row: spinner while paging, a quiet end marker when the list is
/// exhausted, or a retry if a page failed mid-scroll.
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
        child: Center(child: CircularProgressIndicator()),
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
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          "That's everything nearby",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

/// Full-screen state that still scrolls, so RefreshIndicator can be pulled
/// from it. A plain Center wouldn't respond to the drag gesture.
class _ScrollableMessage extends StatelessWidget {
  const _ScrollableMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

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
                    Icon(icon, size: 48, color: theme.colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (action != null) ...<Widget>[
                      const SizedBox(height: 20),
                      action!,
                    ],
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
