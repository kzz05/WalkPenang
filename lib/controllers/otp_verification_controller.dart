import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/otp_service.dart';
import '../services/profile_store.dart';

/// Where the view should go once verification finishes.
enum OtpNext {
  /// Stay put — something failed, or we're still waiting on the user.
  stay,

  /// Verified, and a complete profile is already on file.
  home,

  /// Verified, but the profile still needs filling in.
  completeProfile,
}

/// Result of a verification attempt.
class OtpOutcome {
  final OtpNext next;
  final UserProfile? profile;
  final String? error;

  const OtpOutcome(this.next, {this.profile, this.error});
}

/// Controller for the 6-digit email OTP screen.
///
/// Replaces the old email-link flow. The code is generated, mailed and checked
/// by Cloud Functions (`functions/index.js`); this class owns the screen state
/// — the resend cooldown, the busy flag, and the error line under the boxes.
class OtpVerificationController extends ChangeNotifier {
  OtpVerificationController({
    OtpService? service,
    ProfileStore? store,
    AuthService? auth,
  })  : _service = service ?? OtpService(),
        _store = store ?? ProfileStore(),
        _auth = auth ?? AuthService();

  final OtpService _service;
  final ProfileStore _store;
  final AuthService _auth;

  final formKey = GlobalKey<FormState>();
  final otpCtrl = TextEditingController();

  static const _resendSeconds = 30;

  Timer? _timer;
  int _secondsRemaining = _resendSeconds;
  bool _canResend = false;
  bool _busy = false;
  bool _sending = false;
  String? _errorMessage;
  bool _disposed = false;

  int get secondsRemaining => _secondsRemaining;
  bool get canResend => _canResend && !_sending;
  bool get busy => _busy;
  bool get sending => _sending;
  String? get errorMessage => _errorMessage;
  String get email => _service.currentEmail;

  String? validateOtp(String? v) =>
      (v == null || v.trim().length != 6) ? 'Enter all 6 digits' : null;

  /// Sends the first code when the screen opens.
  ///
  /// Returns an error message on failure, or null if the mail went out.
  Future<String?> start() => _send();

  /// User tapped "resend". Returns an error message, or null on success.
  Future<String?> resendCode() async {
    if (!canResend) return null;
    return _send();
  }

  Future<String?> _send() async {
    _sending = true;
    _errorMessage = null;
    _safeNotify();

    try {
      await _service.sendCode();
      _startResendTimer();
      return null;
    } on OtpException catch (e) {
      // A cooldown rejection still means a code is live, so keep the timer
      // running rather than letting the user hammer the button.
      if (e.isCooldown) _startResendTimer();
      return e.message;
    } finally {
      _sending = false;
      _safeNotify();
    }
  }

  void _startResendTimer() {
    _secondsRemaining = _resendSeconds;
    _canResend = false;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        _secondsRemaining--;
      } else {
        _canResend = true;
        timer.cancel();
      }
      _safeNotify();
    });

    _safeNotify();
  }

  /// Checks the typed code against the server.
  Future<OtpOutcome> verifyOtp() async {
    _errorMessage = null;
    if (!(formKey.currentState?.validate() ?? false)) {
      return const OtpOutcome(OtpNext.stay);
    }

    _setBusy(true);
    try {
      await _service.verifyCode(otpCtrl.text.trim());

      // Verified — decide which screen the user belongs on, the same way
      // LoadingController does after a successful sign-in.
      final profile = await _store.load();
      if (profile != null && profile.isComplete) {
        return OtpOutcome(OtpNext.home, profile: profile);
      }
      return const OtpOutcome(OtpNext.completeProfile);
    } on OtpException catch (e) {
      _errorMessage = e.message;
      // Clear the boxes so the next attempt starts from an empty field.
      otpCtrl.clear();
      _safeNotify();
      return OtpOutcome(OtpNext.stay, error: e.message);
    } finally {
      _setBusy(false);
    }
  }

  /// Abandons verification and ends the session, so the app doesn't bounce
  /// the user straight back here on the next launch.
  Future<void> cancel() async {
    _timer?.cancel();
    await _auth.signOut();
  }

  void _setBusy(bool value) {
    _busy = value;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    otpCtrl.dispose();
    super.dispose();
  }
}
