import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

/// A profile photo that Cloud Vision refused.
///
/// Carries the reason so the UI can say which kind of content tripped it,
/// rather than a generic failure the tourist cannot act on.
class ProfileImageRejected implements Exception {
  const ProfileImageRejected(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileStore {
  static const _key = 'user_profile';
  final FirebaseFirestore _firestore;

  // Resolved on first use rather than at construction, so a test can build the
  // store with an injected Firestore without a Firebase app existing.
  late final FirebaseStorage _storage = FirebaseStorage.instance;
  late final FirebaseAuth _auth = FirebaseAuth.instance;
  late final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// [firestore] is injectable for tests, the same way FirestoreRewardDao
  /// takes one. Left null, it resolves to the live instance as before.
  ProfileStore({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Uploads an avatar and returns its public URL once it has passed
  /// moderation.
  ///
  /// Two steps, and the order is the whole point. The file goes to
  /// `pending_profile_images/`, which storage.rules makes write-only — nobody,
  /// not even the uploader, can read it. `moderateProfileImage` then screens it
  /// with Cloud Vision SafeSearch and, only if it is clean, copies it to
  /// `profile_images/` and hands back the URL.
  ///
  /// It cannot be done the other way round. photoUrl is mirrored into
  /// `leaderboard/{uid}`, which every signed-in tourist can read, and
  /// cached_network_image keys its disk cache on the URL — so a photo that went
  /// public first and was withdrawn afterwards would keep rendering on other
  /// people's devices. Screening before the file is reachable is the only
  /// version of this that works.
  ///
  /// Throws [ProfileImageRejected] when the photo is refused, so the caller can
  /// tell the user why instead of silently keeping the old picture.
  Future<String?> uploadProfileImage(File imageFile, String uid) async {
    final ref =
        _storage.ref().child('pending_profile_images').child('$uid.jpg');

    try {
      await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }

    try {
      final result = await _functions
          .httpsCallable('moderateProfileImage')
          .call<Map<String, dynamic>>();
      return result.data['photoUrl'] as String?;
    } on FirebaseFunctionsException catch (e) {
      // The function deletes the quarantined file on every rejection path, so
      // there is nothing left to clean up here.
      throw ProfileImageRejected(
        e.message ?? 'That photo could not be used. Please choose another.',
      );
    } catch (_) {
      // Network or plugin failure rather than a rejection. Null tells the
      // caller to show its generic "could not upload" message; the function's
      // own logger.error has the server-side detail.
      return null;
    }
  }

  // Fetch data: Checks cloud DB first if online, falls back to local storage
  Future<UserProfile?> load() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      try {
        final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
        if (doc.exists && doc.data() != null) {
          final cloudProfile = UserProfile.fromMap(doc.data()!);
          await saveLocal(cloudProfile);
          return cloudProfile;
        }
      } catch (e) {
        print("Cloud fetch failed: $e");
      }
    }
    return await loadLocal();
  }

  Future<void> save(UserProfile profile) async {
    await saveLocal(profile);
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      await saveToCloud(firebaseUser.uid, profile);
    }
  }

  /// Writes the profile fields into users/{uid}, leaving every other field of
  /// that document alone.
  ///
  /// Merging rather than replacing: the reward module keeps the tourist's
  /// cumulative totals (points, check-ins, distance, carbon, calories) in this
  /// same document and UserProfile carries none of them, so a bare set() wiped
  /// them -- zeroing the statistics dashboard and the tourist's leaderboard row
  /// every time a profile was edited.
  Future<void> saveToCloud(String uid, UserProfile profile) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  Future<UserProfile?> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return UserProfile.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLocal(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toMap()));
  }

  /// Drops the cached profile on logout.
  ///
  /// Removes this store's own key and nothing else. It used to call
  /// prefs.clear(), which empties the whole preference store — so logging out
  /// also deleted the tourist's favourites
  /// (walkpenang.favorites.v2) and the "already routed" places behind the grey
  /// map pins (walkpenang.map.routed_place_ids.v1). Both came back empty on the
  /// next login, which reads as the app having forgotten a year of walking.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}