import 'dart:async';
import 'package:flutter/material.dart';
import 'loading_screen.dart';

class LogoScreen extends StatefulWidget {
  const LogoScreen({super.key});

  @override
  State<LogoScreen> createState() => _LogoScreenState();
}

class _LogoScreenState extends State<LogoScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  void _navigateToNextScreen() async {
    // 🕐 Wait for 2.5 seconds to show off your beautiful logo
    await Future.delayed(const Duration(milliseconds: 3000));

    if (!mounted) return;

    // 🚀 Move directly to the LoadingScreen to evaluate auth status
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoadingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🎨 Matches the exact cream background hex code of your new image asset
      backgroundColor: const Color(0xfffff1d5),
      body: Center(
        child: Padding(
          // 📐 Estimated ideal margin/padding to keep the artwork perfectly framed away from screen edges
          padding: const EdgeInsets.all(40.0),
          child: Image.asset(
            'assets/images/walkpenanglogowithbg.PNG',
            fit: BoxFit.contain, // Ensures the image scales elegantly without distortion
          ),
        ),
      ),
    );
  }
}