import 'package:flutter/material.dart';

import '../controllers/verify_email_controller.dart';
import '../theme/app_theme.dart';
import 'loading_view.dart';
import 'onboarding_view.dart';
import 'widgets/wp_components.dart';

/// Screen 05 · Verify Email — the screen that waits for the link to be clicked.
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
              children: [
                // ✉️ Black disc with the envelope mark.
                const Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.surface,
                    child: Icon(
                      Icons.mail_outline_rounded,
                      size: 52,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Check your inbox',
                  textAlign: TextAlign.center,
                  style: AppType.display,
                ),
                const SizedBox(height: 20),
                Text(
                  'We sent a verification link to',
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                Center(child: WpChip(_controller.userEmail)),
                const SizedBox(height: 18),
                Text(
                  'Tap the link and this screen will continue automatically.',
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 36),
                WpPrimaryButton(
                  label: 'resend verification email',
                  onPressed: _controller.canResendEmail ? _resend : null,
                ),
                const SizedBox(height: 14),
                WpOutlineButton(
                  label: 'cancel & log out',
                  onPressed: _handleCancel,
                ),
                const SizedBox(height: 24),
                WpMonoLabel(
                  _controller.canResendEmail
                      ? 'auto-checking every 3s'
                      : 'auto-checking every 3s · resend in '
                      '${_controller.resendCooldown}s',
                  align: TextAlign.center,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
