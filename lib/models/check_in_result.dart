// ---------------------------------------------------------------------------
// check_in_result.dart
// Module 5 — Reward & Achievement
// Use Case : UC500 Earn points from activities
// FR       : FR-R01 Points Award System
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// The boundary object between Module 4 (Walking & Carbon) and Module 5.
//
// Module 5 begins at "receive verified check-in data". Every value here has
// already been produced by Module 4: the arrival radius was checked against
// FR-W05, and distance, carbon and calories were calculated there. Module 5
// consumes them and must never recompute or re-verify any of them.

import '../utils/reward_constants.dart';
import 'transport_mode.dart';

class CheckInResult {
  /// Firestore document ID of the verified check-in.
  ///
  /// Doubles as the idempotency key: the points ledger entry is written under
  /// this ID, so a retried award overwrites rather than appends (T-R01.5).
  final String checkInId;

  /// The tourist who checked in. Supplied by Module 1 via Module 4.
  final String userId;

  /// The attraction checked into, from Module 2's catalogue.
  final String destinationId;

  /// The attraction's display name at the time of the check-in.
  ///
  /// Denormalised deliberately. [destinationId] is a Places id, so a journal
  /// built on the id alone would list "ChIJ50W1D43DSjARlPqYV1MqscE" instead of
  /// "Chew Jetty", and resolving it later would mean a Places lookup per row —
  /// billed, and useless offline. Storing the name also keeps the record
  /// truthful: it is what the place was called when the tourist walked there,
  /// which is the right thing to show in a history even if it is renamed.
  ///
  /// Empty for check-ins written before this field existed; the journal
  /// renders those as an unknown place rather than a blank row.
  final String destinationName;

  /// The journey's **planned route** distance, as calculated by Module 4.
  ///
  /// This is the rewardable figure and nothing else may be substituted for
  /// it: [distanceMetres] derives from it, and that is what the points
  /// formula and the cumulative distance behind the distance badges are both
  /// scored on. Keeping it pinned to the route is what stops a tourist
  /// earning more by walking a longer way round than the route asked for.
  ///
  /// How far they *actually* walked is [walkedDistanceKm], which is recorded
  /// beside this one rather than in place of it.
  final double distanceKm;

  /// Metres actually walked, as accumulated from the live GPS stream, in km.
  ///
  /// Display only — the walking journal and the journey detail screen show
  /// this so a tourist's history answers "how far did I walk?" with the
  /// distance they covered rather than the one the route predicted. Nothing
  /// in the reward path reads it, deliberately: a detour lengthens this
  /// figure and must not lengthen the award.
  ///
  /// Null when the journey produced no tracked distance to record — no
  /// position fix landed, or the check-in predates this field. Consumers
  /// fall back to [distanceKm] rather than showing a gap; see
  /// [JournalEntryModel.displayDistanceKm].
  final double? walkedDistanceKm;

  /// Carbon saved versus driving the same distance, as calculated by Module 4.
  ///
  /// Route-based, like [distanceKm]: it is the counterfactual "what driving
  /// this route would have emitted", so a detour does not earn extra credit.
  final double carbonSavedKg;

  /// Calories burned, as calculated by Module 4.
  final double caloriesBurned;

  /// When the check-in was verified.
  final DateTime checkInTime;

  /// How the tourist travelled. Chosen before departure on the journey screen.
  ///
  /// Module 5 reads this to decide whether the check-in earns points at all —
  /// only [TransportMode.walking] does. This completes a rule the Walking
  /// module already applies to its other benefits: [WalkingController]
  /// reports 0.0 carbon saved and a null calorie estimate for every
  /// non-walking mode, so points were the last thing a driven journey could
  /// still collect.
  ///
  /// Defaults to [TransportMode.walking] so existing call sites and every
  /// check-in written before modes existed keep their current behaviour.
  final TransportMode transportMode;

  const CheckInResult({
    required this.checkInId,
    required this.userId,
    required this.destinationId,
    this.destinationName = '',
    required this.distanceKm,
    this.walkedDistanceKm,
    required this.carbonSavedKg,
    required this.caloriesBurned,
    required this.checkInTime,
    this.transportMode = TransportMode.walking,
  });

  /// Whether this journey qualifies for points (FR-W01).
  bool get earnsPoints => transportMode.earnsPoints;

  /// The **planned** distance in whole metres — the reward input.
  ///
  /// The points formula and the badge thresholds both work in integer metres
  /// so that binary floating point cannot shift a result across a boundary.
  ///
  /// Reads [distanceKm], never [walkedDistanceKm]. That is the whole reason
  /// the two are separate fields.
  int get distanceMetres => RewardConstants.metresFromKm(distanceKm);

  factory CheckInResult.fromMap(Map<String, dynamic> map) {
    return CheckInResult(
      checkInId: map['checkInId'] as String,
      userId: map['userId'] as String,
      destinationId: map['destinationId'] as String? ?? '',
      destinationName: map['destinationName'] as String? ?? '',
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      // Stays null when absent rather than falling back to 0.0: a check-in
      // written before this field existed did not walk zero kilometres, it
      // simply never recorded how far it walked, and only null can say that.
      walkedDistanceKm: (map['walkedDistanceKm'] as num?)?.toDouble(),
      carbonSavedKg: (map['carbonSavedKg'] as num?)?.toDouble() ?? 0.0,
      caloriesBurned: (map['caloriesBurned'] as num?)?.toDouble() ?? 0.0,
      checkInTime: map['checkInTime'] as DateTime,
      transportMode: TransportMode.fromId(map['transportMode'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'checkInId': checkInId,
      'userId': userId,
      'destinationId': destinationId,
      'destinationName': destinationName,
      'distanceKm': distanceKm,
      // Omitted rather than written as an explicit null. The check-in is
      // saved with SetOptions(merge: true) and re-saved on a reward retry, so
      // a null in the map would clear a distance an earlier save had already
      // recorded. Absent is also exactly what a legacy record looks like, so
      // both read back the same way.
      if (walkedDistanceKm != null) 'walkedDistanceKm': walkedDistanceKm,
      'carbonSavedKg': carbonSavedKg,
      'caloriesBurned': caloriesBurned,
      'checkInTime': checkInTime,
      'transportMode': transportMode.name,
    };
  }

  @override
  String toString() =>
      'CheckInResult(checkInId: $checkInId, userId: $userId, '
      'distanceKm: $distanceKm)';
}
