import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_store.dart';

/// Where the app should go once the auth + profile check finishes.
enum LoadingDestination {
  /// Nobody is signed in — show the login form.
  onboarding,

  /// Signed up with email/password but never clicked the verification link.
  verifyEmail,

  /// Signed in, but the profile is missing or incomplete.
  completeProfile,

  /// Signed in with a complete profile.
  home,
}

/// The decision made by [LoadingController], plus whatever the next screen needs.
class LoadingRoute {
  final LoadingDestination destination;
  final User? user;
  final UserProfile? profile;

  const LoadingRoute(this.destination, {this.user, this.profile});
}

/// Controller for the loading screen.
///
/// Decides where the user belongs on app start. It returns a [LoadingRoute]
/// rather than navigating itself, so the view stays the only layer that
/// touches [Navigator].
class LoadingController {
  final AuthService _auth = AuthService();
  final ProfileStore _store = ProfileStore();

  /// Keeps the loading animation on screen long enough to be seen.
  static const minimumDisplay = Duration(milliseconds: 1750);

  Future<LoadingRoute> resolveDestination() async {
    final user = _auth.currentUser;
    await Future.delayed(minimumDisplay);

    if (user == null) {
      return const LoadingRoute(LoadingDestination.onboarding);
    }

    // 🛡️ If they signed up with email/password but never verified it,
    // send them to verification instead of looping them back through
    // the login form.
    if (!user.emailVerified &&
        user.providerData.any((p) => p.providerId == 'password')) {
      return const LoadingRoute(LoadingDestination.verifyEmail);
    }

    final profile = await _store.load();
    if (profile != null && profile.isComplete) {
      return LoadingRoute(LoadingDestination.home, profile: profile);
    }

    // They're already signed in with Firebase, so don't send them back
    // through the login form — jump straight to "finish your profile".
    return LoadingRoute(LoadingDestination.completeProfile, user: user);
  }
}
