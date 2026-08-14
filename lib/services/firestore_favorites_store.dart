import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:walkpenang/services/current_uid.dart';
import 'package:walkpenang/services/favorites_store.dart';

/// [FavoritesStore] backed by Firestore, so saved places follow the tourist
/// between devices instead of living only in that install's SharedPreferences.
///
/// Stores place ids and nothing else, which is what [FavoritesStore] has
/// always done — and, separately, what Google Maps Platform Terms 3.2.3(b)
/// requires: a place id may be kept indefinitely, its content may not.
/// A favourite is re-hydrated by looking the id up in whatever the catalogue
/// last returned.
///
/// One document per favourite, not a single array field, so two devices saving
/// different places at the same time can't overwrite each other — an array
/// write is last-writer-wins on the whole list.
///
/// ```
/// users/{uid}/favorites/{placeId}   savedAt
/// ```
class FirestoreFavoritesStore implements FavoritesStore {
  FirestoreFavoritesStore({
    FirebaseFirestore? firestore,
    CurrentUid? currentUid,
    this.fallback = const SharedPrefsFavoritesStore(),
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _currentUid = currentUid ?? firebaseCurrentUid;

  final FirebaseFirestore _db;
  final CurrentUid _currentUid;

  /// Used when nobody is signed in. Favourites are a low-stakes convenience,
  /// so a signed-out tourist still gets them locally rather than an error —
  /// and [migrateLocalFavorites] lifts them into the cloud on sign-in.
  final FavoritesStore fallback;

  CollectionReference<Map<String, dynamic>>? get _collection {
    final uid = _currentUid();
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('favorites');
  }

  @override
  Future<Set<String>> loadIds() async {
    final collection = _collection;
    if (collection == null) return fallback.loadIds();
    try {
      final snapshot = await collection.get();
      return snapshot.docs.map((doc) => doc.id).toSet();
    } on Exception {
      // Offline: the last known local set beats an empty favourites screen.
      return fallback.loadIds();
    }
  }

  /// Saves one place. One document write, and it cannot affect any other id —
  /// which is what makes it safe for the map and the Discovery feed to write
  /// from their own independently-loaded snapshots.
  @override
  Future<void> addId(String id) async {
    final collection = _collection;
    if (collection == null) return fallback.addId(id);
    try {
      await collection.doc(id).set(<String, dynamic>{
        'savedAt': FieldValue.serverTimestamp(),
      });
      await fallback.addId(id);
    } on Exception {
      await fallback.addId(id);
    }
  }

  @override
  Future<void> removeId(String id) async {
    final collection = _collection;
    if (collection == null) return fallback.removeId(id);
    try {
      await collection.doc(id).delete();
      await fallback.removeId(id);
    } on Exception {
      await fallback.removeId(id);
    }
  }

  /// Bulk replace. See [FavoritesStore.saveIds] — this deletes anything absent
  /// from [ids], so callers holding a partial view must use [addId] /
  /// [removeId] instead. Kept for `clear()` and [migrateLocalFavorites],
  /// which do own the whole set.
  @override
  Future<void> saveIds(Set<String> ids) async {
    final collection = _collection;
    if (collection == null) return fallback.saveIds(ids);

    try {
      final snapshot = await collection.get();
      final existing = snapshot.docs.map((doc) => doc.id).toSet();

      final added = ids.difference(existing);
      final removed = existing.difference(ids);
      if (added.isEmpty && removed.isEmpty) return;

      final batch = _db.batch();
      for (final id in added) {
        batch.set(collection.doc(id), <String, dynamic>{
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
      for (final id in removed) {
        batch.delete(collection.doc(id));
      }
      await batch.commit();

      // Keep the local copy warm so an offline launch still shows favourites.
      await fallback.saveIds(ids);
    } on Exception {
      await fallback.saveIds(ids);
    }
  }

  /// Call once after sign-in: folds anything saved while signed out into the
  /// tourist's cloud set. A union, not a replace — signing in should never
  /// silently drop favourites saved on either side.
  Future<void> migrateLocalFavorites() async {
    final collection = _collection;
    if (collection == null) return;
    final local = await fallback.loadIds();
    if (local.isEmpty) return;
    final remote = await loadIds();
    await saveIds(remote.union(local));
  }
}
