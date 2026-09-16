import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/validation_messages.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/nickname_service.dart';
import '../services/profile_store.dart';
import '../utils/validators.dart';

/// Controller for the edit-profile screen.
///
/// Seeds the form from the existing profile, handles avatar picking/uploading,
/// and writes the updated profile to local storage + Firestore.
class EditProfileController extends ChangeNotifier {
  /// [nicknames] is injectable so a test can drive the "name taken" path
  /// without a Firebase app.
  EditProfileController({required this.profile, NicknameService? nicknames})
      : _nicknames = nicknames ?? NicknameService() {
    nicknameCtrl = TextEditingController(text: profile.nickname);
    phoneCtrl = TextEditingController(text: profile.phoneNumber ?? '');
    heightCtrl = TextEditingController(text: profile.heightCm.toString());
    weightCtrl = TextEditingController(text: profile.weightKg.toString());
    _units = profile.units;
    nicknameCtrl.addListener(_onNicknameChanged);
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
  final NicknameService _nicknames;

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

  // ── Validation rules ──────────────────────────────────────────────────────
  // Same rules the sign-up form applies, so a profile that was valid at
  // registration can't be edited into an invalid one.

  String? validateNickname(String? v) =>
      Validators.nickname(v) ?? _takenNameError(v);

  /// The name this tourist already holds; checking it would report their own
  /// name as taken.
  String get _ownCurrentNickname => profile.nickname;

  // ── Live "is this name free?" check ───────────────────────────────────────
  //
  // TextFormField.validator is synchronous, so uniqueness cannot be answered
  // from inside it. Instead the answer lands here and notifyListeners() drives
  // a rebuild; the field re-validates because the form uses
  // AutovalidateMode.onUserInteraction and picks the error up.
  //
  // Deliberately NOT Form.validate() — that marks every field touched, which
  // would splash "Weight is required" across untouched fields the moment
  // somebody types a name that is taken.

  Timer? _nicknameDebounce;

  /// The exact string the server reported as taken, or null.
  ///
  /// Compared against the field's current text so the error disappears the
  /// moment the user starts changing it, rather than lingering until the next
  /// round trip returns.
  String? _takenName;

  static const Duration _nicknameCheckDelay = Duration(milliseconds: 400);

  void _onNicknameChanged() {
    _nicknameDebounce?.cancel();

    // Any edit invalidates a previous verdict.
    if (_takenName != null) {
      _takenName = null;
      _safeNotify();
    }

    _nicknameDebounce = Timer(_nicknameCheckDelay, _checkNicknameAvailable);
  }

  Future<void> _checkNicknameAvailable() async {
    final candidate = nicknameCtrl.text.trim();

    // No point spending a call on a name the synchronous rules already reject,
    // or on the name this tourist already holds.
    if (Validators.nickname(candidate) != null) return;
    if (candidate == _ownCurrentNickname) return;

    final available = await _nicknames.isAvailable(candidate);

    // The reply may be for a prefix the user has since typed past. Without this
    // a slow answer about "Ian" could flag a field that now reads "IanWong".
    if (_disposed || nicknameCtrl.text.trim() != candidate) return;

    if (!available) {
      _takenName = candidate;
      _safeNotify();
    }
  }

  /// Applied after the synchronous rules, so a too-short or profane name still
  /// reports its own problem first — that is the one the user can act on.
  String? _takenNameError(String? v) {
    final input = v?.trim() ?? '';
    if (_takenName != null && input == _takenName) {
      return ValidationMessages.nicknameTaken;
    }
    return null;
  }


  String? validatePhone(String? v) => Validators.phone(v);

  String? validateHeight(String? v) => Validators.heightCm(v);

  String? validateWeight(String? v) => Validators.weightKg(v);

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Keep image size small for fast cloud transfers. The dimension caps
      // matter as much as the quality: without them a 12MP phone photo still
      // arrives at 2-3MB, which storage.rules would reject and Cloud Vision
      // would be billed to read.
      imageQuality: 70,
      maxWidth: 1024,
      maxHeight: 1024,
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

      // 1. If a new image was chosen, upload and moderate it first.
      //
      // A rejection aborts the whole save. It used to fall through the
      // `uploaded != null` check and save the rest of the profile with the old
      // picture still attached, which reads as a successful save — so a tourist
      // whose photo was refused would never learn it had been.
      if (_selectedImage != null && user != null) {
        try {
          final uploaded = await _store.uploadProfileImage(
            _selectedImage!,
            user.uid,
          );
          if (uploaded == null) {
            _errorMessage = 'Could not upload that photo. Please try again.';
            return null;
          }
          photoUrl = uploaded;
        } on ProfileImageRejected catch (e) {
          _errorMessage = e.message;
          return null;
        }
      }

      // 2. Claim the display name before writing anything.
      //
      // Skipped when the name has not changed, so editing only a weight costs
      // no server call. Claiming first means a refused name leaves the profile
      // untouched rather than half-saved under a name somebody else holds.
      final nickname = nicknameCtrl.text.trim();
      if (nickname != profile.nickname) {
        try {
          await _nicknames.claim(nickname);
        } on NicknameException catch (e) {
          if (e.isTaken) {
            // Under the field, not in a SnackBar: it is a problem with what
            // they typed. Covers the tourist who started typing while the name
            // was still free and pressed Save after somebody else took it.
            _takenName = nickname;
            _safeNotify();
            return null;
          }
          _errorMessage = e.message;
          return null;
        }
      }

      // 3. Clone the profile with the modified fields.
      final updated = profile.copyWith(
        nickname: nickname,
        phoneNumber: phoneCtrl.text.trim(),
        weightKg: double.tryParse(weightCtrl.text.trim()) ?? profile.weightKg,
        heightCm: double.tryParse(heightCtrl.text.trim()) ?? profile.heightCm,
        units: _units,
        photoUrl: photoUrl,
      );

      // 4. Persist to local preferences and the Firestore cloud vault.
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
    _nicknameDebounce?.cancel();
    nicknameCtrl.removeListener(_onNicknameChanged);
    nicknameCtrl.dispose();
    phoneCtrl.dispose();
    heightCtrl.dispose();
    weightCtrl.dispose();
    super.dispose();
  }
}
