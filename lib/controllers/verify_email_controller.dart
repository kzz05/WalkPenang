import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

/// Controller for the email-verification screen.
///
/// Sends the verification link, runs the 60-second resend cooldown, and polls
/// Firebase every 3 seconds to notice when the user clicks the link.
class VerifyEmailController extends ChangeNotifier {
  final AuthService _auth = AuthService();

  Timer? _pollTimer;
  Timer? _cooldownTimer;

  bool _isEmailVerified = false;
  bool _canResendEmail = true;
  int _resendCooldown = 60;
  bool _disposed = false;

  /// Set by the view so it can navigate the moment verification lands.
  VoidCallback? onVerified;

  bool get isEmailVerified => _isEmailVerified;
  bool get canResendEmail => _canResendEmail;
  int get resendCooldown => _resendCooldown;
  String get userEmail => _auth.currentUser?.email ?? 'your email';

  /// Kicks off the screen: sends the link and starts polling.
  /// Returns an error message if the send failed, otherwise null.
  Future<String?> start() async {
    _isEmailVerified = _auth.currentUser?.emailVerified ?? false;
    if (_isEmailVerified) return null;

    final error = await sendVerificationEmail();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkEmailVerified(),
    );
    return error;
  }

  /// Returns an error message on failure, otherwise null.
  Future<String?> sendVerificationEmail() async {
    try {
      await _auth.sendVerificationEmail();

      _canResendEmail = false;
      _resendCooldown = 60;
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_resendCooldown == 0) {
          _canResendEmail = true;
          timer.cancel();
        } else {
          _resendCooldown--;
        }
        _safeNotify();
      });

      _safeNotify();
      return null;
    } catch (e) {
      return 'Error sending link: $e';
    }
  }

  Future<void> _checkEmailVerified() async {
    try {
      await _auth.currentUser?.reload();
    } catch (_) {
      // Transient error — let the next 3s tick retry instead of killing the loop.
      return;
    }
    if (_disposed) return;

    _isEmailVerified = _auth.currentUser?.emailVerified ?? false;
    _safeNotify();

    if (_isEmailVerified) {
      _pollTimer?.cancel();
      onVerified?.call();
    }
  }

  /// Abandons verification and ends the session.
  Future<void> cancel() async {
    _pollTimer?.cancel();
    await _auth.signOut();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
