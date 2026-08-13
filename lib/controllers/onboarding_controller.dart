import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/password_strength.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
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
  OnboardingController({User? existingUser}) {
    weightCtrl.addListener(_recalculateBmi);
    heightCtrl.addListener(_recalculateBmi);
    passwordCtrl.addListener(_recalculatePasswordStrength);

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

  String? validateNickname(String? v) => Validators.nickname(v);

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
      imageQuality: 70,
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
      var photoUrl = user.photoURL;
      if (_selectedImage != null) {
        final uploaded = await _store.uploadProfileImage(
          _selectedImage!,
          user.uid,
        );
        if (uploaded != null) photoUrl = uploaded;
      }

      final profile = UserProfile(
        nickname: nicknameCtrl.text.trim(),
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
    emailCtrl.dispose();
    passwordCtrl.dispose();
    nicknameCtrl.dispose();
    phoneCtrl.dispose();
    weightCtrl.dispose();
    heightCtrl.dispose();
    super.dispose();
  }
}
