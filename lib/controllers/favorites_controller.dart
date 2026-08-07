import 'package:flutter/foundation.dart';

import 'package:walkpenang/models/place.dart';

/// Screen 04 — the saved-places list.
///
/// In-memory only. Swapping in shared_preferences or sqflite later means
/// changing this class alone; nothing in the UI reads storage directly.
class FavoritesController extends ChangeNotifier {
  final List<Place> _saved = <Place>[];
  final Map<String, DateTime> _savedAt = <String, DateTime>{};

  /// Newest first, matching the mockup's ordering.
  List<Place> get places => List<Place>.unmodifiable(_saved);

  int get count => _saved.length;

  bool isFavorite(Place place) => _savedAt.containsKey(place.id);

  DateTime? savedAt(Place place) => _savedAt[place.id];

  /// Returns true if the place ended up saved, false if it was removed —
  /// the caller uses this to pick the right toast message.
  bool toggle(Place place) {
    if (isFavorite(place)) {
      remove(place);
      return false;
    }
    add(place);
    return true;
  }

  void add(Place place) {
    if (isFavorite(place)) return;
    _saved.insert(0, place);
    _savedAt[place.id] = DateTime.now();
    notifyListeners();
  }

  void remove(Place place) {
    if (!isFavorite(place)) return;
    _saved.removeWhere((Place p) => p.id == place.id);
    _savedAt.remove(place.id);
    notifyListeners();
  }

  void clear() {
    if (_saved.isEmpty) return;
    _saved.clear();
    _savedAt.clear();
    notifyListeners();
  }
}
