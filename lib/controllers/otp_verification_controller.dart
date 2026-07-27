import 'dart:async';

import 'package:flutter/material.dart';

/// Controller for the 6-digit OTP screen.
///
/// ⚠️ Placeholder: the live app verifies email addresses through Firebase
/// email links ([VerifyEmailController]), so nothing navigates here yet and
/// [verifyOtp] accepts any well-formed code. Wire it to a real backend check
/// before using this screen for anything.
class OtpVerificationController extends ChangeNotifier {
  final formKey = GlobalKey<FormState>();
  final otpCtrl = TextEditingController();

  Timer? _timer;
  int _secondsRemaining = 30;
  bool _canResend = false;
  bool _busy = false;
  String? _errorMessage;
  bool _disposed = false;

  int get secondsRemaining => _secondsRemaining;
  bool get canResend => _canResend;
  bool get busy => _busy;
  String? get errorMessage => _errorMessage;

  String? validateOtp(String? v) =>
      (v == null || v.trim().length != 6) ? 'Enter all 6 digits' : null;

  void startResendTimer() {
    _secondsRemaining = 30;
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

  /// Returns true when the code is accepted; check [errorMessage] otherwise.
  Future<bool> verifyOtp() async {
    _errorMessage = null;
    if (!formKey.currentState!.validate()) return false;

    _setBusy(true);
    try {
      final code = otpCtrl.text.trim();
      // TODO: replace with a real backend verification call.
      debugPrint('Verifying secure system code: $code');
      return true;
    } catch (e) {
      _errorMessage = 'Invalid code: $e';
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// Returns true if a fresh code was "sent" (i.e. the cooldown had elapsed).
  bool resendCode() {
    if (!_canResend) return false;
    startResendTimer();
    return true;
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
