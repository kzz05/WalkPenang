import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_store.dart';

/// Controller for the edit-profile screen.
///
/// Seeds the form from the existing profile, handles avatar picking/uploading,
/// and writes the updated profile to local storage + Firestore.
class EditProfileController extends ChangeNotifier {
  EditProfileController({required this.profile}) {
    nicknameCtrl = TextEditingController(text: profile.nickname);
    phoneCtrl = TextEditingController(text: profile.phoneNumber ?? '');
    heightCtrl = TextEditingController(text: profile.heightCm.toString());
    weightCtrl = TextEditingController(text: profile.weightKg.toString());
    _units = profile.units;
  }

  /// The profile as it was when the screen opened.
  final UserProfile profile;

  final formKey = GlobalKey<FormState>();

  late final TextEditingController nicknameCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController heightCtrl;
  late final TextEditingController weightCtrl;

  final ProfileStore _store = ProfileStore();
  final AuthService _auth = AuthService();

  File? _selectedImage;
  bool _busy = false;
  late String _units;
  String? _errorMessage;
  bool _disposed = false;

  File? get selectedImage => _selectedImage;
  bool get busy => _busy;
  String get units => _units;

  /// Set when [save] fails; null when it was only a validation miss.
  String? get errorMessage => _errorMessage;

  void setUnits(String? value) {
    _units = value ?? 'metric';
    _safeNotify();
  }

  String? validateRequired(String? v, String message) =>
      (v == null || v.trim().isEmpty) ? message : null;

  String? validateMeasurement(String? v, String message) =>
      (double.tryParse(v ?? '') ?? 0) <= 0 ? message : null;

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Keep image size small for fast cloud transfers.
      imageQuality: 70,
    );
    if (picked == null) return;
    _selectedImage = File(picked.path);
    _safeNotify();
  }

  /// Returns the saved profile, or null if validation failed or the write
  /// blew up (check [errorMessage] to tell the two apart).
  Future<UserProfile?> save() async {
    _errorMessage = null;
    if (!formKey.currentState!.validate()) return null;

    _setBusy(true);
    try {
      var photoUrl = profile.photoUrl;
      final user = _auth.currentUser;

      // 1. If a new image was chosen, upload it to Firebase Storage first.
      if (_selectedImage != null && user != null) {
        final uploaded = await _store.uploadProfileImage(
          _selectedImage!,
          user.uid,
        );
        if (uploaded != null) photoUrl = uploaded;
      }

      // 2. Clone the profile with the modified fields.
      final updated = profile.copyWith(
        nickname: nicknameCtrl.text.trim(),
        phoneNumber: phoneCtrl.text.trim(),
        weightKg: double.tryParse(weightCtrl.text.trim()) ?? profile.weightKg,
        heightCm: double.tryParse(heightCtrl.text.trim()) ?? profile.heightCm,
        units: _units,
        photoUrl: photoUrl,
      );

      // 3. Persist to local preferences and the Firestore cloud vault.
      await _store.save(updated);
      return updated;
    } catch (e) {
      _errorMessage = 'Failed to update profile: $e';
      return null;
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    _busy = value;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    nicknameCtrl.dispose();
    phoneCtrl.dispose();
    heightCtrl.dispose();
    weightCtrl.dispose();
    super.dispose();
  }
}
