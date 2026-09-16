import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/validation_messages.dart';
import '../models/password_strength.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/nickname_service.dart';
import '../services/profile_store.dart';
import '../utils/validators.dart';

/// What the view should do once an onboarding step finishes.
enum OnboardingNext {
  /// Stay put — either something failed, or the metrics form is now showing.
  stay,

  /// Email/password account that still needs its address verified.
  verifyEmail,

  /// Fully set up — go to the home screen.
  home,
}

/// Result of an onboarding step: where to go, the profile to carry along,
/// and any message the view should surface in a snackbar.
class OnboardingOutcome {
  final OnboardingNext next;
  final UserProfile? profile;
  final String? error;

  const OnboardingOutcome(this.next, {this.profile, this.error});
}

/// Controller for the onboarding screen.
///
/// Owns both phases of onboarding: the auth phase (email/password + Google)
/// and the metrics phase (nickname, contact, height/weight, avatar upload).
/// The view reads state through the getters below and calls these methods —
/// it never touches Firebase, ImagePicker, or the profile store directly.
class OnboardingController extends ChangeNotifier {
  /// [nicknames] is injectable so a test can drive the "name taken" path
  /// without a Firebase app.
  OnboardingController({User? existingUser, NicknameService? nicknames})
      : _nicknames = nicknames ?? NicknameService() {
    weightCtrl.addListener(_recalculateBmi);
    heightCtrl.addListener(_recalculateBmi);
    passwordCtrl.addListener(_recalculatePasswordStrength);
    nicknameCtrl.addListener(_onNicknameChanged);

    if (existingUser != null) {
      _authenticatedUser = existingUser;
      if (existingUser.displayName != null) {
        nicknameCtrl.text = existingUser.displayName!;
      }
      if (existingUser.email != null) {
        emailCtrl.text = existingUser.email!;
      }
    }
  }

  final AuthService _auth = AuthService();
  final ProfileStore _store = ProfileStore();
  final NicknameService _nicknames;

  final authFormKey = GlobalKey<FormState>();
  final profileFormKey = GlobalKey<FormState>();

  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final nicknameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final heightCtrl = TextEditingController();

  User? _authenticatedUser;
  File? _selectedImage;
  String _units = 'metric';
  bool _busy = false;
  bool _obscurePassword = true;
  double _bmi = 0.0;
  String _bmiCategory = '';
  PasswordStrength _passwordStrength = PasswordStrength.of('');
  bool _disposed = false;

  /// True once the user is signed in — the view swaps to the metrics form.
  bool get isAuthenticated => _authenticatedUser != null;
  File? get selectedImage => _selectedImage;
  String get units => _units;
  bool get busy => _busy;
  bool get obscurePassword => _obscurePassword;
  double get bmi => _bmi;
  String get bmiCategory => _bmiCategory;

  /// Live grading of whatever is currently in the password field, driving the
  /// strength meter under it.
  PasswordStrength get passwordStrength => _passwordStrength;

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    _safeNotify();
  }

  void setUnits(String? value) {
    _units = value ?? 'metric';
    _safeNotify();
  }

  // ── Validation rules ──────────────────────────────────────────────────────
  // Thin delegates to Validators so the view never imports it directly and
  // the same rules apply on the edit-profile screen.

  String? validateEmail(String? v) => Validators.email(v);

  String? validatePassword(String? v) => Validators.password(v);

  String? validateNickname(String? v) =>
      Validators.nickname(v) ?? _takenNameError(v);

  /// Nothing is held yet during registration, so every candidate is worth
  /// checking.
  String get _ownCurrentNickname => '';

  // ── Live "is this name free?" check ───────────────────────────────────────
  //
  // TextFormField.validator is synchronous, so uniqueness cannot be answered
  // from inside it. Instead the answer lands here and notifyListeners() drives
  // a rebuild; the field re-validates because the form uses
  // AutovalidateMode.onUserInteraction and picks the error up.
  //
  // Deliberately NOT Form.validate() — that marks every field touched, which
  // would splash "Weight is required" across untouched fields the moment
  // somebody types a name that is taken.

  Timer? _nicknameDebounce;

  /// The exact string the server reported as taken, or null.
  ///
  /// Compared against the field's current text so the error disappears the
  /// moment the user starts changing it, rather than lingering until the next
  /// round trip returns.
  String? _takenName;

  static const Duration _nicknameCheckDelay = Duration(milliseconds: 400);

  void _onNicknameChanged() {
    _nicknameDebounce?.cancel();

    // Any edit invalidates a previous verdict.
    if (_takenName != null) {
      _takenName = null;
      _safeNotify();
    }

    _nicknameDebounce = Timer(_nicknameCheckDelay, _checkNicknameAvailable);
  }

  Future<void> _checkNicknameAvailable() async {
    final candidate = nicknameCtrl.text.trim();

    // No point spending a call on a name the synchronous rules already reject,
    // or on the name this tourist already holds.
    if (Validators.nickname(candidate) != null) return;
    if (candidate == _ownCurrentNickname) return;

    final available = await _nicknames.isAvailable(candidate);

    // The reply may be for a prefix the user has since typed past. Without this
    // a slow answer about "Ian" could flag a field that now reads "IanWong".
    if (_disposed || nicknameCtrl.text.trim() != candidate) return;

    if (!available) {
      _takenName = candidate;
      _safeNotify();
    }
  }

  /// Applied after the synchronous rules, so a too-short or profane name still
  /// reports its own problem first — that is the one the user can act on.
  String? _takenNameError(String? v) {
    final input = v?.trim() ?? '';
    if (_takenName != null && input == _takenName) {
      return ValidationMessages.nicknameTaken;
    }
    return null;
  }


  String? validatePhone(String? v) => Validators.phone(v);

  String? validateHeight(String? v) => Validators.heightCm(v);

  String? validateWeight(String? v) => Validators.weightKg(v);

  // ── Live password strength ────────────────────────────────────────────────

  void _recalculatePasswordStrength() {
    final next = PasswordStrength.of(passwordCtrl.text);
    // Most keystrokes leave the meter looking identical — don't rebuild the
    // whole form for those.
    if (_looksTheSame(next, _passwordStrength)) return;
    _passwordStrength = next;
    _safeNotify();
  }

  static bool _looksTheSame(PasswordStrength a, PasswordStrength b) {
    if (a.level != b.level) return false;
    for (var i = 0; i < a.requirements.length; i++) {
      if (a.requirements[i].met != b.requirements[i].met) return false;
    }
    return true;
  }

  // ── Live BMI preview ──────────────────────────────────────────────────────

  void _recalculateBmi() {
    final w = double.tryParse(weightCtrl.text.trim());
    final h = double.tryParse(heightCtrl.text.trim());
    if (w == null || h == null || h <= 0) return;

    // Reuse the Model's own BMI rules instead of duplicating the thresholds.
    final draft = UserProfile(
      nickname: '',
      weightKg: w,
      heightCm: h,
      units: _units,
    );
    _bmi = draft.bmi;
    _bmiCategory = draft.bmiCategory;
    _safeNotify();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // The dimension caps matter as much as the quality: without them a 12MP
      // phone photo still arrives at 2-3MB, which storage.rules would reject
      // and Cloud Vision would be billed to read.
      imageQuality: 70,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;
    _selectedImage = File(picked.path);
    _safeNotify();
  }

  Future<OnboardingOutcome> signInOrRegister() async {
    if (!authFormKey.currentState!.validate()) {
      return const OnboardingOutcome(OnboardingNext.stay);
    }

    _setBusy(true);
    try {
      final user = await _auth.signInOrRegisterWithEmail(
        emailCtrl.text.trim(),
        passwordCtrl.text.trim(),
      );
      if (user == null) return const OnboardingOutcome(OnboardingNext.stay);
      return await _resolveAfterAuth(user);
    } on FirebaseAuthException catch (e) {
      return OnboardingOutcome(
        OnboardingNext.stay,
        error: e.message ?? 'Authentication error occurred.',
      );
    } finally {
      _setBusy(false);
    }
  }

  Future<OnboardingOutcome> signInWithGoogle() async {
    _setBusy(true);
    try {
      final user = await _auth.signInWithGoogle();
      if (user == null) return const OnboardingOutcome(OnboardingNext.stay);
      return await _resolveAfterAuth(user);
    } catch (_) {
      return const OnboardingOutcome(
        OnboardingNext.stay,
        error: 'Google Sign-In failed.',
      );
    } finally {
      _setBusy(false);
    }
  }

  /// Decides what happens right after a successful sign-in.
  Future<OnboardingOutcome> _resolveAfterAuth(User user) async {
    if (!user.emailVerified &&
        user.providerData.any((p) => p.providerId == 'password')) {
      return const OnboardingOutcome(OnboardingNext.verifyEmail);
    }

    final existing = await _store.load();
    if (existing != null && existing.isComplete) {
      return OnboardingOutcome(OnboardingNext.home, profile: existing);
    }

    // No usable profile yet — stay here and switch to the metrics form.
    _authenticatedUser = user;
    if (user.displayName != null) {
      nicknameCtrl.text = user.displayName!;
    }
    _safeNotify();
    return const OnboardingOutcome(OnboardingNext.stay);
  }

  /// Uploads the chosen avatar (if any) and saves the finished profile.
  Future<OnboardingOutcome> completeProfile() async {
    if (_busy) return const OnboardingOutcome(OnboardingNext.stay);
    if (!profileFormKey.currentState!.validate()) {
      return const OnboardingOutcome(OnboardingNext.stay);
    }

    final user = _authenticatedUser;
    if (user == null) return const OnboardingOutcome(OnboardingNext.stay);

    _setBusy(true);
    try {
      // Claim the display name before anything is written. A refused name
      // must leave the account exactly as it was, not half-set-up.
      final nickname = nicknameCtrl.text.trim();
      try {
        await _nicknames.claim(nickname);
      } on NicknameException catch (e) {
        if (e.isTaken) {
          // Under the field rather than in a SnackBar — see the note in
          // EditProfileController.save().
          _takenName = nickname;
          _safeNotify();
          return const OnboardingOutcome(OnboardingNext.stay);
        }
        return OnboardingOutcome(OnboardingNext.stay, error: e.message);
      }

      var photoUrl = user.photoURL;
      if (_selectedImage != null) {
        // A refused photo stops setup rather than completing it with the
        // Google avatar silently left in place — see the same fix in
        // EditProfileController.save().
        try {
          final uploaded = await _store.uploadProfileImage(
            _selectedImage!,
            user.uid,
          );
          if (uploaded == null) {
            return const OnboardingOutcome(
              OnboardingNext.stay,
              error: 'Could not upload that photo. Please try again.',
            );
          }
          photoUrl = uploaded;
        } on ProfileImageRejected catch (e) {
          return OnboardingOutcome(OnboardingNext.stay, error: e.message);
        }
      }

      final profile = UserProfile(
        nickname: nickname,
        weightKg: double.tryParse(weightCtrl.text.trim()) ?? 0.0,
        heightCm: double.tryParse(heightCtrl.text.trim()) ?? 0.0,
        units: _units,
        email: user.email ?? emailCtrl.text.trim(),
        photoUrl: photoUrl,
        phoneNumber: phoneCtrl.text.trim(),
        points: 0,
      );

      await _store.save(profile);
      return OnboardingOutcome(OnboardingNext.home, profile: profile);
    } catch (e) {
      return OnboardingOutcome(
        OnboardingNext.stay,
        error: 'Failed to complete setup: $e',
      );
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    _busy = value;
    _safeNotify();
  }

  /// Async work can finish after the view is gone; notifying a disposed
  /// ChangeNotifier throws, so guard every notification.
  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    weightCtrl.removeListener(_recalculateBmi);
    heightCtrl.removeListener(_recalculateBmi);
    passwordCtrl.removeListener(_recalculatePasswordStrength);
    nicknameCtrl.removeListener(_onNicknameChanged);
    _nicknameDebounce?.cancel();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    nicknameCtrl.dispose();
    phoneCtrl.dispose();
    weightCtrl.dispose();
    heightCtrl.dispose();
    super.dispose();
  }
}
