import 'package:flutter/material.dart';

import '../controllers/settings_controller.dart';
import '../models/user_profile.dart';
import 'onboarding_view.dart';

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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
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
    final hasPhoto = profile.photoUrl != null && profile.photoUrl!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          // 📷 PROFILE AVATAR
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.teal.shade100,
              backgroundImage:
                  hasPhoto ? NetworkImage(profile.photoUrl!) : null,
              child: hasPhoto
                  ? null
                  : const Icon(Icons.person, size: 50, color: Colors.teal),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              profile.nickname,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(
              profile.email ?? '',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(),
          // 📞 CONTACT DETAILS
          ListTile(
            leading: const Icon(Icons.phone, color: Colors.teal),
            title: const Text('Contact Number'),
            subtitle: Text(profile.phoneNumber ?? 'Not provided'),
          ),
          ListTile(
            leading: const Icon(Icons.height, color: Colors.teal),
            title: const Text('Height'),
            subtitle: Text('${profile.heightCm} cm'),
          ),
          ListTile(
            leading: const Icon(Icons.monitor_weight, color: Colors.teal),
            title: const Text('Weight'),
            subtitle: Text('${profile.weightKg} kg'),
          ),
          ListTile(
            leading: const Icon(Icons.calculate, color: Colors.teal),
            title: const Text('Body Mass Index (BMI)'),
            subtitle: Text(
              '${profile.bmi.toStringAsFixed(1)} (${profile.bmiCategory})',
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Log out',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            subtitle: const Text('Safely ends your active session'),
            onTap: _confirmLogout,
          ),
        ],
      ),
    );
  }
}
