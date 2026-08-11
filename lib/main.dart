import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'views/logo_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Map & GPS module: loads MAPS_API_KEY from .env for the Places/Directions
  // HTTP calls (see lib/services/map_service.dart). Must run before any
  // dotenv.env[...] read — see .env.example if this file is missing.
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const WalkPenangApp());
}

class WalkPenangApp extends StatelessWidget {
  const WalkPenangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WalkPenang',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const LogoView(),
    );
  }
}
