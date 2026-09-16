import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';

/// Controller for the home screen.
///
/// Holds the profile currently being displayed so the view can rebuild itself
/// after the user edits it.
class HomeController extends ChangeNotifier {
  HomeController(this._profile);

  UserProfile _profile;

  UserProfile get profile => _profile;

  void updateProfile(UserProfile profile) {
    _profile = profile;
    notifyListeners();
  }
}
