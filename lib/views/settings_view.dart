import 'package:flutter/material.dart';

import '../controllers/settings_controller.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'onboarding_view.dart';
import 'widgets/wp_components.dart';

/// Screen 08 · Settings — a read-only profile summary plus the log-out action.
class SettingsView extends StatefulWidget {
  final UserProfile profile;

  const SettingsView({super.key, required this.profile});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final SettingsController _controller =
  SettingsController(profile: widget.profile);

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out of WalkPenang?'),
        content: const Text(
          'Are you sure you want to log out? '
              'Your profile data is safely secured in the cloud and will restore when you log back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppType.button),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.mdAll,
              ),
            ),
            child: Text('Log out', style: AppType.button),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _controller.logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingView()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _controller.profile;
    final photoUrl = profile.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return WpScreen(
      children: [
        WpBackBar(onBack: () => Navigator.of(context).pop()),
        const SizedBox(height: 8),
        Text('Settings', style: AppType.display),
        const SizedBox(height: 28),
        Center(
          child: WpAvatar(
            radius: 50,
            image: hasPhoto ? NetworkImage(photoUrl) : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          profile.nickname,
          textAlign: TextAlign.center,
          style: AppType.display.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 6),
        WpMonoLabel(profile.email ?? '', size: 12, align: TextAlign.center),
        const SizedBox(height: 24),
        const Divider(height: 1, thickness: 1, color: AppColors.outline),
        WpDetailRow(
          label: 'contact number',
          value: profile.phoneNumber?.isNotEmpty == true
              ? profile.phoneNumber!
              : 'Not provided',
        ),
        WpDetailRow(label: 'height', value: '${profile.heightCm} cm'),
        WpDetailRow(label: 'weight', value: '${profile.weightKg} kg'),
        WpDetailRow(
          label: 'body mass index',
          value: '${profile.bmi.toStringAsFixed(1)} · ${profile.bmiCategory}',
        ),
        const SizedBox(height: 32),
        WpOutlineButton(label: 'log out', onPressed: _confirmLogout),
        const SizedBox(height: 20),
        const WpMonoLabel(
          'profile stays safely in the cloud',
          align: TextAlign.center,
        ),
      ],
    );
  }
}
