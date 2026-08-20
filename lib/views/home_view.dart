import 'package:flutter/material.dart';

import '../controllers/home_controller.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'discovery_module_view.dart';
import 'edit_profile_view.dart';
import 'map_view.dart';
import 'reward/stats_dashboard_screen.dart';
import 'reward/walking_journal_screen.dart';
import 'settings_view.dart';
import 'widgets/wp_components.dart';
import 'widgets/wp_tab_sheet.dart';

/// Screen 06 · Home — a full-bleed map with every other destination behind a
/// single control in the bottom-left corner.
///
/// There is no bottom navigation bar and no "home" tab, because the map *is*
/// home: the sheet slides up over it and closing the sheet is how you get
/// back. That is what gives the close button one unambiguous meaning, and it
/// hands the whole screen to the map rather than permanently reserving a strip
/// of it for a nav bar.
class HomeView extends StatefulWidget {
  final UserProfile profile;

  const HomeView({super.key, required this.profile});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeController _controller = HomeController(widget.profile);

  bool _sheetOpen = false;
  int _tabIndex = 0;

  void _toggleSheet() => setState(() => _sheetOpen = !_sheetOpen);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsView(profile: _controller.profile),
      ),
    );
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) => EditProfileView(profile: _controller.profile),
      ),
    );
    if (updated != null) _controller.updateProfile(updated);
  }

  /// The sheet's destinations.
  ///
  /// Each is the same screen that used to be pushed as a route, built with
  /// `embedded: true` so it drops its own Scaffold and back bar — inside the
  /// sheet there is nothing to pop, and the corner X is the way out.
  ///
  /// Discovery keeps its own Discover / Favorites tabs. Two levels of tabs is
  /// tolerable where two nav bars was not, because the outer row is pills at
  /// the top of a sheet rather than a second bar competing at the bottom.
  List<WpTab> get _tabs => [
        WpTab(
          label: 'Explore',
          builder: (_) => const DiscoveryModuleView(embedded: true),
        ),
        WpTab(
          label: 'Walk',
          builder: (_) => const WalkingJournalScreen(embedded: true),
        ),
        WpTab(
          label: 'Rewards',
          builder: (_) => const StatsDashboardScreen(embedded: true),
        ),
        WpTab(
          label: 'Account',
          builder: (_) => _AccountMenu(
            onEditProfile: _openEditProfile,
            onSettings: _openSettings,
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // With the sheet open, back closes it rather than leaving the app.
      // Without this the system gesture would pop HomeView itself, which on
      // the root route means exiting — a tourist reading their journal and
      // swiping back would find the app gone.
      canPop: !_sheetOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _sheetOpen) setState(() => _sheetOpen = false);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        // No bottomNavigationBar: the sheet replaced it, and the map gets the
        // whole screen back.
        body: Stack(
          children: [
            // Bottom layer, always present and never rebuilt when the sheet
            // opens — the map keeps its camera, its pins and its GPS stream
            // while the tourist is off in another tab.
            const Positioned.fill(
                child: SafeArea(bottom: false, child: MapPanel())),

            // The sheet, translated fully off the bottom when closed rather
            // than removed, so the slide has something to animate and the tab
            // screens are not torn down and rebuilt on every open.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                offset: _sheetOpen ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: WpTabSheet(
                  tabs: _tabs,
                  currentIndex: _tabIndex,
                  onTabSelected: (index) => setState(() => _tabIndex = index),
                ),
              ),
            ),

            // Above both, so the same control is on top of the map when closed
            // and on top of the sheet when open — that is what makes the X land
            // in exactly the spot the menu button occupied.
            Positioned(
              left: 20,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: WpSheetToggleButton(
                  isOpen: _sheetOpen,
                  onPressed: _toggleSheet,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Account tab's body — the route to the profile and settings screens.
class _AccountMenu extends StatelessWidget {
  final VoidCallback onEditProfile;
  final VoidCallback onSettings;

  const _AccountMenu({required this.onEditProfile, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: WpMonoLabel('account'),
            ),
            WpModuleCard(
              title: 'Edit profile',
              subtitle: 'photo · name · metrics',
              onTap: onEditProfile,
            ),
            WpModuleCard(
              title: 'Settings',
              subtitle: 'account details · log out',
              onTap: onSettings,
            ),
          ],
        ),
      ),
    );
  }
}
