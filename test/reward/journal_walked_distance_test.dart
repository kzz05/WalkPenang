// Tests for the walked-vs-planned distance split on a completed journey.
//
// A journey carries two distances that answer two different questions:
//
//   distanceKm        the route's planned length — what the points and the
//                     distance badges were scored on, so a detour cannot
//                     inflate an award
//   walkedDistanceKm  what the GPS actually measured — what the tourist's
//                     own history should say they walked
//
// Before the split there was only the first, so Journey Completed reported
// 1.9 km and the same journey opened from it reported 1.2 km — while the
// calories on that screen had been calculated from the 1.9 all along.
//
// The rule these pin down is that display follows the walk and reward
// follows the route, and that a record carrying no walked distance (every
// check-in written before the field existed) still reads correctly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/models/check_in_result.dart';
import 'package:walkpenang/models/journal_entry_model.dart';
import 'package:walkpenang/models/transport_mode.dart';
import 'package:walkpenang/views/reward/journal_detail_screen.dart';
import 'package:walkpenang/widgets/reward/journal_entry_tile.dart';

CheckInResult _checkIn({double? walkedDistanceKm}) => CheckInResult(
      checkInId: 'chk_001',
      userId: 'tourist_001',
      destinationId: 'ChIJ_chew_jetty',
      destinationName: 'Chew Jetty',
      distanceKm: 1.2,
      walkedDistanceKm: walkedDistanceKm,
      carbonSavedKg: 0.252,
      caloriesBurned: 111.15,
      checkInTime: DateTime(2026, 8, 21, 10, 30),
    );

JournalEntryModel _entry({
  double distanceKm = 1.2,
  double? walkedDistanceKm,
  int pointsAwarded = 22,
  TransportMode transportMode = TransportMode.walking,
}) =>
    JournalEntryModel(
      checkInId: 'chk_001',
      destinationName: 'Chew Jetty',
      destinationId: 'ChIJ_chew_jetty',
      checkInTime: DateTime(2026, 8, 21, 10, 30),
      distanceKm: distanceKm,
      walkedDistanceKm: walkedDistanceKm,
      pointsAwarded: pointsAwarded,
      carbonSavedKg: 0.252,
      caloriesBurned: 111.15,
      transportMode: transportMode,
    );

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

void main() {
  group('CheckInResult serialisation', () {
    test('round-trips the walked distance', () {
      final restored = CheckInResult.fromMap(_checkIn(walkedDistanceKm: 1.9)
          .toMap()
          .cast<String, dynamic>());

      expect(restored.walkedDistanceKm, closeTo(1.9, 1e-9));
      // And the planned distance is still its own field, untouched.
      expect(restored.distanceKm, closeTo(1.2, 1e-9));
    });

    test('a journey that tracked nothing omits the field rather than '
        'writing a null', () {
      final map = _checkIn().toMap();

      // The record is saved with SetOptions(merge: true) and re-saved on a
      // reward retry, so an explicit null would erase a distance an earlier
      // save had already recorded.
      expect(map.containsKey('walkedDistanceKm'), isFalse);
      expect(map['distanceKm'], closeTo(1.2, 1e-9));
    });

    test('a legacy record reads back as null, not as zero kilometres', () {
      // A check-in written before the field existed. It did not walk zero
      // kilometres — it never recorded how far it walked, and only null can
      // say that.
      final restored = CheckInResult.fromMap({
        'checkInId': 'chk_legacy',
        'userId': 'tourist_001',
        'destinationId': 'ChIJ_chew_jetty',
        'destinationName': 'Chew Jetty',
        'distanceKm': 1.165,
        'carbonSavedKg': 0.24465,
        'caloriesBurned': 52.425,
        'checkInTime': DateTime(2026, 8, 20, 23, 24),
        'transportMode': 'walking',
      });

      expect(restored.walkedDistanceKm, isNull);
      expect(restored.distanceKm, closeTo(1.165, 1e-9));
    });

    test('the reward input is the planned distance, whatever was walked', () {
      // The guard on the whole design: distanceMetres is what the points
      // formula and the badge totals read, and it must never follow the
      // walked figure.
      expect(_checkIn(walkedDistanceKm: 1.9).distanceMetres, 1200);
      expect(_checkIn().distanceMetres, 1200);
    });
  });

  group('JournalEntryModel.displayDistanceKm', () {
    test('prefers the distance actually walked', () {
      expect(_entry(walkedDistanceKm: 1.9).displayDistanceKm,
          closeTo(1.9, 1e-9));
    });

    test('falls back to the planned distance when none was tracked', () {
      // A real journey with nothing measured. The planned distance is the
      // best figure on record for it — better than a dash.
      expect(_entry().displayDistanceKm, closeTo(1.2, 1e-9));
    });

    test('reads the walked distance from a check-in document', () {
      final entry = JournalEntryModel.fromMap('doc-1', {
        'checkInId': 'doc-1',
        'destinationName': 'Chew Jetty',
        'destinationId': 'ChIJ_chew_jetty',
        'checkInTime': DateTime(2026, 8, 21, 10, 30),
        'distanceKm': 1.2,
        'walkedDistanceKm': 1.9,
        'pointsAwarded': 22,
        'carbonSavedKg': 0.252,
        'caloriesBurned': 111.15,
        'transportMode': 'walking',
      });

      expect(entry.walkedDistanceKm, closeTo(1.9, 1e-9));
      expect(entry.distanceKm, closeTo(1.2, 1e-9));
      expect(entry.displayDistanceKm, closeTo(1.9, 1e-9));
    });

    test('a document without the field leaves it null', () {
      final entry = JournalEntryModel.fromMap('doc-2', {
        'checkInId': 'doc-2',
        'destinationName': 'Chew Jetty',
        'destinationId': 'ChIJ_chew_jetty',
        'checkInTime': DateTime(2026, 8, 20, 23, 24),
        'distanceKm': 1.165,
        'pointsAwarded': 21,
        'carbonSavedKg': 0.24465,
        'caloriesBurned': 52.425,
        'transportMode': 'walking',
      });

      expect(entry.walkedDistanceKm, isNull);
      expect(entry.displayDistanceKm, closeTo(1.165, 1e-9));
    });
  });

  group('JournalEntryTile', () {
    testWidgets('lists the distance walked, not the route planned',
        (tester) async {
      await _pump(
        tester,
        JournalEntryTile(
          entry: _entry(walkedDistanceKm: 1.9),
          now: DateTime(2026, 8, 21, 12, 00),
        ),
      );

      expect(find.textContaining('1.9 km'), findsOneWidget);
      expect(find.textContaining('1.2 km'), findsNothing);
    });

    testWidgets('a legacy journey still lists its planned distance',
        (tester) async {
      await _pump(
        tester,
        JournalEntryTile(
          entry: _entry(),
          now: DateTime(2026, 8, 21, 12, 00),
        ),
      );

      expect(find.textContaining('1.2 km'), findsOneWidget);
    });
  });

  group('JournalDetailScreen', () {
    testWidgets('shows the distance walked', (tester) async {
      await _pump(
          tester, JournalDetailScreen(entry: _entry(walkedDistanceKm: 1.9)));

      // Agrees with the KM WALKED tile the tourist came from, and with the
      // calories beside it, which were always based on the walked distance.
      expect(find.text('1.90 km'), findsOneWidget);
      expect(find.text('1.20 km'), findsNothing);
    });

    testWidgets('a legacy journey shows its planned distance', (tester) async {
      await _pump(tester, JournalDetailScreen(entry: _entry()));

      expect(find.text('1.20 km'), findsOneWidget);
    });

    testWidgets('signs the points and names their unit', (tester) async {
      await _pump(
          tester, JournalDetailScreen(entry: _entry(walkedDistanceKm: 1.9)));

      // Matching the "+22 pts" on the journal tile this screen opens from.
      expect(find.text('+22 pts'), findsOneWidget);
      expect(find.text('22'), findsNothing);
    });

    testWidgets('an unrewarded walk still reads as not recorded',
        (tester) async {
      await _pump(tester, JournalDetailScreen(entry: _entry(pointsAwarded: 0)));

      // A pre-existing record, not a zero award — and never "+0 pts".
      expect(find.text('not recorded'), findsOneWidget);
      expect(find.textContaining('pts'), findsNothing);
    });

    testWidgets('a drive still reads as earning nothing by rule',
        (tester) async {
      await _pump(
        tester,
        JournalDetailScreen(
          entry: _entry(
            pointsAwarded: 0,
            transportMode: TransportMode.driving,
            walkedDistanceKm: 1.9,
          ),
        ),
      );

      expect(find.text('none — walking only'), findsOneWidget);
    });
  });
}
