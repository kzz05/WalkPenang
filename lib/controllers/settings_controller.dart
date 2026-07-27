import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_store.dart';

/// Controller for the settings screen.
///
/// Exposes the profile being shown and performs the log-out sequence. The
/// confirmation dialog itself lives in the view, since it is pure UI.
class SettingsController {
  SettingsController({required this.profile});

  final UserProfile profile;

  final ProfileStore _store = ProfileStore();
  final AuthService _auth = AuthService();

  /// Clears the cached profile, then ends the Firebase/Google session.
  Future<void> logout() async {
    await _store.clear();
    await _auth.signOut();
  }
}
