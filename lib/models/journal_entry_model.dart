// journal_entry_model.dart — Module 5: Reward & Achievement
// Data model for a single walking journal entry (destination name, date/time,
// distance walked, points earned, carbon saved, calories burned). FR-R03
//
// Pure Dart with no Firestore import: JournalDao converts the Timestamp at its
// edge, the same way badge_dao.dart does for a badge's earned date.

import 'transport_mode.dart';

/// One completed journey, as the walking journal lists it.
///
/// Read model over Module 4's `check_ins` document rather than a second
/// collection of its own. The check-in *is* the journey record — copying it
/// into a parallel "journal" collection would create two sources of truth that
/// could disagree, and nothing would reconcile them.
class JournalEntryModel {
  const JournalEntryModel({
    required this.checkInId,
    required this.destinationName,
    required this.destinationId,
    required this.checkInTime,
    required this.distanceKm,
    this.walkedDistanceKm,
    required this.pointsAwarded,
    required this.carbonSavedKg,
    required this.caloriesBurned,
    this.transportMode = TransportMode.walking,
  });

  final String checkInId;

  /// Empty for journeys recorded before the name was stored; the tile shows
  /// [displayName] rather than a blank row.
  final String destinationName;

  final String destinationId;
  final DateTime checkInTime;

  /// The journey's planned route distance — the figure its points were
  /// awarded on. Kept because it is what the reward and badge totals were
  /// scored against, but [displayDistanceKm] is what the journal shows.
  final double distanceKm;

  /// How far the tourist actually walked, from the live GPS stream.
  ///
  /// Null for a journey that recorded no tracked distance, including every
  /// check-in written before the field existed — see [displayDistanceKm].
  final double? walkedDistanceKm;

  /// The distance to put in front of the tourist.
  ///
  /// Their own walking, whenever it was tracked: a history that answers "how
  /// far did I walk?" with the route's prediction is answering a different
  /// question, and it would contradict [caloriesBurned], which is already
  /// calculated from the distance actually covered.
  ///
  /// Falls back to the planned [distanceKm] for a journey with nothing
  /// tracked. That journey was really walked, and the planned distance is the
  /// best figure on record for it — better than a dash.
  double get displayDistanceKm => walkedDistanceKm ?? distanceKm;

  /// Points this journey earned. 0 for a journey that earned none — a drive or
  /// a bus ride (FR-W01) — and also 0 for one recorded before the award was
  /// copied onto the check-in. The two are indistinguishable here, which is
  /// why [transportMode] is shown alongside it.
  final int pointsAwarded;

  final double carbonSavedKg;
  final double caloriesBurned;
  final TransportMode transportMode;

  /// What to put on the tile. Never an empty string, and never the raw Places
  /// id — "ChIJ50W1D43DSjARlPqYV1MqscE" tells a tourist nothing.
  String get displayName =>
      destinationName.isNotEmpty ? destinationName : 'Unknown place';

  /// Whether this entry predates the fields the journal needs, so the UI can
  /// explain a nameless, point-less row instead of looking broken.
  bool get isIncomplete => destinationName.isEmpty;

  /// Builds an entry from a `check_ins` document.
  ///
  /// Every field falls back rather than throwing. Records written before
  /// `destinationName` and `pointsAwarded` existed are real journeys the
  /// tourist actually walked, and dropping them from their own history would
  /// be worse than showing them incomplete.
  factory JournalEntryModel.fromMap(String id, Map<String, dynamic> map) {
    return JournalEntryModel(
      checkInId: map['checkInId'] as String? ?? id,
      destinationName: map['destinationName'] as String? ?? '',
      destinationId: map['destinationId'] as String? ?? '',
      checkInTime: map['checkInTime'] as DateTime? ?? DateTime.now(),
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      // Null rather than 0.0 when absent: the record does not claim the
      // tourist walked nothing, it carries no tracked distance at all, and
      // [displayDistanceKm] falls back to the planned figure for it.
      walkedDistanceKm: (map['walkedDistanceKm'] as num?)?.toDouble(),
      pointsAwarded: (map['pointsAwarded'] as num?)?.toInt() ?? 0,
      carbonSavedKg: (map['carbonSavedKg'] as num?)?.toDouble() ?? 0.0,
      caloriesBurned: (map['caloriesBurned'] as num?)?.toDouble() ?? 0.0,
      transportMode: TransportMode.fromId(map['transportMode'] as String?),
    );
  }

  /// 'Today', 'Yesterday', '3 days ago', then a plain date — matching how
  /// Review.relativeTime reads in the Discovery module.
  String relativeDate(DateTime now) {
    final thatDay = DateTime(checkInTime.year, checkInTime.month, checkInTime.day);
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(thatDay).inDays;

    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    return '${checkInTime.day}/${checkInTime.month}/${checkInTime.year}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalEntryModel && other.checkInId == checkInId);

  @override
  int get hashCode => checkInId.hashCode;
}
