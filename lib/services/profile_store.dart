import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class ProfileStore {
  static const _key = 'user_profile';
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  // Upload Profile Avatar File to Firebase Storage
  Future<String?> uploadProfileImage(File imageFile, String uid) async {
    try {
      final ref = _storage.ref().child('profile_images').child('$uid.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
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
      await _firestore.collection('users').doc(firebaseUser.uid).set(profile.toMap());
    }
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

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}