// ---------------------------------------------------------------------------
// leaderboard_controller.dart
// Module 5 — Reward & Achievement
// Use Case : UC540 Compare standing against other tourists
// FR       : FR-R06 Leaderboard
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// Drives LeaderboardScreen: publishes the signed-in tourist's own standing,
// reads the top of the board, and ranks it.
//
// Holds no Firestore types — both DAOs are injected as their abstractions, so
// the screen's demo mode swaps in an in-memory board exactly as the statistics
// dashboard and the walking journal do.

import 'package:flutter/foundation.dart';

import '../dao/leaderboard_dao.dart';
import '../dao/reward_dao.dart';
import '../models/leaderboard_entry_model.dart';
import '../utils/reward_constants.dart';

class LeaderboardController extends ChangeNotifier {
  LeaderboardController({
    required this.userId,
    required LeaderboardDao leaderboardDao,
    RewardDao? rewardDao,
    this.limit = RewardConstants.leaderboardPageSize,
    this.isDemo = false,
  })  : _leaderboardDao = leaderboardDao,
        _rewardDao = rewardDao;

  /// The signed-in tourist, so their own row can be highlighted. Empty when
  /// nobody is signed in — the board still renders, it just has nobody to
  /// point at, and the screen says so.
  final String userId;

  /// True when backed by the in-memory demo board rather than Firestore.
  final bool isDemo;

  /// How many rows to fetch.
  final int limit;

  final LeaderboardDao _leaderboardDao;

  /// Optional. When supplied, [load] republishes the tourist's own row from
  /// their cumulative totals before reading the board — see [_publishSelf].
  final RewardDao? _rewardDao;

  // --- State the view renders ----------------------------------------------

  List<RankedEntry> _entries = const <RankedEntry>[];

  /// The board, best first. Empty until [load] completes.
  List<RankedEntry> get entries => _entries;

  RankedEntry? _currentUserEntry;

  /// The signed-in tourist's own row, whether or not it is on [entries].
  ///
  /// Null when they have never been awarded points, or when nobody is signed
  /// in. When its rank is beyond [limit] the screen pins it under the board
  /// instead of leaving the tourist unable to find themselves.
  RankedEntry? get currentUserEntry => _currentUserEntry;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Object? _error;

  /// Non-null when the last load failed. The screen shows a retry rather than
  /// an empty board, because "nobody has scored" and "the read failed" look
  /// identical otherwise and must not.
  Object? get error => _error;

  /// True once a load has finished with nobody on the board — distinct from
  /// still loading and from a failed read.
  bool get isEmpty => !_isLoading && _error == null && _entries.isEmpty;

  /// The tourist currently holding the highest points total, which is the
  /// question the screen exists to answer. Null on an empty board.
  RankedEntry? get leader => _entries.isEmpty ? null : _entries.first;

  /// The top three, in order. Fewer than three rows returns however many
  /// there are, so a board with two tourists on it renders two.
  List<RankedEntry> get podium =>
      _entries.take(3).toList(growable: false);

  /// Everyone below the podium.
  List<RankedEntry> get chasingPack =>
      _entries.length <= 3 ? const <RankedEntry>[] : _entries.sublist(3);

  /// True when the tourist's own row exists but did not make the fetched
  /// page, so the screen knows to pin it separately rather than twice.
  bool get isCurrentUserOffBoard {
    final own = _currentUserEntry;
    if (own == null) return false;
    return !_entries.any((ranked) => ranked.entry.userId == own.entry.userId);
  }

  /// How many points separate the signed-in tourist from the tourist directly
  /// above them, or null when they lead, are absent, or are off the page.
  ///
  /// This is the number that does the motivating — "you are 4th" says less
  /// than "18 points off 3rd" — so it is computed here rather than left to
  /// the view to work out from two rows.
  int? get pointsToNextRank {
    final own = _currentUserEntry;
    if (own == null || own.isLeader) return null;

    final index =
        _entries.indexWhere((ranked) => ranked.entry.userId == own.entry.userId);
    // Off the fetched page: the tourist above them was never read, so there
    // is no honest gap to quote.
    if (index <= 0) return null;

    // Walk up past anyone tied with this tourist — the gap that matters is to
    // the next tourist actually ahead, not to somebody level with them.
    for (var i = index - 1; i >= 0; i--) {
      final gap = _entries[i].entry.totalPoints - own.entry.totalPoints;
      if (gap > 0) return gap;
    }
    return null;
  }

  // --- Loading -------------------------------------------------------------

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Publishing first, so a tourist who opens the board sees the points they
    // have actually earned rather than whatever their row last said.
    await _publishSelf();

    try {
      final board = await _leaderboardDao.fetchTopEntries(limit: limit);
      _entries = LeaderboardRanking.rank(board);
      _currentUserEntry = await _resolveCurrentUser();
    } catch (error) {
      // Surfaced rather than swallowed. An empty board here would tell the
      // tourist that nobody in Penang has walked anywhere, and the likeliest
      // cause is a security rule denying the read — which needs fixing, not
      // hiding behind an empty state.
      _error = error;
      _entries = const <RankedEntry>[];
      _currentUserEntry = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mirrors the tourist's current totals into their public row.
  ///
  /// Two things depend on this. A tourist who earned points before the
  /// leaderboard existed has no row at all, and opening the screen enrols
  /// them — no backfill script, and no board that is missing half the group.
  /// And a tourist who has since renamed themselves gets the new name onto
  /// the board, which a mirror written only at award time could not do.
  ///
  /// Failure is absorbed. Publishing is a courtesy write on a derived
  /// collection; if it is denied or the network drops, the board should still
  /// render for everyone else on it.
  Future<void> _publishSelf() async {
    final rewardDao = _rewardDao;
    if (rewardDao == null || userId.isEmpty) return;

    try {
      final stats = await rewardDao.fetchRewardSummary(userId);
      await _leaderboardDao.publishEntry(userId: userId, stats: stats);
    } catch (error) {
      debugPrint('Leaderboard: could not publish own standing — $error');
    }
  }

  /// The tourist's own ranked row.
  ///
  /// Taken from the fetched page when they are on it, so the rank shown
  /// beside their name is the same one the board shows. Only when they are
  /// not does this fall back to a separate read of their row, ranked as
  /// [limit] + 1 — an honest "below the board" position rather than a
  /// precise rank the client cannot know without counting every tourist
  /// ahead of them.
  Future<RankedEntry?> _resolveCurrentUser() async {
    if (userId.isEmpty) return null;

    for (final ranked in _entries) {
      if (ranked.entry.userId == userId) return ranked;
    }

    final own = await _leaderboardDao.fetchEntry(userId);
    if (own == null) return null;

    return RankedEntry(rank: limit + 1, entry: own);
  }
}
