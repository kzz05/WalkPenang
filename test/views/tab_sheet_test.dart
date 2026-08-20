// The sheet that replaced the bottom navigation bar.
//
// HomeView cannot be pumped in a widget test — it builds a MapPanel, which
// creates a MapController that asks Geolocator for a position stream. These
// exercise WpTabSheet and WpSheetToggleButton directly instead, which is where
// the behaviour actually lives.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/views/widgets/wp_tab_sheet.dart';

void main() {
  List<WpTab> tabsFor(List<String> labels) {
    return [
      for (final label in labels)
        WpTab(
          label: label,
          builder: (_) => _TabProbe(label: label),
        ),
    ];
  }

  setUp(_TabProbeState.inits.clear);

  Future<void> pumpSheet(
    WidgetTester tester, {
    required List<String> labels,
    int currentIndex = 0,
    ValueChanged<int>? onTabSelected,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WpTabSheet(
            tabs: tabsFor(labels),
            currentIndex: currentIndex,
            onTabSelected: onTabSelected ?? (_) {},
          ),
        ),
      ),
    );
  }

  group('WpTabSheet', () {
    testWidgets('shows a pill per tab and the selected tab body',
        (tester) async {
      await pumpSheet(tester, labels: const ['Explore', 'Walk', 'Rewards']);

      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Walk'), findsOneWidget);
      expect(find.text('Rewards'), findsOneWidget);
      expect(find.text('Explore body'), findsOneWidget);
    });

    testWidgets('reports the tapped tab index', (tester) async {
      int? tapped;
      await pumpSheet(
        tester,
        labels: const ['Explore', 'Walk', 'Rewards'],
        onTabSelected: (index) => tapped = index,
      );

      await tester.tap(find.text('Rewards'));
      await tester.pump();

      expect(tapped, 2);
    });

    testWidgets('keeps every tab alive so switching does not refetch',
        (tester) async {
      // The IndexedStack guarantee, measured where it matters: each tab's
      // State is created once and preserved across switches. The journal and
      // the dashboard both call load() from initState, so a torn-down tab
      // would refetch from Firestore every time the tourist came back to it.
      //
      // Builder closures do re-run — HomeView rebuilds its tab list each
      // frame — but that only produces a new widget for the same State, which
      // is exactly the distinction this asserts.
      await pumpSheet(tester, labels: const ['Explore', 'Walk']);
      expect(_TabProbeState.inits['Explore'], 1);
      expect(_TabProbeState.inits['Walk'], 1);

      await pumpSheet(tester, labels: const ['Explore', 'Walk'], currentIndex: 1);
      expect(find.text('Walk body'), findsOneWidget);

      expect(_TabProbeState.inits['Explore'], 1);
      expect(_TabProbeState.inits['Walk'], 1);
    });

    testWidgets('leaves the map visible above it', (tester) async {
      await pumpSheet(tester, labels: const ['Explore']);

      final size = tester.getSize(find.byType(WpTabSheet));
      final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;

      // A full-height panel would read as a screen you navigated to. The point
      // of the sheet is that home is still behind it.
      expect(size.height, lessThan(screen));
    });
  });

  group('WpSheetToggleButton', () {
    Future<void> pumpButton(WidgetTester tester, {required bool isOpen}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WpSheetToggleButton(isOpen: isOpen, onPressed: () {}),
          ),
        ),
      );
    }

    testWidgets('is a menu icon closed and a close icon open', (tester) async {
      await pumpButton(tester, isOpen: false);
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);

      await pumpButton(tester, isOpen: true);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsNothing);
    });

    testWidgets('does not move or resize between states', (tester) async {
      // The whole interaction rests on the X landing exactly where the menu
      // button was. A different size or offset between the two states would
      // break that however carefully the parent positions it.
      await pumpButton(tester, isOpen: false);
      final closedRect = tester.getRect(find.byType(WpSheetToggleButton));

      await pumpButton(tester, isOpen: true);
      await tester.pumpAndSettle();
      final openRect = tester.getRect(find.byType(WpSheetToggleButton));

      expect(openRect, closedRect);
    });

    testWidgets('reports taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WpSheetToggleButton(isOpen: false, onPressed: () => taps++),
          ),
        ),
      );

      await tester.tap(find.byType(WpSheetToggleButton));
      await tester.pump();

      expect(taps, 1);
    });
  });
}

/// Records how many times its State was created, per label.
class _TabProbe extends StatefulWidget {
  const _TabProbe({required this.label});

  final String label;

  @override
  State<_TabProbe> createState() => _TabProbeState();
}

class _TabProbeState extends State<_TabProbe> {
  static final Map<String, int> inits = {};

  @override
  void initState() {
    super.initState();
    inits[widget.label] = (inits[widget.label] ?? 0) + 1;
  }

  @override
  Widget build(BuildContext context) =>
      Center(child: Text('${widget.label} body'));
}
