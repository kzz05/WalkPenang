import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'views/logo_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Map & GPS module: loads MAPS_API_KEY from .env for the Places/Directions
  // HTTP calls (see lib/services/map_service.dart). Must run before any
  // dotenv.env[...] read — see .env.example if this file is missing.
  await dotenv.load(fileName: '.env');

  // Map & GPS module: the public (pk.*) Mapbox token the renderer uses to
  // fetch tiles and the custom Studio style. Distinct from the secret
  // download token, which is build-time only and lives in gradle.properties,
  // never here. Must be set before the first MapWidget is built.
  MapboxOptions.setAccessToken(dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '');

  // Republishing a Studio style does not change its URI, so the SDK has no
  // reason to refetch and keeps serving the copy in its ambient cache — the
  // app can render an old basemap for a long time after the new one is live.
  // Clearing is opt-in rather than automatic because doing it every launch
  // would throw away the tile cache too, costing a fresh download (and quota)
  // on every start:
  //
  //   flutter run --dart-define=MAPBOX_CLEAR_CACHE=true
  //
  // Only the map's own cached data goes; the session and profile are
  // untouched.
  if (const bool.fromEnvironment('MAPBOX_CLEAR_CACHE')) {
    await MapboxMapsOptions.clearData();
  }

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
