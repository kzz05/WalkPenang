import 'package:flutter/material.dart';

import 'package:walkpenang/controllers/discovery_controller.dart';
import 'package:walkpenang/controllers/favorites_controller.dart';
import 'package:walkpenang/main_discovery.dart' show DiscoveryShell;
import 'package:walkpenang/services/place_repository.dart';
import 'package:walkpenang/theme/app_theme.dart';
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
  /// True when this screen is a tab inside HomeView's sheet rather than a
  /// pushed route.
  ///
  /// Drops its own Scaffold and back bar: the sheet supplies the surface, and
  /// the way out is the X pinned at the corner, not a back arrow that would
  /// have nothing to pop.
  final bool embedded;

  const DiscoveryModuleView({super.key, this.embedded = false});

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
    final content = Column(
        children: [
          // Pushed modules each provide their own way back — the reward module
          // uses this same component. Without one the only exit would be the
          // Android system back gesture, since DiscoveryShell has no AppBar.
          // Embedded in the tab sheet there is nothing to pop, and the sheet's
          // X is the exit, so it is left out.
          if (!widget.embedded)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                child: WpBackBar(onBack: () => Navigator.of(context).pop()),
              ),
            ),
          // No Theme override here any more: the module used to need its own
          // one, but its palette, fonts and radii are now the app's, so the
          // ambient theme is already the right one.
          Expanded(
            child: DiscoveryShell(
              discovery: _discovery,
              favorites: _favorites,
              repository: _repository,
            ),
          ),
        ],
      );

    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: content,
    );
  }
}
