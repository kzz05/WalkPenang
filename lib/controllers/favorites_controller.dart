import 'package:flutter/foundation.dart';

import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/services/favorites_store.dart';

/// T-FD04.1 / T-FD04.2 — the saved-places list, persisted across restarts.
///
/// Writes are fire-and-forget: the in-memory state updates immediately so the
/// heart icon never lags, and the disk write happens behind it. If the write
/// fails the UI is already correct, and the next toggle retries the whole set.
class FavoritesController extends ChangeNotifier {
  FavoritesController({FavoritesStore? store})
      : _store = store ?? const SharedPrefsFavoritesStore();

  final FavoritesStore _store;

  final List<Place> _saved = <Place>[];
  final Map<String, DateTime> _savedAt = <String, DateTime>{};

  /// IDs restored from disk whose Place object hasn't been seen yet. The feed
  /// calls [hydrate] as pages load, which moves them into [_saved].
  final Set<String> _pendingIds = <String>{};

  bool _loaded = false;
  bool _disposed = false;

  /// False until the first [load] completes, so the UI can avoid flashing an
  /// empty state over favourites that are about to appear.
  bool get isLoaded => _loaded;

  /// Newest first, matching the mockup's ordering.
  List<Place> get places => List<Place>.unmodifiable(_saved);

  /// Counts restored-but-not-yet-hydrated IDs too, so the badge is correct
  /// immediately on launch.
  int get count => _saved.length + _pendingIds.length;

  bool isFavorite(Place place) =>
      _savedAt.containsKey(place.id) || _pendingIds.contains(place.id);

  DateTime? savedAt(Place place) => _savedAt[place.id];

  /// Reads the persisted IDs. Call once at startup.
  Future<void> load() async {
    final Set<String> ids = await _store.loadIds();
    if (_disposed) return;
    _pendingIds
      ..clear()
      ..addAll(ids);
    _loaded = true;
    notifyListeners();
  }

  /// Attaches full Place objects to IDs restored from disk.
  ///
  /// The feed calls this with each page it loads. Places the user saved but
  /// which no longer appear in any result stay pending — they're counted but
  /// can't be rendered, which is the honest outcome for a deleted listing.
  void hydrate(Iterable<Place> candidates) {
    if (_pendingIds.isEmpty) return;

    bool changed = false;
    for (final Place place in candidates) {
      if (_pendingIds.remove(place.id)) {
        _saved.add(place);
        _savedAt[place.id] = DateTime.fromMillisecondsSinceEpoch(0);
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }

  /// Returns true if the place ended up saved, false if it was removed — the
  /// caller uses this to pick the right toast message.
  bool toggle(Place place) {
    if (isFavorite(place)) {
      remove(place);
      return false;
    }
    add(place);
    return true;
  }

  void add(Place place) {
    if (isFavorite(place)) return;
    _saved.insert(0, place);
    _savedAt[place.id] = DateTime.now();
    notifyListeners();
    _persist();
  }

  void remove(Place place) {
    if (!isFavorite(place)) return;
    _saved.removeWhere((Place p) => p.id == place.id);
    _savedAt.remove(place.id);
    _pendingIds.remove(place.id);
    notifyListeners();
    _persist();
  }

  void clear() {
    if (_saved.isEmpty && _pendingIds.isEmpty) return;
    _saved.clear();
    _savedAt.clear();
    _pendingIds.clear();
    notifyListeners();
    _persist();
  }

  /// Everything currently saved, hydrated or not.
  Set<String> get savedIds => <String>{..._savedAt.keys, ..._pendingIds};

  Future<void> _persist() async {
    try {
      await _store.saveIds(savedIds);
    } catch (error) {
      // Persistence is best-effort; in-memory state is already correct and
      // the next toggle rewrites the whole set.
      debugPrint('Failed to persist favourites: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}