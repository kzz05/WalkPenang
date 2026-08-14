import 'package:shared_preferences/shared_preferences.dart';

/// T-FD04.1 — persists saved place IDs across app restarts.
///
/// Only IDs are stored, not whole places: the place data belongs to the API
/// and would go stale, whereas an ID stays valid. The controller re-hydrates
/// the full objects from whatever it has loaded.
abstract class FavoritesStore {
  Future<Set<String>> loadIds();

  /// Replaces the entire stored set.
  ///
  /// **Clobbers.** Anything absent from [ids] is deleted, so this is only safe
  /// when the caller owns the whole set — a single in-process writer, or a
  /// deliberate wipe. Two screens each holding their own snapshot must not
  /// both call this: the second overwrites whatever the first added. Use
  /// [addId] / [removeId] for a single place.
  Future<void> saveIds(Set<String> ids);

  /// Saves one place without touching any other.
  ///
  /// Exists because the map and the Discovery feed both write favourites from
  /// independently-loaded snapshots; with [saveIds] alone, saving on one
  /// screen deleted whatever had been saved on the other.
  Future<void> addId(String id);

  /// Unsaves one place without touching any other.
  Future<void> removeId(String id);
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

  @override
  Future<void> addId(String id) async {
    final ids = await loadIds();
    if (!ids.add(id)) return;
    await saveIds(ids);
  }

  @override
  Future<void> removeId(String id) async {
    final ids = await loadIds();
    if (!ids.remove(id)) return;
    await saveIds(ids);
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

  @override
  Future<void> addId(String id) async {
    _ids.add(id);
    saveCount++;
  }

  @override
  Future<void> removeId(String id) async {
    _ids.remove(id);
    saveCount++;
  }
}