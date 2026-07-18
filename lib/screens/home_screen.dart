import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserProfile profile;
  const HomeScreen({super.key, required this.profile});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late UserProfile _profile = widget.profile;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:  Image.asset(
          'assets/images/walkpenanglogonew.PNG',
          width: 100,
          height: 100,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SettingsScreen(profile: _profile)),
              );
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  radius: 28, // Adjust the size to match your current layout perfectly
                  backgroundColor: Colors.teal[100],
                  // 1. Check if the cloud database contains a profile photo URL
                  backgroundImage: _profile.photoUrl != null && _profile.photoUrl!.isNotEmpty
                      ? NetworkImage(_profile.photoUrl!)
                      : null,
                  // 2. Fall back to the generic teal icon ONLY if no picture exists
                  child: _profile.photoUrl == null || _profile.photoUrl!.isEmpty
                      ? const Icon(Icons.person, size: 28, color: Colors.teal)
                      : null,
                ),
                title: Text('Hi, ${_profile.nickname}'),
                subtitle: Text(
                    'Weight: ${_profile.weightKg} kg  •  Height: ${_profile.heightCm} cm\n'
                        'BMI: ${_profile.bmi.toStringAsFixed(1)} (${_profile.bmiCategory})  •  Points: ${_profile.points}'),
                isThreeLine: true,
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final updated = await Navigator.of(context).push<UserProfile>(
                    MaterialPageRoute(
                        builder: (_) => EditProfileScreen(profile: _profile)),
                  );
                  if (updated != null) setState(() => _profile = updated);
                },
              ),
            ),
            const SizedBox(height: 20),
            const Text('Modules',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // Placeholders your teammates replace with real screens.
            _moduleButton(Icons.map, 'Map & GPS', 'Tang Yue Hann'),
            _moduleButton(Icons.restaurant, 'Food & Attractions', 'Ong Song Wei'),
            _moduleButton(Icons.directions_walk, 'Walking & Carbon', 'Poon Wei Seng'),
            _moduleButton(Icons.emoji_events, 'Rewards', 'Tang Khuan Zhi'),
          ],
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