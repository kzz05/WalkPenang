import 'package:flutter/foundation.dart';

import 'package:walkpenang/models/favorite_place.dart';
import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/services/favorites_store.dart';

/// T-FD04.1 / T-FD04.2 — the one saved-places list for the whole app.
///
/// A single instance is created by [HomeView] and passed to every screen that
/// shows a heart (the map carousel, the Discovery grid, the place detail
/// screen) and to the Favorites list itself, so a toggle anywhere is reflected
/// everywhere with no reload.
///
/// The list is the source of truth: [count] is `favorites.length`, never a
/// separate id set, so the Favorites header can't drift out of sync with the
/// rows it shows.
///
/// Writes are fire-and-forget: in-memory state updates immediately so the heart
/// never lags, and the disk write happens behind it. If the write fails the UI
/// is already correct and the next toggle rewrites the whole list.
class FavoritesController extends ChangeNotifier {
  FavoritesController({FavoritesStore? store})
      : _store = store ?? FirestoreFavoritesStore();

  final FavoritesStore _store;

  /// Newest first.
  final List<FavoritePlace> _favorites = <FavoritePlace>[];

  /// Session-only cache of full [Place] objects the user has browsed, keyed by
  /// id. Lets the Favorites list open the rich detail screen for a place seen
  /// this session. Never affects [count] — it's purely a nav convenience.
  final Map<String, Place> _fullPlaces = <String, Place>{};

  bool _loaded = false;
  bool _disposed = false;

  /// False until the first [load] completes, so the UI can avoid flashing an
  /// empty state over favourites that are about to appear.
  bool get isLoaded => _loaded;

  List<FavoritePlace> get favorites => List<FavoritePlace>.unmodifiable(_favorites);

  int get count => _favorites.length;

  bool isFavorite(String placeId) =>
      _favorites.any((FavoritePlace f) => f.id == placeId);

  /// Reads the persisted favourites. Call once at startup.
  Future<void> load() async {
    final List<FavoritePlace> saved = await _store.load();
    if (_disposed) return;
    _favorites
      ..clear()
      ..addAll(saved);
    _sortNewestFirst();
    _loaded = true;
    notifyListeners();
  }

  /// Returns true if the place ended up saved, false if it was removed — the
  /// caller uses this to pick the right toast message.
  bool toggle(FavoritePlace place) {
    if (isFavorite(place.id)) {
      remove(place.id);
      return false;
    }
    add(place);
    return true;
  }

  void add(FavoritePlace place) {
    if (isFavorite(place.id)) return;
    _favorites.insert(0, place);
    notifyListeners();
    _persist();
  }

  void remove(String placeId) {
    final int before = _favorites.length;
    _favorites.removeWhere((FavoritePlace f) => f.id == placeId);
    if (_favorites.length == before) return;
    notifyListeners();
    _persist();
  }

  void clear() {
    if (_favorites.isEmpty) return;
    _favorites.clear();
    notifyListeners();
    _persist();
  }

  /// Opportunistically remembers full [Place] objects as the Discovery feed
  /// loads them, so [fullPlace] can hand one back to the Favorites list. Does
  /// not touch the favourites list or [count].
  void rememberPlaces(Iterable<Place> places) {
    for (final Place place in places) {
      _fullPlaces[place.id] = place;
    }
  }

  /// The full [Place] for [placeId] if it's been seen this session, else null.
  Place? fullPlace(String placeId) => _fullPlaces[placeId];

  void _sortNewestFirst() {
    _favorites.sort((FavoritePlace a, FavoritePlace b) =>
        b.savedAt.compareTo(a.savedAt));
  }

  Future<void> _persist() async {
    try {
      await _store.save(List<FavoritePlace>.of(_favorites));
    } catch (error) {
      // Persistence is best-effort; in-memory state is already correct and the
      // next toggle rewrites the whole list.
      debugPrint('Failed to persist favourites: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
