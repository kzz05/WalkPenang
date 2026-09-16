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

/// Which slice of the journal the screen is showing.
///
/// Deliberately two values. A tourist is in Penang for a few days, so the only
/// question the list cannot already answer at a glance is "what did I walk
/// today?" — week/month/year filters would be furniture nobody uses.
enum JournalFilter { all, today }

class JournalController extends ChangeNotifier {
  JournalController({
    required this.userId,
    required JournalDao journalDao,
    DateTime Function()? now,
  })  : _journalDao = journalDao,
        _now = now ?? DateTime.now;

  /// The signed-in tourist. Empty when nobody is — the screen shows its
  /// signed-out state rather than an empty journal, because "you have walked
  /// nothing" and "we do not know who you are" are different messages.
  final String userId;

  final JournalDao _journalDao;

  /// The clock "today" is measured against. Injected by tests so the day
  /// boundary can be pinned without waiting for midnight, exactly as
  /// JournalEntryTile takes its `now`.
  final DateTime Function() _now;

  List<JournalEntryModel> _entries = const <JournalEntryModel>[];

  /// Every journey loaded, newest first — the DAO's order, untouched.
  List<JournalEntryModel> get entries => _entries;

  JournalFilter _filter = JournalFilter.all;
  JournalFilter get filter => _filter;

  /// The entries the list should render.
  ///
  /// Filtered here in memory rather than by a second Firestore query: the
  /// journal is already capped at 50 documents, so narrowing it costs nothing,
  /// switching filters shows no loading state, and — the real reason — a
  /// date-ranged query would need another composite index, whose absence
  /// fails at runtime rather than at build time.
  List<JournalEntryModel> get visibleEntries {
    if (_filter == JournalFilter.all) return _entries;

    final today = _now();
    return _entries
        .where((entry) => _isSameDay(entry.checkInTime, today))
        .toList(growable: false);
  }

  /// Switches the visible slice. Notifies only on an actual change, so a
  /// second tap on the selected pill does not rebuild the list.
  void setFilter(JournalFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
  }

  /// Device-local calendar day, not a 24-hour window: a journey finished at
  /// 23:50 last night is yesterday's even though it is ten minutes old, which
  /// is the same rule JournalEntryModel.relativeDate reads by. Check-ins are
  /// stamped with the device's own DateTime.now() and converted back to local
  /// time at the DAO edge, so local is the timezone they were recorded in.
  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Object? _error;
  Object? get error => _error;

  /// True once a load has finished with no journeys — distinct from "still
  /// loading" and from "the read failed", which must not look alike.
  ///
  /// Describes the whole journal, never the filtered slice. "You have walked
  /// nothing" and "you have walked nothing *today*" are different sentences,
  /// and the screen says them separately.
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
