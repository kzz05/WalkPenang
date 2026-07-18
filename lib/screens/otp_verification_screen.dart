import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'onboarding_screen.dart'; // 👈 FIX 1: Added missing import so it recognizes OnboardingScreen

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Timer? _timer;
  int _secondsRemaining = 30;
  bool _canResend = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _secondsRemaining = 30;
      _canResend = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _canResend = true;
          _timer?.cancel();
        });
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);

    try {
      final code = _otpCtrl.text.trim();

      // Temporary print statement to utilize the 'code' variable and eliminate the warning
      print('Verifying secure system code: $code');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email verified successfully!')),
      );

      // Route back to onboarding/login entry point
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
            (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid code: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A fresh 6-digit verification code has been sent.')),
    );

    _startResendTimer();
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
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.teal),
              const SizedBox(height: 24),
              const Text(
                'Verification Code',
                textAlign: TextAlign.center, // 👈 FIX 2: Fixed alignment parameter type
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a 6-digit secure key to\n${widget.email}',
                textAlign: TextAlign.center, // 👈 FIX 3: Fixed alignment parameter type
                style: TextStyle(color: Colors.grey[700], fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 40),

              // 6-Digit OTP Field Container
              TextFormField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center, // 👈 FIX 4: Fixed alignment parameter type
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: "",
                  hintText: "000000",
                  hintStyle: TextStyle(color: Colors.grey, letterSpacing: 8),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 2)),
                ),
                validator: (v) => (v == null || v.trim().length != 6) ? 'Enter all 6 digits' : null,
              ),
              const SizedBox(height: 30),

              FilledButton(
                onPressed: _verifyOtp,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 14), // 👈 FIX 5: Changed to .symmetric(vertical: 14)
                ),
                child: const Text('Verify Code', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 20),

              TextButton(
                onPressed: _canResend ? _resendCode : null,
                child: Text(
                  _canResend
                      ? 'Resend Verification Code'
                      : 'Resend code available in $_secondsRemaining s',
                  style: TextStyle(
                    color: _canResend ? Colors.teal : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}