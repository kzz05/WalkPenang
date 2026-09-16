import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

/// Saved places, kept against the tourist's account rather than the phone.
///
/// They used to live in SharedPreferences, which is device-wide: signing into a
/// second Google account on one phone showed the first account's favourites,
/// and signing out deleted everything. Everything else the tourist owns —
/// points, check-ins, badges, the journal — is already under users/{uid}, and
/// these belong there with it.
///
/// One document holding the whole list, not a document per place. It matches
/// this store's save-the-whole-list contract exactly, makes each save atomic,
/// and costs one read and one write instead of a batch plus deletes for
/// whatever was removed. A tourist's favourites are tens of entries against a
/// 1 MiB document limit.
///
/// No rules change was needed: firestore.rules already grants
/// users/{userId}/{document=**} to its owner. Reads come from Firestore's
/// local cache when there is no signal, which is on by default.
class FirestoreFavoritesStore implements FavoritesStore {
  FirestoreFavoritesStore({
    FirebaseFirestore? firestore,
    String Function()? currentUserId,
    FavoritesStore? legacyStore,
  })  : _injectedFirestore = firestore,
        _injectedUserId = currentUserId,
        _legacy = legacyStore ?? const SharedPrefsFavoritesStore();

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

  /// Where the device-wide favourites used to live. Read once, to carry them
  /// up to whichever account signs in first after the upgrade.
  final FavoritesStore _legacy;

  static const String _collection = 'app_data';
  static const String _document = 'favorites';
  static const String _field = 'places';

  DocumentReference<Map<String, dynamic>>? _docFor(String uid) {
    if (uid.isEmpty) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection(_collection)
        .doc(_document);
  }

  @override
  Future<List<FavoritePlace>> load() async {
    try {
      // Signed out: nothing to read, and nowhere to put a write. The app
      // cannot reach a screen that saves favourites without a session, so this
      // is a guard rather than a state to design for.
      final doc = _docFor(_currentUserId());
      if (doc == null) return const <FavoritePlace>[];

      final snapshot = await doc.get();
      if (!snapshot.exists) return _adoptLegacy(doc);

      final raw = snapshot.data()?[_field];
      if (raw is! List) return const <FavoritePlace>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(FavoritePlace.fromJson)
          .where((FavoritePlace f) => f.id.isNotEmpty)
          .toList();
    } catch (_) {
      // Same tolerance the SharedPreferences store has always had: a bad read
      // shows an empty list rather than wedging the app on every launch.
      return const <FavoritePlace>[];
    }
  }

  /// Moves the pre-account favourites up to this tourist, once.
  ///
  /// Only runs when the account has no document of its own yet. The local copy
  /// is deleted afterwards so the *next* account to sign in starts clean —
  /// which is the whole point of the move.
  Future<List<FavoritePlace>> _adoptLegacy(
    DocumentReference<Map<String, dynamic>> doc,
  ) async {
    final List<FavoritePlace> saved;
    try {
      saved = await _legacy.load();
    } catch (_) {
      return const <FavoritePlace>[];
    }
    if (saved.isEmpty) return const <FavoritePlace>[];

    await doc.set(<String, dynamic>{
      _field: saved.map((FavoritePlace p) => p.toJson()).toList(),
    });
    await _legacy.save(const <FavoritePlace>[]);
    return saved;
  }

  @override
  Future<void> save(List<FavoritePlace> places) async {
    try {
      final doc = _docFor(_currentUserId());
      if (doc == null) return;
      await doc.set(<String, dynamic>{
        _field: places.map((FavoritePlace p) => p.toJson()).toList(),
      });
    } catch (_) {
      // The heart is already filled in on screen and the next toggle rewrites
      // the whole list, so a failed write costs this one save rather than the
      // screen. Firestore queues writes offline, so a real failure here means
      // no session or a rule saying no.
    }
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
