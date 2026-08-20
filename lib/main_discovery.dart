import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:walkpenang/controllers/discovery_controller.dart';
import 'package:walkpenang/controllers/favorites_controller.dart';
import 'package:walkpenang/firebase_options.dart';
import 'package:walkpenang/services/firestore_place_repository.dart';
import 'package:walkpenang/services/place_repository.dart';
import 'package:walkpenang/theme/app_theme.dart';
import 'package:walkpenang/theme/discovery_theme.dart';
import 'package:walkpenang/views/discovery_feed_view.dart';
import 'package:walkpenang/views/favorites_view.dart';

/// Development entry point for the Food & Attraction Discovery module.
///
/// Boots straight into the feed, backed by the real 'places' Firestore
/// collection (see tool/seed_places.dart) — no login, no onboarding — so
/// the module can be built, tested and demoed on its own.
///
/// Run it with:
///   flutter run -t lib/main_discovery.dart
///
/// The real app still starts from lib/main.dart.
void main() async {
  // shared_preferences and Firebase both need the binding before runApp.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const DiscoveryModuleApp());
}

class DiscoveryModuleApp extends StatefulWidget {
  const DiscoveryModuleApp({super.key});

  @override
  State<DiscoveryModuleApp> createState() => _DiscoveryModuleAppState();
}

class _DiscoveryModuleAppState extends State<DiscoveryModuleApp> {
  /// Backed by Firestore's 'places' collection. Swap back to
  /// MockPlaceRepository() (pass `failureRate: 0.4`) to demo the error and
  /// retry states without touching the network.
  late final PlaceRepository _repository = FirestorePlaceRepository();
  late final DiscoveryController _discovery =
  DiscoveryController(repository: _repository);
  final FavoritesController _favorites = FavoritesController();

  @override
  void initState() {
    super.initState();
    // T-FD04.1 — restore saved place IDs from the previous session.
    _favorites.load();
  }

  @override
  void dispose() {
    _discovery.dispose();
    _favorites.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WalkPenang — Discovery',
      debugShowCheckedModeBanner: false,
      theme: discoveryTheme,
      home: DiscoveryShell(
        discovery: _discovery,
        favorites: _favorites,
        repository: _repository,
      ),
    );
  }
}

/// Discover / Favorites tabs. IndexedStack keeps the feed's scroll position
/// and loaded pages alive when switching tabs and back.
///
/// When the module is folded into the full app, this is the widget to mount
/// from home_view.dart — the entry point above is only for running it alone.
class DiscoveryShell extends StatefulWidget {
  const DiscoveryShell({
    super.key,
    required this.discovery,
    required this.favorites,
    required this.repository,
  });

  final DiscoveryController discovery;
  final FavoritesController favorites;
  final PlaceRepository repository;

  @override
  State<DiscoveryShell> createState() => _DiscoveryShellState();
}

class _DiscoveryShellState extends State<DiscoveryShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          DiscoveryFeedView(
            controller: widget.discovery,
            favorites: widget.favorites,
            repository: widget.repository,
          ),
          FavoritesView(
            favorites: widget.favorites,
            repository: widget.repository,
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: widget.favorites,
        builder: (BuildContext context, _) {
          // Styling comes from `navigationBarTheme` in buildAppTheme, the same
          // source HomeView's WpBottomNav renders from.
          return NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (int value) =>
                setState(() => _index = value),
            destinations: <Widget>[
              const NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Discover',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: widget.favorites.count > 0,
                  backgroundColor: AppColors.primaryDeep,
                  label: Text('${widget.favorites.count}'),
                  child: const Icon(Icons.favorite_border),
                ),
                selectedIcon: const Icon(Icons.favorite),
                label: 'Favorites',
              ),
            ],
          );
        },
      ),
    );
  }
}