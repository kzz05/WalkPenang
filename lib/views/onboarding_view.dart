import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controllers/onboarding_controller.dart';
import '../theme/app_theme.dart';
import 'home_view.dart';
import 'otp_verification_view.dart';
import 'widgets/wp_components.dart';

/// Screens 03 · Sign In and 04 · Profile Setup.
///
/// One view, two phases: the auth form swaps for the fitness form the moment
/// the controller reports an authenticated user.
class OnboardingView extends StatefulWidget {
  final User? existingUser;

  const OnboardingView({super.key, this.existingUser});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  late final OnboardingController _controller =
  OnboardingController(existingUser: widget.existingUser);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Wiring: run a controller action, then react to its outcome ────────────

  Future<void> _handleAuth() => _apply(_controller.signInOrRegister());

  Future<void> _handleGoogleAuth() => _apply(_controller.signInWithGoogle());

  Future<void> _handleCompleteProfile() => _apply(_controller.completeProfile());

  Future<void> _apply(Future<OnboardingOutcome> action) async {
    final outcome = await action;
    if (!mounted) return;

    if (outcome.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(outcome.error!)),
      );
      return;
    }

    switch (outcome.next) {
      case OnboardingNext.stay:
        return;
      case OnboardingNext.verifyEmail:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OtpVerificationView()),
        );
      case OnboardingNext.home:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeView(profile: outcome.profile!),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            if (_controller.busy) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              children: _controller.isAuthenticated
                  ? _buildMetricsPhase()
                  : _buildAuthPhase(),
            );
          },
        ),
      ),
    );
  }

  // ── Phase 1 · Sign in ─────────────────────────────────────────────────────

  List<Widget> _buildAuthPhase() {
    return [
      const WpPageTitle(
        'Sign in',
        caption: 'one form · signs you in or creates the account',
      ),
      const SizedBox(height: 40),
      Form(
        key: _controller.authFormKey,
        child: Column(
          children: [
            WpField(
              label: 'email address',
              controller: _controller.emailCtrl,
              keyboardType: TextInputType.emailAddress,
              validator: _controller.validateEmail,
            ),
            const SizedBox(height: 20),
            WpField(
              label: 'password',
              controller: _controller.passwordCtrl,
              obscureText: _controller.obscurePassword,
              validator: _controller.validatePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _controller.obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: AppColors.muted,
                ),
                onPressed: _controller.togglePasswordVisibility,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      WpPrimaryButton(
        label: 'sign in / register',
        onPressed: _handleAuth,
      ),
      const SizedBox(height: 24),
      const WpOrDivider(),
      const SizedBox(height: 24),
      WpOutlineButton(
        label: 'continue with google',
        onPressed: _handleGoogleAuth,
      ),
    ];
  }

  // ── Phase 2 · Profile setup ───────────────────────────────────────────────

  List<Widget> _buildMetricsPhase() {
    final selectedImage = _controller.selectedImage;

    return [
      const WpPageTitle(
        'Set up your profile',
        caption: 'step 2 of 2 · fitness configuration',
      ),
      const SizedBox(height: 28),
      Center(
        child: WpAvatar(
          radius: 55,
          background: AppColors.surface,
          image: selectedImage != null ? FileImage(selectedImage) : null,
          onEdit: _controller.pickImage,
        ),
      ),
      const SizedBox(height: 28),
      Form(
        key: _controller.profileFormKey,
        child: Column(
          children: [
            WpField(
              label: 'display name / nickname',
              controller: _controller.nicknameCtrl,
              validator: (v) =>
                  _controller.validateRequired(v, 'Name required'),
            ),
            const SizedBox(height: 20),
            WpField(
              label: 'contact number',
              controller: _controller.phoneCtrl,
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  _controller.validateRequired(v, 'Contact details required'),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: WpField(
                    label: 'height (cm)',
                    controller: _controller.heightCtrl,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    validator: _controller.validateMeasurement,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: WpField(
                    label: 'weight (kg)',
                    controller: _controller.weightCtrl,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    validator: _controller.validateMeasurement,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            WpDropdownField(
              label: 'system units',
              value: _controller.units,
              options: const {
                'metric': 'Metric (kg, cm)',
                'imperial': 'Imperial (lb, in)',
              },
              onChanged: _controller.setUnits,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      BmiCard(bmi: _controller.bmi, category: _controller.bmiCategory),
      const SizedBox(height: 24),
      WpPrimaryButton(
        label: 'finalize account setup',
        onPressed: _handleCompleteProfile,
      ),
    ];
  }
}

/// The black BMI read-out: mono label, big number, and a sand category pill.
class BmiCard extends StatelessWidget {
  final double bmi;
  final String category;

  const BmiCard({super.key, required this.bmi, required this.category});

  @override
  Widget build(BuildContext context) {
    final hasValue = bmi > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WpMonoLabel(
                  'body mass index',
                  color: AppColors.onSurfaceMuted,
                ),
                const SizedBox(height: 6),
                Text(
                  hasValue ? bmi.toStringAsFixed(1) : '—',
                  style: AppType.stat.copyWith(
                    color: Colors.white,
                    fontSize: 32,
                  ),
                ),
              ],
            ),
          ),
          if (hasValue)
            WpChip(
              category,
              background: AppColors.primary,
              uppercase: true,
            ),
        ],
      ),
    );
  }
}
