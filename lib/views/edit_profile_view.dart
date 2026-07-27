import 'package:flutter/material.dart';

import '../controllers/edit_profile_controller.dart';
import '../models/user_profile.dart';

class EditProfileView extends StatefulWidget {
  final UserProfile profile;

  const EditProfileView({super.key, required this.profile});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  late final EditProfileController _controller =
      EditProfileController(profile: widget.profile);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Grab these before awaiting so they survive the pop below.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final updated = await _controller.save();
    if (!mounted) return;

    if (updated == null) {
      final error = _controller.errorMessage;
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Profile updated successfully!')),
    );
    // Hand the updated profile back so HomeView can refresh.
    navigator.pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        // Work out which avatar image to show, in priority order.
        final selectedImage = _controller.selectedImage;
        final photoUrl = widget.profile.photoUrl;

        ImageProvider? avatarImage;
        if (selectedImage != null) {
          avatarImage = FileImage(selectedImage);
        } else if (photoUrl != null && photoUrl.isNotEmpty) {
          avatarImage = NetworkImage(photoUrl);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit Profile'),
            actions: [
              if (!_controller.busy)
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _save,
                ),
            ],
          ),
          body: _controller.busy
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _controller.formKey,
                    child: ListView(
                      children: [
                        // 📷 EDITABLE AVATAR STACK
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 55,
                                backgroundColor: Colors.teal.shade100,
                                backgroundImage: avatarImage,
                                child: avatarImage == null
                                    ? const Icon(Icons.person,
                                        size: 55, color: Colors.teal)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  backgroundColor: Colors.teal,
                                  radius: 18,
                                  child: IconButton(
                                    icon: const Icon(Icons.camera_alt,
                                        size: 16, color: Colors.white),
                                    onPressed: _controller.pickImage,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Nickname Input
                        TextFormField(
                          controller: _controller.nicknameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nickname',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => _controller.validateRequired(
                              v, 'Name cannot be empty'),
                        ),
                        const SizedBox(height: 16),

                        // 📞 CONTACT NUMBER INPUT
                        TextFormField(
                          controller: _controller.phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Contact Number',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => _controller.validateRequired(
                              v, 'Contact number cannot be empty'),
                        ),
                        const SizedBox(height: 16),

                        // Metrics Split Row
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _controller.heightCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Height (cm)',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => _controller
                                    .validateMeasurement(v, 'Invalid height'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _controller.weightCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Weight (kg)',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => _controller
                                    .validateMeasurement(v, 'Invalid weight'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Units Dropdown Selector
                        DropdownButtonFormField<String>(
                          value: _controller.units,
                          decoration: const InputDecoration(
                            labelText: 'System Units',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'metric', child: Text('Metric (kg, cm)')),
                            DropdownMenuItem(
                                value: 'imperial',
                                child: Text('Imperial (lb, in)')),
                          ],
                          onChanged: _controller.setUnits,
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
      },
    );
  }
}
