import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/otp_verification_controller.dart';
import 'onboarding_view.dart';

/// ⚠️ Not wired into navigation — the app verifies email addresses through
/// Firebase email links (see VerifyEmailView). Kept for a future SMS/OTP flow.
class OtpVerificationView extends StatefulWidget {
  final String email;

  const OtpVerificationView({super.key, required this.email});

  @override
  State<OtpVerificationView> createState() => _OtpVerificationViewState();
}

class _OtpVerificationViewState extends State<OtpVerificationView> {
  final _controller = OtpVerificationController();

  @override
  void initState() {
    super.initState();
    _controller.startResendTimer();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final verified = await _controller.verifyOtp();
    if (!mounted) return;

    if (!verified) {
      final error = _controller.errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email verified successfully!')),
    );

    // Route back to the onboarding/login entry point.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingView()),
      (route) => false,
    );
  }

  void _resendCode() {
    if (!_controller.resendCode()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('A fresh 6-digit verification code has been sent.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBEFD3),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.teal),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.busy) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Form(
              key: _controller.formKey,
              child: ListView(
                children: [
                  const SizedBox(height: 20),
                  const Icon(Icons.mark_email_read_outlined,
                      size: 80, color: Colors.teal),
                  const SizedBox(height: 24),
                  const Text(
                    'Verification Code',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We sent a 6-digit secure key to\n${widget.email}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 6-digit OTP field
                  TextFormField(
                    controller: _controller.otpCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      counterText: "",
                      hintText: "000000",
                      hintStyle:
                          TextStyle(color: Colors.grey, letterSpacing: 8),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.teal, width: 2),
                      ),
                    ),
                    validator: _controller.validateOtp,
                  ),
                  const SizedBox(height: 30),

                  FilledButton(
                    onPressed: _verifyOtp,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Verify Code',
                        style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: _controller.canResend ? _resendCode : null,
                    child: Text(
                      _controller.canResend
                          ? 'Resend Verification Code'
                          : 'Resend code available in ${_controller.secondsRemaining} s',
                      style: TextStyle(
                        color: _controller.canResend
                            ? Colors.teal
                            : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
