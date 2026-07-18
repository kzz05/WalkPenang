import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_profile.dart';
import '../services/profile_store.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _nicknameCtrl;
  late TextEditingController _phoneCtrl; // 👈 NEW
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;

  final _store = ProfileStore();

  File? _selectedImage; // Holds the new locally picked image file
  bool _busy = false;
  late String _units;

  @override
  void initState() {
    super.initState();
    // Pre-populate fields with existing data
    _nicknameCtrl = TextEditingController(text: widget.profile.nickname);
    _phoneCtrl = TextEditingController(text: widget.profile.phoneNumber ?? '');
    _heightCtrl = TextEditingController(text: widget.profile.heightCm.toString());
    _weightCtrl = TextEditingController(text: widget.profile.weightKg.toString());
    _units = widget.profile.units;
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _phoneCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  // Gallery Image Picker Logic
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Keep image size small for fast cloud transfers
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // Save changes handler
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);

    try {
      String? photoUrl = widget.profile.photoUrl;
      final user = FirebaseAuth.instance.currentUser;

      // 1. If a new image was chosen, upload it to Firebase Storage first
      if (_selectedImage != null && user != null) {
        final uploadedUrl = await _store.uploadProfileImage(_selectedImage!, user.uid);
        if (uploadedUrl != null) {
          photoUrl = uploadedUrl;
        }
      }

      // 2. Clone the profile with the modified parameters using copyWith
      final updated = widget.profile.copyWith(
        nickname: _nicknameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(), // 👈 SAVE PHONE NUMBER
        weightKg: double.tryParse(_weightCtrl.text.trim()) ?? widget.profile.weightKg,
        heightCm: double.tryParse(_heightCtrl.text.trim()) ?? widget.profile.heightCm,
        units: _units,
        photoUrl: photoUrl, // 👈 SAVE NEW PHOTO URL
      );

      // 3. Persist modifications down to local preferences and Firestore cloud vault
      await _store.save(updated);

      if (!mounted) return;

      // 4. Return back to Settings Screen and pass the updated profile back to update the UI
      Navigator.pop(context, updated);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Determine the image provider cleanly up here
    ImageProvider? avatarImage;

    if (_selectedImage != null) {
      avatarImage = FileImage(_selectedImage!);
    } else if (widget.profile.photoUrl != null && widget.profile.photoUrl!.isNotEmpty) {
      avatarImage = NetworkImage(widget.profile.photoUrl!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (!_busy)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
            ),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 📷 EDITABLE AVATAR STACK
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.teal.shade100,
                      backgroundImage: avatarImage, // 👈 Simply pass the variable here!
                      child: avatarImage == null
                          ? const Icon(Icons.person, size: 55, color: Colors.teal)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: Colors.teal,
                        radius: 18,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Nickname Input
              TextFormField(
                controller: _nicknameCtrl,
                decoration: const InputDecoration(labelText: 'Nickname', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name cannot be empty' : null,
              ),
              const SizedBox(height: 16),

              // 📞 CONTACT NUMBER INPUT
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Contact Number', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Contact number cannot be empty' : null,
              ),
              const SizedBox(height: 16),

              // Metrics Split Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _heightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Height (cm)', border: OutlineInputBorder()),
                      validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid height' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
                      validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid weight' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Units Dropdown Selector
              DropdownButtonFormField<String>(
                value: _units,
                decoration: const InputDecoration(labelText: 'System Units', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'metric', child: Text('Metric (kg, cm)')),
                  DropdownMenuItem(value: 'imperial', child: Text('Imperial (lb, in)')),
                ],
                onChanged: (v) => setState(() => _units = v ?? 'metric'),
              ),
              const SizedBox(height: 30),

              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}