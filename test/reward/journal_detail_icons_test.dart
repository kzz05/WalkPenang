// Tests for the leading icons on the Journey Detail rows.
//
// The six rows are a wall of mono labels and figures, and the tourist reads
// them looking for one of them. A small glyph per row gives each one a shape
// to find it by. The icons say nothing the label does not, which is exactly
// why they must stay decorative: they carry no semantic label, so a screen
// reader still announces each row once.
//
// What these pin down is that the icons arrived without disturbing anything —
// the labels, the values and the "+22 pts" and walked-distance rules are
// unchanged — and that WpDetailRow's other callers, which pass no icon, are
// left exactly as they were.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/models/journal_entry_model.dart';
import 'package:walkpenang/models/transport_mode.dart';
import 'package:walkpenang/theme/app_theme.dart';
import 'package:walkpenang/views/reward/journal_detail_screen.dart';
import 'package:walkpenang/views/widgets/wp_components.dart';

JournalEntryModel _entry({
  double distanceKm = 1.2,
  double? walkedDistanceKm = 1.9,
  int pointsAwarded = 22,
  TransportMode transportMode = TransportMode.walking,
}) =>
    JournalEntryModel(
      checkInId: 'chk_001',
      destinationName: 'Chew Jetty',
      destinationId: 'ChIJ_chew_jetty',
      checkInTime: DateTime(2026, 9, 6, 9, 5),
      distanceKm: distanceKm,
      walkedDistanceKm: walkedDistanceKm,
      pointsAwarded: pointsAwarded,
      carbonSavedKg: 0.252,
      caloriesBurned: 92.4,
      transportMode: transportMode,
    );

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

/// The row carrying [label], so an icon can be checked against the row it
/// belongs to rather than merely against the screen.
Finder _row(String label) => find.ancestor(
      of: find.text(label.toUpperCase()),
      matching: find.byType(WpDetailRow),
    );

void main() {
  group('JournalDetailScreen icons', () {
    testWidgets('gives every one of the six rows a leading icon',
        (tester) async {
      await _pump(tester, JournalDetailScreen(entry: _entry()));

      const expected = <String, IconData>{
        'distance': Icons.directions_walk,
        'travelled by': Icons.commute_outlined,
        'points earned': Icons.stars_rounded,
        'carbon saved': Icons.eco_outlined,
        'calories burned': Icons.local_fire_department_outlined,
        'completed': Icons.event_available_outlined,
      };

      expect(find.byType(WpDetailRow), findsNWidgets(6));

      expected.forEach((label, icon) {
        expect(
          find.descendant(of: _row(label), matching: find.byIcon(icon)),
          findsOneWidget,
          reason: 'the "$label" row should carry its own icon',
        );
      });
    });

    testWidgets('sizes and mutes the icons like the reward stat cards',
        (tester) async {
      await _pump(tester, JournalDetailScreen(entry: _entry()));

      for (final icon in tester.widgetList<Icon>(
        find.descendant(
          of: find.byType(WpDetailRow),
          matching: find.byType(Icon),
        ),
      )) {
        expect(icon.size, 18);
        expect(icon.color, AppColors.muted);
        // Decorative: the label beside it already says this. A semantic
        // label here would have the row read out twice.
        expect(icon.semanticLabel, isNull);
      }
    });

    testWidgets('does not use a walking glyph for the mode row', (tester) async {
      // The value there may be Driving or Public Transport, so the icon must
      // not claim the journey was walked.
      await _pump(
        tester,
        JournalDetailScreen(entry: _entry(transportMode: TransportMode.driving)),
      );

      expect(
        find.descendant(
          of: _row('travelled by'),
          matching: find.byIcon(Icons.directions_walk),
        ),
        findsNothing,
      );
    });

    testWidgets('leaves the six labels and their values untouched',
        (tester) async {
      await _pump(tester, JournalDetailScreen(entry: _entry()));

      for (final label in const [
        'DISTANCE',
        'TRAVELLED BY',
        'POINTS EARNED',
        'CARBON SAVED',
        'CALORIES BURNED',
        'COMPLETED',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      // The walked distance, not the 1.2 km the route planned.
      expect(find.text('1.90 km'), findsOneWidget);
      expect(find.text('1.20 km'), findsNothing);
      // Signed and carrying its unit, as on the journal tile.
      expect(find.text('+22 pts'), findsOneWidget);
      expect(find.text('Walking'), findsOneWidget);
      expect(find.text('0.25 kg'), findsOneWidget);
      expect(find.text('92 kcal'), findsOneWidget);
      expect(find.text('6/9/2026 at 09:05'), findsOneWidget);
    });

    testWidgets('fits a long value on a small phone without overflowing',
        (tester) async {
      // The narrowest screen the app supports, with the longest value any of
      // the six rows can hold — an icon must not squeeze it into an overflow.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(
        tester,
        JournalDetailScreen(
          entry: _entry(
            pointsAwarded: 0,
            transportMode: TransportMode.publicTransport,
          ),
        ),
      );

      expect(find.text('none — walking only'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('WpDetailRow', () {
    testWidgets('renders without an icon by default, as its other callers '
        'still use it', (tester) async {
      await _pump(
        tester,
        const WpDetailRow(label: 'height', value: '170 cm'),
      );

      expect(find.text('HEIGHT'), findsOneWidget);
      expect(find.text('170 cm'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(WpDetailRow),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
    });

    testWidgets('shows the icon it is given', (tester) async {
      await _pump(
        tester,
        const WpDetailRow(
          label: 'milestone',
          value: '10 journeys',
          icon: Icons.stars_rounded,
        ),
      );

      expect(find.byIcon(Icons.stars_rounded), findsOneWidget);
      expect(find.text('MILESTONE'), findsOneWidget);
      expect(find.text('10 journeys'), findsOneWidget);
    });
  });
}
