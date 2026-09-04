// ---------------------------------------------------------------------------
// journal_controller.dart
// Module 5 — Reward & Achievement
// Use Case : UC520 View walking journal
// FR       : FR-R03 Walking Journal
// ---------------------------------------------------------------------------
//
// Drives WalkingJournalScreen. Holds no Firestore types — the DAO is injected
// as its abstraction, so the tests drive it with an in-memory tourist and no
// Firebase project, exactly as the statistics dashboard's controller does.

import 'package:flutter/foundation.dart';

import '../dao/journal_dao.dart';
import '../models/journal_entry_model.dart';

class JournalController extends ChangeNotifier {
  JournalController({
    required this.userId,
    required JournalDao journalDao,
  }) : _journalDao = journalDao;

  /// The signed-in tourist. Empty when nobody is — the screen shows its
  /// signed-out state rather than an empty journal, because "you have walked
  /// nothing" and "we do not know who you are" are different messages.
  final String userId;

  final JournalDao _journalDao;

  List<JournalEntryModel> _entries = const <JournalEntryModel>[];
  List<JournalEntryModel> get entries => _entries;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Object? _error;
  Object? get error => _error;

  /// True once a load has finished with no journeys — distinct from "still
  /// loading" and from "the read failed", which must not look alike.
  bool get isEmpty => !_isLoading && _error == null && _entries.isEmpty;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _entries = await _journalDao.fetchEntries(userId);
    } catch (error) {
      // Surfaced rather than swallowed. An empty list here would tell the
      // tourist they have walked nowhere, which is a lie the screen has no way
      // to walk back — and the likeliest cause is a missing Firestore index,
      // which needs fixing rather than hiding.
      _error = error;
      _entries = const <JournalEntryModel>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
