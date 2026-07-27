import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controllers/onboarding_controller.dart';
import 'home_view.dart';
import 'verify_email_view.dart';

// 🎨 Brand palette pulled straight from the WalkPenang logo mark.
class _Brand {
  static const cream = Color(0xFFFFF1D5); // matches LogoView/LoadingView
  static const indigo = Color(0xFF3D2FE0); // the "W" figure
  static const pink = Color(0xFFEC3D96); // the outline / wordmark
  static const mint = Color(0xFF4CE6B0); // the "P" figure
  static const ink = Color(0xFF241C4D); // body text on cream
}

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
          MaterialPageRoute(builder: (_) => const VerifyEmailView()),
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
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: _Brand.cream,
      body: SafeArea(
        child: Column(
          children: [
            // 🏷️ Logo hero — fills the top 40% of the screen.
            SizedBox(
              height: screenHeight * 0.40,
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 16, 48, 8),
                child: Image.asset(
                  'assets/images/walkpenanglogonew.PNG',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  if (_controller.busy) {
                    return const Center(
                      child: CircularProgressIndicator(color: _Brand.indigo),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: _controller.isAuthenticated
                        ? _buildMetricsPhase()
                        : _buildAuthPhase(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Shared field styling so every input on this screen matches the brand.
  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _Brand.ink),
      prefixIcon: Icon(icon, color: _Brand.pink),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: border(Colors.transparent, 0),
      enabledBorder: border(_Brand.indigo.withOpacity(0.15), 1.4),
      focusedBorder: border(_Brand.indigo, 2),
      errorBorder: border(_Brand.pink, 1.4),
      focusedErrorBorder: border(_Brand.pink, 2),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  Widget _buildAuthPhase() {
    return Form(
      key: _controller.authFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 🖊️ Register / sign in column
          TextFormField(
            controller: _controller.emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: _Brand.ink),
            decoration: _fieldDecoration(
              label: 'Email address',
              icon: Icons.alternate_email_rounded,
            ),
            validator: _controller.validateEmail,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _controller.passwordCtrl,
            obscureText: _controller.obscurePassword,
            style: const TextStyle(color: _Brand.ink),
            decoration: _fieldDecoration(
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _controller.obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _Brand.ink.withOpacity(0.5),
                ),
                onPressed: _controller.togglePasswordVisibility,
              ),
            ),
            validator: _controller.validatePassword,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _controller.busy ? null : _handleAuth,
              style: FilledButton.styleFrom(
                backgroundColor: _Brand.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Sign In / Register',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // — divider —
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Row(
              children: [
                Expanded(child: Divider(color: Color(0x333D2FE0))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: _Brand.ink,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Color(0x333D2FE0))),
              ],
            ),
          ),

          // 🟢 Google sign-in
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _controller.busy ? null : _handleGoogleAuth,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: _Brand.mint, width: 1.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.g_mobiledata,
                  size: 28, color: _Brand.indigo),
              label: const Text(
                'Continue with Google',
                style: TextStyle(
                  color: _Brand.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsPhase() {
    final selectedImage = _controller.selectedImage;

    return Form(
      key: _controller.profileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: _Brand.indigo.withOpacity(0.1),
                  backgroundImage:
                      selectedImage != null ? FileImage(selectedImage) : null,
                  child: selectedImage == null
                      ? const Icon(Icons.person, size: 50, color: _Brand.indigo)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: _Brand.pink,
                    radius: 17,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt,
                          size: 15, color: Colors.white),
                      onPressed: _controller.pickImage,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Let's finish setting up your fitness profile.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: _Brand.indigo,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _controller.nicknameCtrl,
            style: const TextStyle(color: _Brand.ink),
            decoration: _fieldDecoration(
              label: 'Display name / nickname',
              icon: Icons.badge_outlined,
            ),
            validator: (v) => _controller.validateRequired(v, 'Name required'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _controller.phoneCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: _Brand.ink),
            decoration: _fieldDecoration(
              label: 'Contact number',
              icon: Icons.call_outlined,
            ),
            validator: (v) =>
                _controller.validateRequired(v, 'Contact details required'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _controller.heightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: _Brand.ink),
                  decoration: _fieldDecoration(
                    label: 'Height (cm)',
                    icon: Icons.height_rounded,
                  ),
                  validator: _controller.validateMeasurement,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _controller.weightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: _Brand.ink),
                  decoration: _fieldDecoration(
                    label: 'Weight (kg)',
                    icon: Icons.monitor_weight_outlined,
                  ),
                  validator: _controller.validateMeasurement,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _controller.units,
            style: const TextStyle(color: _Brand.ink),
            decoration: _fieldDecoration(
              label: 'System units',
              icon: Icons.straighten_outlined,
            ),
            items: const [
              DropdownMenuItem(value: 'metric', child: Text('Metric (kg, km)')),
              DropdownMenuItem(
                  value: 'imperial', child: Text('Imperial (lb, mi)')),
            ],
            onChanged: _controller.setUnits,
          ),
          if (_controller.bmi > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _Brand.mint.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _Brand.mint, width: 1.2),
              ),
              child: Text(
                'Auto calculated BMI: ${_controller.bmi.toStringAsFixed(1)} (${_controller.bmiCategory})',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _Brand.ink,
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _handleCompleteProfile,
              style: FilledButton.styleFrom(
                backgroundColor: _Brand.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Finalize Account Setup',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
