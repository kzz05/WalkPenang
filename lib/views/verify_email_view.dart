import 'package:flutter/material.dart';

import '../controllers/verify_email_controller.dart';
import 'loading_view.dart';
import 'onboarding_view.dart';

class VerifyEmailView extends StatefulWidget {
  const VerifyEmailView({super.key});

  @override
  State<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<VerifyEmailView> {
  final _controller = VerifyEmailController();

  @override
  void initState() {
    super.initState();
    // The controller polls Firebase; this fires as soon as the link is clicked.
    _controller.onVerified = _goToLoading;
    _start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final error = await _controller.start();
    _showIfError(error);
  }

  Future<void> _resend() async {
    final error = await _controller.sendVerificationEmail();
    _showIfError(error);
  }

  void _showIfError(String? error) {
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  void _goToLoading() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoadingView()),
    );
  }

  Future<void> _handleCancel() async {
    await _controller.cancel();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Column(
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
                  _controller.userEmail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Please check your inbox (and spam folder) and click the confirmation link to automatically continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 40),

                // Resend button with cooldown state
                FilledButton.icon(
                  onPressed: _controller.canResendEmail ? _resend : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal,
                    disabledBackgroundColor: Colors.teal.shade100,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    _controller.canResendEmail
                        ? 'Resend Verification Email'
                        : 'Resend Link in ${_controller.resendCooldown}s',
                  ),
                ),
                const SizedBox(height: 12),

                // Cancel button
                OutlinedButton(
                  onPressed: _handleCancel,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Cancel & Log Out'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
