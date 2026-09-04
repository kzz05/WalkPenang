import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'controllers/journey_session.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'views/logo_view.dart';
import 'views/widgets/journey_mini_bar.dart';

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
      // A minimised journey has to be re-openable from the mini bar, which is
      // drawn above every route and so has no route context of its own to push
      // from (see JourneySession.expand).
      navigatorKey: JourneySession.navigatorKey,
      builder: (context, child) => JourneyOverlayHost(child: child!),
      home: const LogoView(),
    );
  }
}
