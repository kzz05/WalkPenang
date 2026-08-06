import 'package:flutter/foundation.dart';

import 'package:walk_penang/models/place.dart';
import 'package:walk_penang/models/search_filters.dart';
import 'package:walk_penang/services/place_repository.dart';

/// What the feed is currently doing. The screen switches on this rather than
/// juggling four separate booleans.
enum FeedStatus {
  /// Nothing fetched yet.
  initial,

  /// First page in flight — show the full-screen spinner.
  loading,

  /// Have results, fetching the next page — show the footer spinner.
  loadingMore,

  /// Have results.
  ready,

  /// Request succeeded but matched nothing (T-FD01.3 zero-result state).
  empty,

  /// Request failed — show the retry card.
  error,
}

/// Owns the feed's data and paging cursor (T-FD02.2).
class DiscoveryController extends ChangeNotifier {
  DiscoveryController({required this.repository, this.pageSize = 10});

  final PlaceRepository repository;
  final int pageSize;

  final List<Place> _places = <Place>[];
  SearchFilters _filters = const SearchFilters();
  FeedStatus _status = FeedStatus.initial;
  String? _errorMessage;
  int _page = 0;
  bool _hasMore = true;
  bool _isFetching = false;
  bool _disposed = false;

  List<Place> get places => List<Place>.unmodifiable(_places);
  SearchFilters get filters => _filters;
  FeedStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  /// First load, and the retry target for the error state.
  Future<void> loadInitial() => _load(reset: true, status: FeedStatus.loading);

  /// Called by the scroll listener as the user nears the bottom.
  Future<void> loadMore() async {
    if (!_hasMore || _isFetching) return;
    if (_status != FeedStatus.ready) return;
    await _load(reset: false, status: FeedStatus.loadingMore);
  }

  /// Pull-to-refresh. Deliberately does NOT flip to [FeedStatus.loading] —
  /// RefreshIndicator already draws a spinner, and blanking the list under it
  /// makes the screen flash.
  Future<void> refresh() => _load(reset: true, status: _status);

  /// New filters from the search bar: reset the cursor and refetch page zero.
  Future<void> updateFilters(SearchFilters filters) async {
    if (filters == _filters) return;
    _filters = filters;
    await _load(reset: true, status: FeedStatus.loading);
  }

  Future<void> _load({required bool reset, required FeedStatus status}) async {
    if (_isFetching) return;
    _isFetching = true;

    final int targetPage = reset ? 0 : _page + 1;

    _status = status;
    _errorMessage = null;
    _safeNotify();

    try {
      final PlacePage result = await repository.fetchPlaces(
        filters: _filters,
        page: targetPage,
        pageSize: pageSize,
      );

      if (_disposed) return;

      if (reset) _places.clear();

      // Guard against duplicates if a refresh and a page load overlap.
      final Set<String> seen = _places.map((Place p) => p.id).toSet();
      _places.addAll(
        result.items.where((Place p) => seen.add(p.id)),
      );

      _page = result.page;
      _hasMore = result.hasMore;
      _status = _places.isEmpty ? FeedStatus.empty : FeedStatus.ready;
    } on ApiTimeoutException catch (error) {
      if (_disposed) return;
      _errorMessage = error.message;
      // A failed "load more" shouldn't throw away the pages already on screen.
      _status = _places.isEmpty ? FeedStatus.error : FeedStatus.ready;
    } on ApiFailureException catch (error) {
      if (_disposed) return;
      _errorMessage = error.message;
      _status = _places.isEmpty ? FeedStatus.error : FeedStatus.ready;
    } catch (_) {
      if (_disposed) return;
      _errorMessage = 'Something went wrong. Try again.';
      _status = _places.isEmpty ? FeedStatus.error : FeedStatus.ready;
    } finally {
      _isFetching = false;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
