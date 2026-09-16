import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

/// The routed-place ids, kept against the tourist's account rather than the
/// phone — see [FirestoreFavoritesStore], which this mirrors exactly and whose
/// doc comment explains the single-document shape and why no rules change was
/// needed.
///
/// Grey pins are a smaller thing to get wrong than favourites, but they get it
/// wrong the same way: device-wide storage showed one account the places
/// another account had walked to.
class FirestoreRoutedPlacesStore implements RoutedPlacesStore {
  FirestoreRoutedPlacesStore({
    FirebaseFirestore? firestore,
    String Function()? currentUserId,
    RoutedPlacesStore? legacyStore,
  })  : _injectedFirestore = firestore,
        _injectedUserId = currentUserId,
        _legacy = legacyStore ?? const SharedPrefsRoutedPlacesStore();

  final FirebaseFirestore? _injectedFirestore;
  final String Function()? _injectedUserId;

  /// Resolved on first use, not at construction. MapController and
  /// FavoritesController build their default store eagerly, including in
  /// widget tests that only ever pump a screen — and FirebaseFirestore.instance
  /// throws without a Firebase app.
  late final FirebaseFirestore _firestore =
      _injectedFirestore ?? FirebaseFirestore.instance;
  late final String Function() _currentUserId = _injectedUserId ??
      (() => FirebaseAuth.instance.currentUser?.uid ?? '');
  final RoutedPlacesStore _legacy;

  static const String _collection = 'app_data';
  static const String _document = 'routed_places';
  static const String _field = 'placeIds';

  DocumentReference<Map<String, dynamic>>? _docFor(String uid) {
    if (uid.isEmpty) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection(_collection)
        .doc(_document);
  }

  @override
  Future<List<String>> load() async {
    try {
      final doc = _docFor(_currentUserId());
      if (doc == null) return const <String>[];

      final snapshot = await doc.get();
      if (!snapshot.exists) return _adoptLegacy(doc);

      final raw = snapshot.data()?[_field];
      if (raw is! List) return const <String>[];
      return raw
          .whereType<String>()
          .where((String id) => id.isNotEmpty)
          .toList();
    } catch (_) {
      // A pin that fails to grey is a cosmetic loss; throwing here would take
      // the map down with it.
      return const <String>[];
    }
  }

  /// Carries the pre-account ids up to whichever tourist signs in first, then
  /// clears the device copy so the next account starts clean.
  Future<List<String>> _adoptLegacy(
    DocumentReference<Map<String, dynamic>> doc,
  ) async {
    final List<String> saved;
    try {
      saved = await _legacy.load();
    } catch (_) {
      return const <String>[];
    }
    if (saved.isEmpty) return const <String>[];

    await doc.set(<String, dynamic>{_field: saved});
    await _legacy.save(const <String>[]);
    return saved;
  }

  @override
  Future<void> save(List<String> placeIds) async {
    try {
      final doc = _docFor(_currentUserId());
      if (doc == null) return;
      await doc.set(<String, dynamic>{_field: placeIds});
    } catch (_) {
      // Best-effort, as it always has been: the pin is already grey on screen,
      // and the next completed journey rewrites the whole list.
    }
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
