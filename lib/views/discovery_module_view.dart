import 'package:flutter/material.dart';

import 'package:walkpenang/controllers/discovery_controller.dart';
import 'package:walkpenang/controllers/favorites_controller.dart';
import 'package:walkpenang/main_discovery.dart' show DiscoveryShell;
import 'package:walkpenang/services/place_repository.dart';
import 'package:walkpenang/theme/app_theme.dart';
import 'package:walkpenang/theme/discovery_theme.dart';
import 'package:walkpenang/views/widgets/wp_components.dart';

/// Production entry point for the Food & Attraction Discovery module
/// (US-FD01, US-FD02), pushed from the "explore" slot in HomeView's bottom nav.
///
/// The module ships its own [DiscoveryShell] — the Discover / Favorites tab
/// pair — which main_discovery.dart mounts when the module is run standalone
/// via `flutter run -t lib/main_discovery.dart`. This widget is the other
/// mount point: it supplies the three long-lived objects the shell needs and
/// owns their lifecycle, so the rest of the app doesn't have to know about
/// them. Nothing inside the module is modified.
class DiscoveryModuleView extends StatefulWidget {
  const DiscoveryModuleView({super.key});

  @override
  State<DiscoveryModuleView> createState() => _DiscoveryModuleViewState();
}

class _DiscoveryModuleViewState extends State<DiscoveryModuleView> {
  /// Seeded, in-process data. The module has no HTTP repository yet — swap
  /// this for the real one once the Places-backed implementation lands, which
  /// is the single change needed to put live data behind these screens.
  late final PlaceRepository _repository = MockPlaceRepository();
  late final DiscoveryController _discovery =
      DiscoveryController(repository: _repository);
  final FavoritesController _favorites = FavoritesController();

  @override
  void initState() {
    super.initState();
    // T-FD04.1 — restore saved place IDs from the previous session. The
    // default store is SharedPrefsFavoritesStore, so favourites survive both
    // leaving this screen and restarting the app.
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Pushed modules each provide their own way back — the reward module
          // uses this same component. Without one the only exit would be the
          // Android system back gesture, since DiscoveryShell has no AppBar.
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: WpBackBar(onBack: () => Navigator.of(context).pop()),
            ),
          ),
          // discoveryTheme is applied by MaterialApp when the module runs
          // standalone. Pushed inside the app the ambient theme is the app's
          // instead, so re-apply it here or the module's cards, chips and
          // NavigationBar lose the styling they were designed against.
          Expanded(
            child: Theme(
              data: discoveryTheme,
              child: DiscoveryShell(
                discovery: _discovery,
                favorites: _favorites,
                repository: _repository,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
