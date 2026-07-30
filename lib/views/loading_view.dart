import 'package:flutter/material.dart';

import '../controllers/loading_controller.dart';
import '../theme/app_theme.dart';
import 'home_view.dart';
import 'onboarding_view.dart';
import 'verify_email_view.dart';
import 'widgets/wp_components.dart';

/// Screen 02 · Loading — logo, a sand progress bar, and a mono status line.
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/walkpenanglogonobg.png',
                  height: 160,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 36),

                // 📊 Fills over the controller's minimum display time, so the
                // bar finishes at roughly the moment the screen hands over.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: LoadingController.minimumDisplay,
                  curve: Curves.easeOut,
                  builder: (context, value, _) => ClipRRect(
                    borderRadius: AppRadius.mdAll,
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: AppColors.placeholder,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const WpMonoLabel(
                  'preparing your journey',
                  size: 12,
                  color: AppColors.onPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
