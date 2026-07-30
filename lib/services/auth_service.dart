import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isInitialized = false;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      // 🛠️ FIX: google_sign_in v7 requires initialize() to be told which
      // OAuth client to use on platforms that don't auto-detect it from
      // native config files (notably iOS/macOS, and web). Previously this
      // was called with no arguments, which can leave sign-in silently
      // misconfigured on those platforms.
      //
      // The iOS client ID below is the same one already present in
      // firebase_options.dart (DefaultFirebaseOptions.ios.iosClientId).
      // Android picks up its config automatically from google-services.json,
      // so no clientId is needed there.
      //
      // ⚠️ If you ship this app on Web, you'll also need to pass a web
      // OAuth client ID here (create one in Google Cloud Console / the
      // Firebase console's Auth > Sign-in method > Google settings) — it's
      // not present in firebase_options.dart today.
      const iosClientId =
          '997752335330-cn23bbhc9qj1p77fd61ujnp0g8q0ahv3.apps.googleusercontent.com';

      await _googleSignIn.initialize(
        clientId: (!kIsWeb && Platform.isIOS) ? iosClientId : null,
      );
      _isInitialized = true;
    }
  }

  Future<User?> signInOrRegisterWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        final credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return credential.user;
      }
      rethrow;
    }
  }

  Future<User?> signInWithGoogle() async {
    await _ensureInitialized();

    final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user;
  }

  // 📧 Email verification is no longer done with Firebase's built-in link.
  // A 6-digit code is issued and checked by the `sendEmailOtp` /
  // `verifyEmailOtp` Cloud Functions — see OtpService and functions/index.js.

  Future<void> signOut() async {
    await _ensureInitialized();
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}