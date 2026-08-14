import 'package:firebase_auth/firebase_auth.dart';

/// Returns the signed-in tourist's uid, or null when signed out.
///
/// A function rather than a [FirebaseAuth] instance, because the Firestore
/// stores need exactly one string from auth. Depending on the whole SDK would
/// force every test to stand up a fake FirebaseAuth just to exercise logic
/// that has nothing to do with authentication — and `fake_cloud_firestore`,
/// which the suite already uses, has no auth counterpart in this project.
typedef CurrentUid = String? Function();

/// The production implementation, used as the default by the Firestore stores.
String? firebaseCurrentUid() => FirebaseAuth.instance.currentUser?.uid;
