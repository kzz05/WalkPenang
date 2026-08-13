import 'package:flutter/foundation.dart';

import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/search_filters.dart';
import 'package:walkpenang/services/place_repository.dart';

enum FeedStatus { initial, loading, loadingMore, ready, empty, error }

/// Owns the feed's data and paging cursor (T-FD02.2).
class DiscoveryController extends ChangeNotifier {
  DiscoveryController({required this.repository, this.pageSize = 8});

  final PlaceRepository repository;
  final int pageSize;

  final List<Place> _places = <Place>[];
  SearchFilters _filters = const SearchFilters();
  FeedStatus _status = FeedStatus.initial;
  String? _errorMessage;
  int _page = 0;
  int _totalCount = 0;
  bool _hasMore = true;
  bool _isFetching = false;
  bool _disposed = false;

  List<Place> get places => List<Place>.unmodifiable(_places);
  SearchFilters get filters => _filters;
  FeedStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  /// Total matching the current filters, for "Nearby you (12 places)".
  int get totalCount => _totalCount;

  Future<void> loadInitial() => _load(reset: true, status: FeedStatus.loading);

  Future<void> loadMore() async {
    if (!_hasMore || _isFetching) return;
    if (_status != FeedStatus.ready) return;
    await _load(reset: false, status: FeedStatus.loadingMore);
  }

  /// Pull-to-refresh. Deliberately keeps the current status — RefreshIndicator
  /// already draws a spinner, and blanking the grid under it makes it flash.
  Future<void> refresh() => _load(reset: true, status: _status);

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
      _places.addAll(result.items.where((Place p) => seen.add(p.id)));

      _page = result.page;
      _hasMore = result.hasMore;
      _totalCount = result.totalCount;
      _status = _places.isEmpty ? FeedStatus.empty : FeedStatus.ready;
    } on ApiTimeoutException catch (error) {
      _handleError(error.message);
    } on ApiFailureException catch (error) {
      _handleError(error.message);
    } catch (_) {
      _handleError('Something went wrong. Try again.');
    } finally {
      _isFetching = false;
      _safeNotify();
    }
  }

  void _handleError(String message) {
    if (_disposed) return;
    _errorMessage = message;
    // A failed "load more" shouldn't throw away pages already on screen.
    _status = _places.isEmpty ? FeedStatus.error : FeedStatus.ready;
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
