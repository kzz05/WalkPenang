import 'package:flutter/material.dart';

import '../controllers/logo_controller.dart';
import 'loading_view.dart';

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
      // 🎨 Matches the exact cream background hex code of the image asset.
      backgroundColor: const Color(0xfffff1d5),
      body: Center(
        child: Padding(
          // 📐 Keeps the artwork framed away from the screen edges.
          padding: const EdgeInsets.all(40.0),
          child: Image.asset(
            'assets/images/walkpenanglogowithbg.PNG',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
