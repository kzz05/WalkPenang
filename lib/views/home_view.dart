import 'package:flutter/material.dart';

import '../controllers/home_controller.dart';
import '../models/user_profile.dart';
import 'edit_profile_view.dart';
import 'settings_view.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/walkpenanglogonew.PNG',
          width: 100,
          height: 100,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final profile = _controller.profile;
            final hasPhoto =
                profile.photoUrl != null && profile.photoUrl!.isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.teal[100],
                      // 1. Use the cloud profile photo when there is one.
                      backgroundImage:
                          hasPhoto ? NetworkImage(profile.photoUrl!) : null,
                      // 2. Fall back to the generic teal icon otherwise.
                      child: hasPhoto
                          ? null
                          : const Icon(Icons.person,
                              size: 28, color: Colors.teal),
                    ),
                    title: Text('Hi, ${profile.nickname}'),
                    subtitle: Text(
                      'Weight: ${profile.weightKg} kg  •  Height: ${profile.heightCm} cm\n'
                      'BMI: ${profile.bmi.toStringAsFixed(1)} (${profile.bmiCategory})  •  Points: ${profile.points}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.edit),
                    onTap: _openEditProfile,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Modules',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                // Placeholders your teammates replace with real screens.
                _moduleButton(Icons.map, 'Map & GPS', 'Tang Yue Hann'),
                _moduleButton(
                    Icons.restaurant, 'Food & Attractions', 'Ong Song Wei'),
                _moduleButton(Icons.directions_walk, 'Walking & Carbon',
                    'Poon Wei Seng'),
                _moduleButton(Icons.emoji_events, 'Rewards', 'Tang Khuan Zhi'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _moduleButton(IconData icon, String label, String owner) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton.icon(
        icon: Icon(icon),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text('$label  (todo: $owner)'),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label module — to be built')),
          );
        },
      ),
    );
  }
}
