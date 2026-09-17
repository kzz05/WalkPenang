import 'package:flutter/material.dart';

import '../controllers/edit_profile_controller.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'widgets/body_metrics_fields.dart';
import 'widgets/wp_components.dart';

/// Screen 07 · Edit Profile.
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

        if (_controller.busy) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        return WpScreen(
          children: [
            WpBackBar(
              onBack: () => Navigator.of(context).pop(),
              actionLabel: 'save',
              onAction: _save,
            ),
            const SizedBox(height: 8),
            Text('Edit profile', style: AppType.display),
            const SizedBox(height: 28),
            Center(
              child: WpAvatar(
                radius: 55,
                image: avatarImage,
                onEdit: _controller.pickImage,
              ),
            ),
            const SizedBox(height: 28),
            Form(
              key: _controller.formKey,
              // Errors appear as soon as the user has touched a field, rather
              // than waiting for the save tap.
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  WpField(
                    label: 'nickname',
                    controller: _controller.nicknameCtrl,
                    validator: _controller.validateNickname,
                  ),
                  const SizedBox(height: 20),
                  WpCountryPhoneField(
                    label: 'contact number',
                    controller: _controller.phoneCtrl,
                    country: _controller.phoneCountry,
                    onCountryChanged: _controller.setPhoneCountry,
                    validator: _controller.validatePhone,
                  ),
                  const SizedBox(height: 20),
                  BodyMetricsFields(fields: _controller),
                ],
              ),
            ),
            const SizedBox(height: 32),
            WpPrimaryButton(label: 'save changes', onPressed: _save),
          ],
        );
      },
    );
  }
}
