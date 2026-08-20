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

/// Screen 06 · Home — brand bar over a full-height map, with the explore,
/// walk and rewards modules reached from the bottom nav and the account
/// screens from the hamburger. The map is embedded rather than pushed so it
/// is the first thing a tourist sees after signing in.
class HomeView extends StatefulWidget {
  final UserProfile profile;

  const HomeView({super.key, required this.profile});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeController _controller = HomeController(widget.profile);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The hamburger opens this — the dashboard's route to the account screens.
  Future<void> _openAccountMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AccountMenu(
        onEditProfile: () {
          Navigator.pop(sheetContext);
          _openEditProfile();
        },
        onSettings: () {
          Navigator.pop(sheetContext);
          _openSettings();
        },
      ),
    );
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

  /// US-FD01 / US-FD02 — the Food & Attraction Discovery module. Pushed rather
  /// than embedded: it brings its own Discover / Favorites tabs, which would
  /// otherwise sit under this screen's nav and give the tourist two nav bars.
  Future<void> _openDiscoveryModule() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DiscoveryModuleView(),
      ),
    );
  }

  /// The walk tab opens the tourist's journey history (UC520 / FR-R03).
  ///
  /// It used to open UC-W01's transport-mode picker. That became redundant
  /// once the map's route summary grew its own Walk/Drive/Bus tabs and
  /// journeys started from a tapped place — the picker had no destination to
  /// offer and could only send the tourist back to the map.
  Future<void> _openWalkingModule() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WalkingJournalScreen()),
    );
  }

  Future<void> _openRewardModule() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const StatsDashboardScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // In the Scaffold's own nav slot, like the Discovery module's shell —
      // so the bar handles its own safe-area inset and the map gets the rest.
      // Home *is* the map: it now runs edge to edge under the status bar
      // rather than starting below a brand bar, so nothing competes with it
      // for vertical space. The account button rides in the map's own top
      // overlay row, level with the radius chips.
      body: SafeArea(
        bottom: false,
        child: MapPanel(topBarTrailing: _buildAccountButton()),
      ),
      bottomNavigationBar: WpBottomNav(
        currentIndex: 0,
        items: const ['home', 'explore', 'walk', 'rewards'],
        onTap: (index) {
          switch (index) {
            case 1:
              _openDiscoveryModule();
            case 2:
              _openWalkingModule();
            case 3:
              _openRewardModule();
          }
        },
      ),
    );
  }

  /// The account menu button, sitting over the map alongside the radius
  /// chips.
  ///
  /// No fill and no outline: it is drawn straight onto the map, so any
  /// background would reinstate the bar this replaced. The icon stays dark
  /// ink, which is what carries it against the map's light ground — over
  /// satellite imagery or a dark style it would need a scrim.
  Widget _buildAccountButton() {
    return InkWell(
      onTap: _openAccountMenu,
      customBorder: const CircleBorder(),
      child: const SizedBox(
        width: 40,
        height: 40,
        child: Icon(Icons.menu, size: 22, color: AppColors.onPrimary),
      ),
    );
  }
}

/// The sheet behind the hamburger — the dashboard's account section.
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
