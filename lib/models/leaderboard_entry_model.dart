// ---------------------------------------------------------------------------
// leaderboard_entry_model.dart
// Module 5 — Reward & Achievement
// Use Case : UC540 Compare standing against other tourists
// FR       : FR-R06 Leaderboard
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// One tourist's public standing: the name, picture and totals other tourists
// are allowed to see.
//
// Deliberately not RewardModel. The tourist document those totals live on
// also carries email, phone number, weight and height, and a leaderboard has
// to be readable by everyone — so the standings are mirrored into their own
// collection holding only these fields, and the tourist document stays
// readable by its owner alone (NFR-04). See dao/leaderboard_dao.dart.
//
// Nothing here is calculated. Points come from the award formula, distance
// and check-in count from the cumulative totals; this only carries them.

/// Shown in place of a name a tourist never set. Not "Anonymous" — every row
/// here belongs to somebody who actually walked, and the board should read as
/// a field of walkers rather than a list of unknowns.
const String kDefaultWalkerName = 'Walker';

class LeaderboardEntryModel {
  /// The tourist this row belongs to, and the document ID in the standings
  /// collection — so one tourist can never occupy two rows.
  final String userId;

  final String displayName;

  /// Profile picture, when the tourist has uploaded one. Null renders as
  /// initials rather than a broken image.
  final String? photoUrl;

  /// Lifetime points. This is what the leaderboard ranks on — see
  /// [LeaderboardRanking.rank].
  final int totalPoints;

  final int totalCheckIns;

  /// Lifetime distance in whole metres, matching how RewardModel stores it.
  final int totalDistanceMetres;

  const LeaderboardEntryModel({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    this.totalPoints = 0,
    this.totalCheckIns = 0,
    this.totalDistanceMetres = 0,
  });

  double get totalDistanceKm => totalDistanceMetres / 1000;

  /// A tourist who has never been awarded anything. Ranking them alongside
  /// walkers would fill the board with zeroes, so the DAO leaves them out.
  bool get hasPoints => totalPoints > 0;

  /// Up to two letters for the avatar when there is no photo.
  ///
  /// First letter of the first two words, so "Khuan Zhi" reads KZ. A name
  /// made only of punctuation or emoji has no letter to take, and falls back
  /// to the default's initial rather than rendering an empty circle.
  String get initials {
    final letters = displayName
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0])
        .where((letter) => RegExp(r'[A-Za-z0-9]').hasMatch(letter))
        .take(2)
        .join();

    return letters.isEmpty ? kDefaultWalkerName[0] : letters.toUpperCase();
  }

  /// Reads a standings document.
  ///
  /// Every field defaults, the same way RewardModel.fromMap does: a row
  /// written by an older build, or one whose profile carried no nickname,
  /// must render as a walker with zeroes rather than crash the board.
  factory LeaderboardEntryModel.fromMap(
    String userId,
    Map<String, dynamic> map,
  ) {
    final name = (map[LeaderboardFields.displayName] as String?)?.trim();
    final photo = (map[LeaderboardFields.photoUrl] as String?)?.trim();

    return LeaderboardEntryModel(
      userId: userId,
      displayName: name == null || name.isEmpty ? kDefaultWalkerName : name,
      // An empty string is not a URL. Normalising it to null here means every
      // widget downstream tests for null alone instead of for both.
      photoUrl: photo == null || photo.isEmpty ? null : photo,
      totalPoints: (map[LeaderboardFields.totalPoints] as num?)?.toInt() ?? 0,
      totalCheckIns:
          (map[LeaderboardFields.totalCheckIns] as num?)?.toInt() ?? 0,
      totalDistanceMetres:
          (map[LeaderboardFields.totalDistanceMetres] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        LeaderboardFields.displayName: displayName,
        LeaderboardFields.photoUrl: photoUrl,
        LeaderboardFields.totalPoints: totalPoints,
        LeaderboardFields.totalCheckIns: totalCheckIns,
        LeaderboardFields.totalDistanceMetres: totalDistanceMetres,
      };

  @override
  String toString() => 'LeaderboardEntryModel(userId: $userId, '
      'name: $displayName, points: $totalPoints)';
}

/// Field names on a standings document.
///
/// Declared here rather than in RewardConstants because they name a different
/// collection with a different shape, and renaming one must not silently
/// rename the other — the same reason `checkInUserIdField` is kept separate
/// from `ledgerUserIdField`.
class LeaderboardFields {
  LeaderboardFields._();

  static const String displayName = 'displayName';
  static const String photoUrl = 'photoUrl';
  static const String totalPoints = 'totalPoints';
  static const String totalCheckIns = 'totalCheckIns';
  static const String totalDistanceMetres = 'totalDistanceMetres';

  /// When this row was last mirrored from the tourist's totals. Written by
  /// the DAO and never read by the model — it exists so that a row which has
  /// fallen behind is diagnosable from the Firestore console.
  static const String updatedAt = 'updatedAt';
}

/// One tourist's row together with the position it holds.
class RankedEntry {
  final int rank;
  final LeaderboardEntryModel entry;

  const RankedEntry({required this.rank, required this.entry});

  /// Top three — the podium (FR-R06).
  bool get isPodium => rank <= 3;

  /// The tourist holding the highest points total. This is the answer to
  /// "who is winning", which is the whole point of the screen.
  bool get isLeader => rank == 1;
}

/// Turns a list of standings into ranked positions.
///
/// Pure Dart with no Flutter or Firestore dependency, so the tie rules can be
/// unit tested directly — which matters, because ties are the case a
/// leaderboard gets wrong and nobody notices until two tourists hold their
/// screens side by side.
class LeaderboardRanking {
  LeaderboardRanking._();

  /// Ranks [entries], highest points first.
  ///
  /// Ties share a rank and the next position skips — standard competition
  /// ranking, so two tourists on 1st are followed by 3rd, not 2nd. Breaking
  /// the tie into 1st and 2nd would be worse than useless: the two have
  /// earned exactly the same points, and the board would be claiming one
  /// out-walked the other.
  ///
  /// Display order within a tie still has to be decided, so it falls to
  /// distance, then name, then user ID. The last is not a meaningful
  /// ordering — it is there so two tourists with identical points, distance
  /// and name still see the same order as each other, rather than whichever
  /// order the documents happened to arrive in.
  static List<RankedEntry> rank(List<LeaderboardEntryModel> entries) {
    final sorted = [...entries]..sort(_byStanding);

    final ranked = <RankedEntry>[];
    var rank = 0;
    int? previousPoints;

    for (var i = 0; i < sorted.length; i++) {
      final entry = sorted[i];
      // Rank comes from the position in the list, not from a running counter:
      // a tie of two at 1st is followed by 3rd, because two tourists already
      // sit above that row.
      if (entry.totalPoints != previousPoints) {
        rank = i + 1;
        previousPoints = entry.totalPoints;
      }
      ranked.add(RankedEntry(rank: rank, entry: entry));
    }

    return ranked;
  }

  static int _byStanding(LeaderboardEntryModel a, LeaderboardEntryModel b) {
    final byPoints = b.totalPoints.compareTo(a.totalPoints);
    if (byPoints != 0) return byPoints;

    final byDistance = b.totalDistanceMetres.compareTo(a.totalDistanceMetres);
    if (byDistance != 0) return byDistance;

    final byName =
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    if (byName != 0) return byName;

    return a.userId.compareTo(b.userId);
  }
}
