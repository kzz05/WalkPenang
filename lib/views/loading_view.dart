import 'package:flutter/material.dart';

import '../controllers/loading_controller.dart';
import 'home_view.dart';
import 'onboarding_view.dart';
import 'verify_email_view.dart';

class LoadingView extends StatefulWidget {
  const LoadingView({super.key});

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView> {
  final _controller = LoadingController();

  @override
  void initState() {
    super.initState();
    _goToResolvedDestination();
  }

  Future<void> _goToResolvedDestination() async {
    final route = await _controller.resolveDestination();
    if (!mounted) return;

    final Widget next = switch (route.destination) {
      LoadingDestination.onboarding => const OnboardingView(),
      LoadingDestination.verifyEmail => const VerifyEmailView(),
      LoadingDestination.completeProfile =>
        OnboardingView(existingUser: route.user),
      LoadingDestination.home => HomeView(profile: route.profile!),
    };

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
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
