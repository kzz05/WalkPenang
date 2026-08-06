import 'package:flutter/material.dart';

import '../controllers/home_controller.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'edit_profile_view.dart';
import 'map_view.dart';
import 'settings_view.dart';
import 'widgets/wp_components.dart';

/// Screen 06 · Home — brand bar, profile hero, stat tiles, module list.
class HomeView extends StatefulWidget {
  final UserProfile profile;

  const HomeView({super.key, required this.profile});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeController _controller = HomeController(widget.profile);

  /// The four modules, in the order the bottom bar lists them.
  static const _modules = [
    (
    title: 'Map & GPS',
    subtitle: 'live map · nearby pins',
    owner: 'Tang Yue Hann',
    ),
    (
    title: 'Food & Attractions',
    subtitle: 'search · bookmarks',
    owner: 'Ong Song Wei',
    ),
    (
    title: 'Walking & Carbon',
    subtitle: 'track · carbon saved',
    owner: 'Poon Wei Seng',
    ),
    (
    title: 'Rewards',
    subtitle: 'points · badges',
    owner: 'Tang Khuan Zhi',
    ),
  ];

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

  void _announcePending(String label, String owner) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label module — to be built ($owner)')),
    );
  }

  /// Map & GPS is the only module built so far — everything else still
  /// shows the placeholder snackbar until its owner builds it.
  void _openModule(String title, String owner) {
    if (title == 'Map & GPS') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MapView()),
      );
      return;
    }
    _announcePending(title, owner);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  final profile = _controller.profile;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      _buildBrandBar(),
                      const SizedBox(height: 24),
                      _ProfileHero(
                        profile: profile,
                        onTap: _openEditProfile,
                      ),
                      const SizedBox(height: 20),
                      _buildStatRow(profile),
                      const SizedBox(height: 28),
                      const WpMonoLabel('modules'),
                      const SizedBox(height: 12),
                      for (final module in _modules)
                        WpModuleCard(
                          title: module.title,
                          subtitle: module.subtitle,
                          onTap: () => _openModule(module.title, module.owner),
                        ),
                    ],
                  );
                },
              ),
            ),
            WpBottomNav(
              currentIndex: 0,
              items: const ['home', 'map', 'walk', 'rewards'],
              onTap: (index) {
                if (index == 0) return;
                // The bar mirrors the module list minus Food & Attractions.
                final module = switch (index) {
                  1 => _modules[0],
                  2 => _modules[2],
                  _ => _modules[3],
                };
                _openModule(module.title, module.owner);
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

  Widget _buildStatRow(UserProfile profile) {
    // IntrinsicHeight keeps the three tiles the same height. A plain
    // `stretch` can't be used here — inside a ListView the Row's height is
    // unbounded, and stretching against infinity throws during layout.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: WpStatTile(
              label: 'distance',
              value: profile.distanceKm.toStringAsFixed(1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: WpStatTile(
              label: 'co2 saved',
              value: profile.co2SavedKg.toStringAsFixed(1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: WpStatTile(
              label: 'points',
              value: '${profile.points}',
            ),
          ),
        ],
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

/// The black pill greeting card at the top of the home screen.
class _ProfileHero extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onTap;

  const _ProfileHero({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final photoUrl = profile.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              WpAvatar(
                radius: 36,
                image: hasPhoto ? NetworkImage(photoUrl) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const WpMonoLabel('signed in', color: AppColors.primary),
                    const SizedBox(height: 4),
                    Text(
                      'Hi, ${profile.nickname}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.display.copyWith(
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Shrinks rather than wrapping, so a long nickname or a
                    // 4-digit points total can't make the card two lines tall.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: WpMonoLabel(
                        'bmi ${profile.bmi.toStringAsFixed(1)} · '
                            '${profile.bmiCategory} · ${profile.points} pts',
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // ✏️ Makes it obvious the whole card opens Edit Profile.
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: const Icon(
                  Icons.edit,
                  size: 16,
                  color: AppColors.onPrimary,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
