import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/otp_verification_controller.dart';
import '../theme/app_theme.dart';
import 'home_view.dart';
import 'loading_view.dart';
import 'onboarding_view.dart';
import 'widgets/wp_components.dart';

/// Screen 09 · OTP Verification.
///
/// The live email-verification step: a 6-digit code is mailed by the
/// `sendEmailOtp` Cloud Function and checked by `verifyEmailOtp`. Replaces the
/// old email-link screen, which required leaving the app to click a link.
class OtpVerificationView extends StatefulWidget {
  const OtpVerificationView({super.key});

  @override
  State<OtpVerificationView> createState() => _OtpVerificationViewState();
}

class _OtpVerificationViewState extends State<OtpVerificationView> {
  final _controller = OtpVerificationController();

  @override
  void initState() {
    super.initState();
    // The digit boxes are painted from the controller's text, so repaint on
    // every keystroke. Purely visual state, so it stays in the view.
    _controller.otpCtrl.addListener(_onDigitsChanged);
    _sendFirstCode();
  }

  @override
  void dispose() {
    _controller.otpCtrl.removeListener(_onDigitsChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onDigitsChanged() => setState(() {});

  Future<void> _sendFirstCode() async {
    _showIfError(await _controller.start());
  }

  Future<void> _resendCode() async {
    final error = await _controller.resendCode();
    if (!mounted) return;

    _showIfError(error);
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A fresh 6-digit code is on its way.')),
      );
    }
  }

  void _showIfError(String? error) {
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  Future<void> _verifyOtp() async {
    final outcome = await _controller.verifyOtp();
    if (!mounted) return;

    switch (outcome.next) {
      case OtpNext.stay:
      // The error is already rendered under the boxes by the controller.
        return;
      case OtpNext.home:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomeView(profile: outcome.profile!),
          ),
              (route) => false,
        );
      case OtpNext.completeProfile:
      // Let LoadingView re-resolve — it already knows how to hand the
      // signed-in user to the profile-setup form.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoadingView()),
              (route) => false,
        );
    }
  }

  /// Abandons verification, ends the session, and returns to sign-in.
  Future<void> _cancel() async {
    await _controller.cancel();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingView()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.busy) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final error = _controller.errorMessage;

        return WpScreen(
          children: [
            WpBackBar(onBack: _cancel),
            const SizedBox(height: 8),
            Text('Verification code', style: AppType.display),
            const SizedBox(height: 16),
            Text(
              'Enter the 6-digit key we sent to',
              style: AppType.body.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: WpChip(_controller.email),
            ),
            const SizedBox(height: 24),
            Form(key: _controller.formKey, child: _buildDigitBoxes()),

            // ⚠️ Wrong / expired / rate-limited codes report here, right
            // under the boxes the user just typed into.
            if (error != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.dangerTint,
                  borderRadius: AppRadius.smAll,
                ),
                child: WpMonoLabel(
                  error,
                  size: 11,
                  color: AppColors.danger,
                  align: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _controller.canResend ? _resendCode : null,
                behavior: HitTestBehavior.opaque,
                child: WpMonoLabel(
                  _controller.sending
                      ? 'sending…'
                      : _controller.canResend
                      ? 'resend verification code'
                      : 'resend code in ${_controller.secondsRemaining}s',
                  size: 11,
                  color: _controller.canResend
                      ? AppColors.onPrimary
                      : AppColors.muted,
                ),
              ),
            ),
            const SizedBox(height: 32),
            WpPrimaryButton(label: 'verify code', onPressed: _verifyOtp),
            const SizedBox(height: 14),
            WpOutlineButton(label: 'cancel & log out', onPressed: _cancel),
          ],
        );
      },
    );
  }

  /// Six painted boxes with one invisible field stretched across them, so the
  /// controller keeps owning a single 6-character string.
  Widget _buildDigitBoxes() {
    final digits = _controller.otpCtrl.text;

    return Stack(
      children: [
        IgnorePointer(
          child: Row(
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _digitBox(digits, i)),
              ],
            ],
          ),
        ),
        Positioned.fill(
          child: TextFormField(
            controller: _controller.otpCtrl,
            validator: _controller.validateOtp,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            // Invisible: the boxes above are what the user actually reads.
            style: const TextStyle(color: Colors.transparent, fontSize: 1),
            cursorColor: Colors.transparent,
            showCursor: false,
            decoration: const InputDecoration(
              counterText: '',
              // This field is a transparent hit target laid over the six
              // painted boxes, so it must opt out of the app-wide filled
              // input style — otherwise the theme's white fill covers them.
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              // The controller surfaces validation in its own error panel.
              errorStyle: TextStyle(fontSize: 0, height: 0),
            ),
            onFieldSubmitted: (_) => _verifyOtp(),
          ),
        ),
      ],
    );
  }

  Widget _digitBox(String digits, int index) {
    final filled = index < digits.length;
    final isNext = index == digits.length;

    return AspectRatio(
      aspectRatio: 0.85,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: AppRadius.smAll,
          border: Border.all(
            color: isNext ? AppColors.primary : AppColors.outline,
            width: isNext ? 1.8 : 1,
          ),
        ),
        child: filled
            ? Text(digits[index], style: AppType.stat.copyWith(fontSize: 24))
            : const Icon(Icons.circle, size: 5, color: AppColors.muted),
      ),
    );
  }
}
