import 'package:flutter/material.dart';

import 'package:walkpenang/controllers/discovery_controller.dart';
import 'package:walkpenang/controllers/favorites_controller.dart';
import 'package:walkpenang/main_discovery.dart' show DiscoveryShell;
import 'package:walkpenang/services/google_places_repository.dart';
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
  const DiscoveryModuleView({super.key, required this.favorites});

  /// The app-wide favourites controller, owned by [HomeView]. Shared so a
  /// heart toggled here shows on the Home map carousel too, and vice versa.
  final FavoritesController favorites;

  @override
  State<DiscoveryModuleView> createState() => _DiscoveryModuleViewState();
}

class _DiscoveryModuleViewState extends State<DiscoveryModuleView> {
  /// Live Places API (New) data around Penang, the same source
  /// main_discovery.dart uses when the module runs standalone. Reviews,
  /// ratings and favourites still come from Firestore, keyed by Google's
  /// place id — Google doesn't let the app write reviews back.
  ///
  /// This was MockPlaceRepository() until the Places-backed implementation
  /// landed. The seed data it served used real Penang names, so the feed
  /// looked plausible while showing invented details and reviews.
  /// MockPlaceRepository is still the way to demo the error and retry states
  /// offline — construct it with `failureRate: 0.4`.
  late final PlaceRepository _repository = GooglePlacesRepository();
  late final DiscoveryController _discovery =
      DiscoveryController(repository: _repository);

  @override
  void dispose() {
    _discovery.dispose();
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
          // No Theme override here any more: the module used to need its own
          // one, but its palette, fonts and radii are now the app's, so the
          // ambient theme is already the right one.
          Expanded(
            child: DiscoveryShell(
              discovery: _discovery,
              favorites: widget.favorites,
              repository: _repository,
            ),
          ),
        ],
      ),
    );
  }
}
