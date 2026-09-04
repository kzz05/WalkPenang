import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:walkpenang/models/favorite_place.dart';

/// T-FD04.1 — persists the saved-places list across app restarts.
///
/// Stores a full [FavoritePlace] snapshot per favourite, not just an id: the
/// list has to render immediately on launch with no place feed loaded, and the
/// same favourite can be saved from the map (where only [PlaceModel] exists) or
/// the grid (where only [Place] exists).
abstract class FavoritesStore {
  Future<List<FavoritePlace>> load();

  Future<void> save(List<FavoritePlace> places);
}

class SharedPrefsFavoritesStore implements FavoritesStore {
  const SharedPrefsFavoritesStore();

  /// v2: a JSON array of [FavoritePlace] objects. The v1 key
  /// ('discovery.favorite_place_ids', a bare id list) is intentionally not
  /// read or migrated — those ids were saved against an older place-id scheme
  /// and could no longer be resolved anyway.
  static const String _key = 'walkpenang.favorites.v2';

  @override
  Future<List<FavoritePlace>> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const <FavoritePlace>[];

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return const <FavoritePlace>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(FavoritePlace.fromJson)
          .where((FavoritePlace f) => f.id.isNotEmpty)
          .toList();
    } catch (_) {
      // A corrupt payload shouldn't wedge the app on every launch.
      return const <FavoritePlace>[];
    }
  }

  @override
  Future<void> save(List<FavoritePlace> places) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(places.map((FavoritePlace p) => p.toJson()).toList()),
    );
  }
}

/// In-memory implementation for tests, so the suite never touches disk.
class InMemoryFavoritesStore implements FavoritesStore {
  InMemoryFavoritesStore([List<FavoritePlace>? initial])
      : _places = <FavoritePlace>[...?initial];

  List<FavoritePlace> _places;

  /// Lets tests assert on what was actually written.
  List<FavoritePlace> get places => List<FavoritePlace>.unmodifiable(_places);

  int saveCount = 0;

  @override
  Future<List<FavoritePlace>> load() async => List<FavoritePlace>.of(_places);

  @override
  Future<void> save(List<FavoritePlace> places) async {
    _places = List<FavoritePlace>.of(places);
    saveCount++;
  }
}
