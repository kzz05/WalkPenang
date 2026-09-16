import 'package:flutter/material.dart';

import '../controllers/logo_controller.dart';
import '../theme/app_theme.dart';
import 'loading_view.dart';
import 'widgets/wp_components.dart';

/// Screen 01 · Splash — version stamp on top, logo centred, tagline below.
class LogoView extends StatefulWidget {
  const LogoView({super.key});

  @override
  State<LogoView> createState() => _LogoViewState();
}

class _LogoViewState extends State<LogoView> {
  final _controller = LogoController();

  @override
  void initState() {
    super.initState();
    _showThenContinue();
  }

  Future<void> _showThenContinue() async {
    // 🕐 Hold on the logo, then move to LoadingView to evaluate auth status.
    await _controller.waitForSplash();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoadingView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const WpMonoLabel('v1.0 · TARC UC'),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/walkpenanglogonobg.png',
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 40),
                      const WpMonoLabel(
                        'explore penang on foot',
                        size: 12,
                        color: AppColors.onPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
