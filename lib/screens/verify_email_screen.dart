import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'loading_screen.dart';
import 'onboarding_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _auth = AuthService();
  bool _isEmailVerified = false;
  bool _canResendEmail = true;
  Timer? _timer;
  int _resendCooldown = 60;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();

    // 1. Check if user is already verified natively right away
    _isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!_isEmailVerified) {
      // 2. Send the link immediately upon entering the screen
      _sendVerificationEmail();

      // 3. Start checking every 3 seconds if the user clicked the link
      _timer = Timer.periodic(
        const Duration(seconds: 3),
            (_) => _checkEmailVerified(),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    try {
      await _auth.sendVerificationEmail();
      setState(() => _canResendEmail = false);

      // Start a 60-second visual cooldown countdown
      _resendCooldown = 60;
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_resendCooldown == 0) {
          setState(() => _canResendEmail = true);
          timer.cancel();
        } else {
          setState(() => _resendCooldown--);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending link: $e')),
        );
      }
    }
  }

  Future<void> _checkEmailVerified() async {
    try {
      await FirebaseAuth.instance.currentUser?.reload();
    } catch (_) {
      return; // transient error — let the next 3s tick retry instead of killing the loop
    }

    if (!mounted) return;

    final verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    setState(() => _isEmailVerified = verified);

    if (verified) {
      _timer?.cancel();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoadingScreen()),
      );
    }
  }


  Future<void> _handleCancel() async {
    _timer?.cancel();
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'your email';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.email_outlined, size: 100, color: Colors.teal),
            const SizedBox(height: 30),
            const Text(
              'A verification email has been sent to:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              userEmail,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 24),
            const Text(
              'Please check your inbox (and spam folder) and click the confirmation link to automatically continue.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 40),

            // Resend Button with Cooldown state
            FilledButton.icon(
              onPressed: _canResendEmail ? _sendVerificationEmail : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.teal,
                disabledBackgroundColor: Colors.teal.shade100,
              ),
              icon: const Icon(Icons.refresh),
              label: Text(
                _canResendEmail ? 'Resend Verification Email' : 'Resend Link in ${_resendCooldown}s',
              ),
            ),
            const SizedBox(height: 12),

            // Cancel Button
            OutlinedButton(
              onPressed: _handleCancel,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel & Log Out'),
            ),
          ],
        ),
      ),
    );
  }
}