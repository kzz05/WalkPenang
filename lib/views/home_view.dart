import 'package:flutter/material.dart';

import '../controllers/home_controller.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'edit_profile_view.dart';
import 'map_view.dart';
import 'reward/stats_dashboard_screen.dart';
import 'settings_view.dart';
import 'walking_view.dart';
import 'widgets/wp_components.dart';

/// Screen 06 · Home — brand bar over a full-height map, with the walk and
/// rewards modules reached from the bottom nav and the account screens from
/// the hamburger. The map is embedded rather than pushed so it is the first
/// thing a tourist sees after signing in.
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

  Future<void> _openWalkingModule() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WalkingView(profile: _controller.profile),
      ),
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
      body: SafeArea(
        child: Column(
          children: [
            // The brand bar sits above the map rather than floating over it,
            // so the hamburger never competes with the map's pan gestures.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: _buildBrandBar(),
            ),
            // Home *is* the map — it fills whatever is left between the brand
            // bar and the nav, so it is the first thing shown after sign-in.
            const Expanded(child: MapPanel()),
            WpBottomNav(
              currentIndex: 0,
              items: const ['home', 'walk', 'rewards'],
              onTap: (index) {
                switch (index) {
                  case 1:
                    _openWalkingModule();
                  case 2:
                    _openRewardModule();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Logo on the left, a circular menu button on the right.
  Widget _buildBrandBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Image.asset(
          'assets/images/walkpenanglogonobg.png',
          height: 64,
          fit: BoxFit.contain,
        ),
        InkWell(
          onTap: _openAccountMenu,
          customBorder: const CircleBorder(),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.onPrimary, width: 1.6),
            ),
            child: const Icon(Icons.menu, size: 20, color: AppColors.onPrimary),
          ),
        ),
      ],
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
