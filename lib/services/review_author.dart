import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import 'profile_store.dart';

/// Who is writing a review: the owner stamped on the document, and the name
/// shown above it in the reviews list.
///
/// These are deliberately separate. [uid] is identity — it decides whose
/// review this is, and the Firestore rule checks it. [displayName] is only a
/// label; a tourist may rename themselves and their old reviews keep the name
/// they were written under, which is how review sites normally behave.
class ReviewAuthor {
  const ReviewAuthor({required this.uid, required this.displayName});

  final String uid;
  final String displayName;

  /// Nobody is signed in. Callers refuse to write a review under this, the
  /// same '' convention every account-scoped store in this app uses
  /// (see FirestoreFavoritesStore._docFor).
  static const ReviewAuthor signedOut =
      ReviewAuthor(uid: '', displayName: 'Anonymous');

  bool get isSignedIn => uid.isNotEmpty;
}

/// Resolves the current tourist for review attribution.
///
/// The name comes from the profile nickname the tourist chose at onboarding,
/// which is the name they already see on their own profile screen. Two
/// fallbacks behind it, because neither is guaranteed: a Google sign-in can
/// land in the app before the profile document is written, and an
/// email/password account has no displayName at all.
class ReviewAuthorResolver {
  ReviewAuthorResolver({FirebaseAuth? auth, ProfileStore? profileStore})
      : _injectedAuth = auth,
        _profileStore = profileStore ?? ProfileStore();

  final FirebaseAuth? _injectedAuth;
  final ProfileStore _profileStore;

  // Resolved on first use, not at construction, so a widget test can build the
  // repository that owns this without a Firebase app existing — the same
  // late-final trick ProfileStore uses for FirebaseStorage.
  late final FirebaseAuth _auth = _injectedAuth ?? FirebaseAuth.instance;

  /// The uid alone, with no profile round trip. Read paths use this to notice
  /// an account switch cheaply; only a write needs the display name.
  String get currentUid => _auth.currentUser?.uid ?? '';

  Future<ReviewAuthor> resolve() async {
    final User? user = _auth.currentUser;
    if (user == null) return ReviewAuthor.signedOut;

    // A failed profile read must not cost the tourist their review — fall
    // through to the email prefix rather than throwing out of submitReview.
    UserProfile? profile;
    try {
      profile = await _profileStore.load();
    } catch (_) {
      profile = null;
    }

    return ReviewAuthor(
      uid: user.uid,
      displayName: resolveDisplayName(
        nickname: profile?.nickname,
        email: profile?.email ?? user.email,
        authDisplayName: user.displayName,
      ),
    );
  }

  /// Nickname → the part of the email before the @ → Google's display name →
  /// 'Anonymous'. Pure and static so the precedence is unit-testable without a
  /// Firebase app.
  static String resolveDisplayName({
    String? nickname,
    String? email,
    String? authDisplayName,
  }) {
    final String fromNickname = nickname?.trim() ?? '';
    if (fromNickname.isNotEmpty) return fromNickname;

    final String fromEmail = (email ?? '').trim();
    final int at = fromEmail.indexOf('@');
    if (at > 0) return fromEmail.substring(0, at);

    final String fromAuth = authDisplayName?.trim() ?? '';
    if (fromAuth.isNotEmpty) return fromAuth;

    return 'Anonymous';
  }
}
