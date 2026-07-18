import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_store.dart';
import '../services/auth_service.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatelessWidget {
  final UserProfile profile;
  SettingsScreen({super.key, required this.profile});

  final _store = ProfileStore();
  final _auth = AuthService();

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out of WalkPenang?'),
        content: const Text(
            'Are you sure you want to log out? '
                'Your profile data is safely secured in the cloud and will restore when you log back in.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out')),
        ],
      ),
    );
    if (ok != true) return;

    await _store.clear();
    await _auth.signOut();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          // 📷 DISPLAY PROFILE AVATAR
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.teal.shade100,
              backgroundImage: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                  ? NetworkImage(profile.photoUrl!)
                  : null,
              child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                  ? const Icon(Icons.person, size: 50, color: Colors.teal)
                  : null,
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
          // 📞 DISPLAY CONTACT DETAILS
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
            subtitle: Text('${profile.bmi.toStringAsFixed(1)} (${profile.bmiCategory})'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log out', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            subtitle: const Text('Safely ends your active session'),
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }
}