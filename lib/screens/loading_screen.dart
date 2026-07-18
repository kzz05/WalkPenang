import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'onboarding_screen.dart';
import 'edit_profile_screen.dart';
import 'verify_email_screen.dart';
import '../services/profile_store.dart';
import '../models/user_profile.dart';
import 'home_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  final _store = ProfileStore();

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final user = FirebaseAuth.instance.currentUser;
    await Future.delayed(const Duration(milliseconds: 1750));

    if (user == null) {
      // No user logged in -> Go to Onboarding/Auth
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    // 🛡️ If they signed up with email/password but never verified it,
    // send them to verification instead of looping them back through
    // the login form.
    if (!user.emailVerified &&
        user.providerData.any((p) => p.providerId == 'password')) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
      );
      return;
    }

    // User exists -> Check if their Firestore profile is complete
    final profile = await _store.load();
    if (!mounted) return;

    if (profile != null && profile.isComplete) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(profile: profile)),
      );
    } else {
      // 🛠️ FIX: they're already signed in with Firebase, so don't send them
      // back through the email/password (or Google) login form again.
      // Pass the existing user along so OnboardingScreen can jump straight
      // to the "finish your profile" step.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OnboardingScreen(existingUser: user),
        ),
      );
    }
  }

  void _navigateTo(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffff1d5),
      body: SizedBox.expand(
        child: Image.asset(
          'assets/images/loadinganimation.GIF',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}