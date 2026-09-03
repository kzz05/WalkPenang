import 'package:shared_preferences/shared_preferences.dart';

/// UC-M04 — remembers which places the tourist has already got a route to, so
/// their pin and card stay grey across app restarts.
///
/// Ids only, unlike [FavoritesStore]: nothing renders from this list on its
/// own. It is read as a lookup against places the Places API has already
/// returned, so an id that no longer resolves simply never matches and costs
/// nothing.
abstract class RoutedPlacesStore {
  /// Oldest first — the order [MapController] trims from when the list hits
  /// its cap.
  Future<List<String>> load();

  Future<void> save(List<String> placeIds);
}

class SharedPrefsRoutedPlacesStore implements RoutedPlacesStore {
  const SharedPrefsRoutedPlacesStore();

  static const String _key = 'walkpenang.map.routed_place_ids.v1';

  @override
  Future<List<String>> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[])
        .where((String id) => id.isNotEmpty)
        .toList();
  }

  @override
  Future<void> save(List<String> placeIds) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, placeIds);
  }
}

/// In-memory implementation for tests, so the suite never touches disk.
class InMemoryRoutedPlacesStore implements RoutedPlacesStore {
  InMemoryRoutedPlacesStore([List<String>? initial])
      : _placeIds = <String>[...?initial];

  List<String> _placeIds;

  /// Lets tests assert on what was actually written.
  List<String> get placeIds => List<String>.unmodifiable(_placeIds);

  int saveCount = 0;

  @override
  Future<List<String>> load() async => List<String>.of(_placeIds);

  @override
  Future<void> save(List<String> placeIds) async {
    _placeIds = List<String>.of(placeIds);
    saveCount++;
  }
}
