// ---------------------------------------------------------------------------
// leaderboard_screen_test.dart
// Module 5 — Reward & Achievement
// Use Case : UC540 Compare standing against other tourists
// FR       : FR-R06 Leaderboard
// Task     : T-R06.2 Leaderboard screen states
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// Smoke tests for the leaderboard, driven by the in-memory board so no
// Firebase project or signed-in tourist is needed.
//
// These exist for the same reason the other reward screen tests do: to catch
// layout overflow. The podium puts three variable-length names side by side in
// a Row, which is exactly the shape that overflows on a narrow phone and never
// shows up in flutter analyze.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/controllers/leaderboard_controller.dart';
import '../support/in_memory_reward_data.dart';
import 'package:walkpenang/models/leaderboard_entry_model.dart';
import 'package:walkpenang/views/reward/leaderboard_screen.dart';
import 'package:walkpenang/widgets/reward/leaderboard_row.dart';

LeaderboardController demoBoard({
  String userId = DemoRewardData.userId,
  List<LeaderboardEntryModel>? entries,
  int limit = 50,
}) {
  return LeaderboardController(
    userId: userId,
    leaderboardDao: InMemoryLeaderboardDao(
      entries: entries ?? DemoRewardData.standings,
    ),
    limit: limit,
  );
}

Future<void> pump(WidgetTester tester, Widget screen) async {
  // A representative phone. Fixing the size makes an overflow deterministic
  // rather than dependent on the default 800x600 test window.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the podium and the rest of the board', (tester) async {
    await pump(tester, LeaderboardScreen(controller: demoBoard()));

    expect(find.text('Leaderboard'), findsOneWidget);

    // The leader is named on the podium, and the trophy marks first place.
    expect(find.text('Mei Ling'), findsOneWidget);
    expect(find.text('512 PTS'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events), findsOneWidget);

    // Three plinths, and a row for each tourist below them.
    expect(find.text('1'), findsOneWidget);
    expect(
      find.byType(LeaderboardRowTile),
      findsNWidgets(DemoRewardData.standings.length - 3),
    );
  });

  testWidgets('names the signed-in tourist as You and quotes the gap',
      (tester) async {
    await pump(tester, LeaderboardScreen(controller: demoBoard()));

    // The demo tourist sits 4th on 194 points, 11 behind Siti on 205.
    expect(find.text('You are ranked #4'), findsOneWidget);
    expect(find.textContaining('11 points behind'), findsOneWidget);
    // Their own row is labelled rather than left to be found by name.
    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('tells the leader they are first', (tester) async {
    await pump(
      tester,
      LeaderboardScreen(controller: demoBoard(userId: 'demo_mei_ling')),
    );

    expect(find.text('You are in first place'), findsOneWidget);
    expect(find.textContaining('512 points'), findsOneWidget);
  });

  testWidgets('pins the standing of a tourist below the fetched page',
      (tester) async {
    await pump(
      tester,
      LeaderboardScreen(controller: demoBoard(userId: 'demo_wong', limit: 3)),
    );

    expect(find.text('YOUR STANDING'), findsOneWidget);
    // The board says where it stopped rather than inventing a position it
    // cannot know without counting every tourist ahead.
    expect(find.text('3+'), findsOneWidget);
    expect(find.text('You are below the top 3'), findsOneWidget);
  });

  testWidgets('an empty board reads as a starting point, not a failure',
      (tester) async {
    await pump(
      tester,
      LeaderboardScreen(controller: demoBoard(entries: const [])),
    );

    expect(find.text('Nobody on the board yet'), findsOneWidget);
    expect(find.byType(LeaderboardRowTile), findsNothing);
  });

  testWidgets('a signed-out tourist still sees the board', (tester) async {
    await pump(tester, LeaderboardScreen(controller: demoBoard(userId: '')));

    expect(find.text('Mei Ling'), findsOneWidget);
    expect(find.text('Sign in to join the board'), findsOneWidget);
  });

  testWidgets('a two-tourist board renders without an empty plinth',
      (tester) async {
    await pump(
      tester,
      LeaderboardScreen(
        controller: demoBoard(
          entries: DemoRewardData.standings.take(2).toList(),
        ),
      ),
    );

    expect(find.byType(LeaderboardPodium), findsOneWidget);
    expect(find.text('Mei Ling'), findsOneWidget);
    expect(find.text('Arjun Rao'), findsOneWidget);
    expect(find.byType(LeaderboardRowTile), findsNothing);
  });

  testWidgets('a very long name does not overflow the podium', (tester) async {
    // The case the podium is most likely to break on: three long names in a
    // Row on a narrow phone.
    await pump(
      tester,
      LeaderboardScreen(
        controller: demoBoard(
          entries: const [
            LeaderboardEntryModel(
              userId: 'a',
              displayName: 'Muhammad Irsyad Bin Kamil Riadz',
              totalPoints: 800,
              totalCheckIns: 30,
              totalDistanceMetres: 50000,
            ),
            LeaderboardEntryModel(
              userId: 'b',
              displayName: 'Nur Aisyah Binti Abdul Rahman',
              totalPoints: 700,
              totalCheckIns: 26,
              totalDistanceMetres: 44000,
            ),
            LeaderboardEntryModel(
              userId: 'c',
              displayName: 'Ravichandran Subramaniam',
              totalPoints: 600,
              totalCheckIns: 22,
              totalDistanceMetres: 38000,
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
