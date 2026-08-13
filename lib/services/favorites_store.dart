import 'package:shared_preferences/shared_preferences.dart';

/// T-FD04.1 — persists saved place IDs across app restarts.
///
/// Only IDs are stored, not whole places: the place data belongs to the API
/// and would go stale, whereas an ID stays valid. The controller re-hydrates
/// the full objects from whatever it has loaded.
abstract class FavoritesStore {
  Future<Set<String>> loadIds();

  Future<void> saveIds(Set<String> ids);
}

class SharedPrefsFavoritesStore implements FavoritesStore {
  const SharedPrefsFavoritesStore();

  static const String _key = 'discovery.favorite_place_ids';

  @override
  Future<Set<String>> loadIds() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  @override
  Future<void> saveIds(Set<String> ids) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, ids.toList());
  }
}

/// In-memory implementation for tests, so the suite never touches disk.
class InMemoryFavoritesStore implements FavoritesStore {
  InMemoryFavoritesStore([Set<String>? initial])
      : _ids = <String>{...?initial};

  Set<String> _ids;

  /// Lets tests assert on what was actually written.
  Set<String> get ids => Set<String>.unmodifiable(_ids);

  int saveCount = 0;

  @override
  Future<Set<String>> loadIds() async => Set<String>.of(_ids);

  @override
  Future<void> saveIds(Set<String> ids) async {
    _ids = Set<String>.of(ids);
    saveCount++;
  }
}