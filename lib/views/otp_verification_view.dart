import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/otp_verification_controller.dart';
import '../theme/app_theme.dart';
import 'onboarding_view.dart';
import 'widgets/wp_components.dart';

/// Screen 09 · OTP Verification.
///
/// ⚠️ Not wired into navigation — the app verifies email addresses through
/// Firebase email links (see VerifyEmailView). Kept for a future SMS/OTP flow,
/// which is why the design carries a "PLANNED FLOW · NOT WIRED" flag.
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
    // The digit boxes are painted from the controller's text, so repaint on
    // every keystroke. Purely visual state, so it stays in the view.
    _controller.otpCtrl.addListener(_onDigitsChanged);
  }

  @override
  void dispose() {
    _controller.otpCtrl.removeListener(_onDigitsChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onDigitsChanged() => setState(() {});

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

        return WpScreen(
          children: [
            WpBackBar(onBack: () => Navigator.of(context).pop()),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: WpChip(
                'planned flow · not wired',
                background: AppColors.primary,
                uppercase: true,
              ),
            ),
            const SizedBox(height: 20),
            Text('Verification code', style: AppType.display),
            const SizedBox(height: 16),
            Text(
              'Enter the 6-digit key we sent to',
              style: AppType.body.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerLeft, child: WpChip(widget.email)),
            const SizedBox(height: 24),
            Form(key: _controller.formKey, child: _buildDigitBoxes()),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _controller.canResend ? _resendCode : null,
                behavior: HitTestBehavior.opaque,
                child: WpMonoLabel(
                  _controller.canResend
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
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
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
          color: AppColors.border,
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
