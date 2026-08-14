// Debug-only entry point that boots straight into the Map & GPS screen
// (UC-007 / UC-008 / UC-009), skipping the logo -> loading -> auth chain.
//
//     flutter run -t lib/debug/map_preview_main.dart
//
// Same idea as journey_ui_preview_main.dart, for the same reason: checking
// how the map actually renders shouldn't require signing in first. This is a
// separate `main()`, so lib/main.dart stays exactly as it ships — there is no
// debug branch anywhere in the production startup path.
//
// Firebase is deliberately not initialised: MapView, MapController and every
// service behind them (location, places, boundary, route) touch neither
// Firestore nor Auth. Only dotenv and the Mapbox token are needed.
//
// Pair it with a mock location for anywhere outside Penang, or the boundary
// check (UC-009) will correctly report you as outside the state:
//
//     adb emu geo fix 100.3288 5.4141      # note: longitude first
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../theme/app_theme.dart';
import '../views/map_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  MapboxOptions.setAccessToken(dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '');

  runApp(
    MaterialApp(
      title: 'WalkPenang — Map preview',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const MapView(),
    ),
  );
}
