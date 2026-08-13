import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/theme/app_theme.dart';
import 'package:walkpenang/views/widgets/wp_components.dart';

/// The one bottom-bar design, and the input-theme trap that hid the OTP boxes.
void main() {
  Future<void> pumpNav(
    WidgetTester tester, {
    required List<String> items,
    int currentIndex = 0,
    ValueChanged<int>? onTap,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          bottomNavigationBar: WpBottomNav(
            currentIndex: currentIndex,
            items: items,
            onTap: onTap ?? (_) {},
          ),
        ),
      ),
    );
  }

  group('WpBottomNav', () {
    testWidgets('renders a Material NavigationBar, like the Discovery shell',
        (tester) async {
      await pumpNav(tester, items: const ['home', 'explore', 'walk']);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
    });

    testWidgets('labels are title case, not the mono uppercase treatment',
        (tester) async {
      await pumpNav(tester, items: const ['home', 'explore', 'rewards']);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Rewards'), findsOneWidget);
      expect(find.text('HOME'), findsNothing);
    });

    testWidgets('the selected item is filled and the rest are outlined',
        (tester) async {
      await pumpNav(
        tester,
        items: const ['home', 'explore', 'walk'],
        currentIndex: 1,
      );

      // Selected.
      expect(find.byIcon(Icons.explore), findsOneWidget);
      expect(find.byIcon(Icons.explore_outlined), findsNothing);
      // Resting.
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.byIcon(Icons.home), findsNothing);
    });

    testWidgets('reports the tapped index', (tester) async {
      final tapped = <int>[];
      await pumpNav(
        tester,
        items: const ['home', 'explore', 'walk'],
        onTap: tapped.add,
      );

      await tester.tap(find.text('Walk'));
      await tester.pumpAndSettle();

      expect(tapped, [2]);
    });

    testWidgets('an unknown item still renders rather than crashing',
        (tester) async {
      await pumpNav(tester, items: const ['home', 'nonsense']);

      expect(find.byType(NavigationDestination), findsNWidgets(2));
      expect(find.text('Nonsense'), findsOneWidget);
    });
  });

  group('navigation bar theme', () {
    testWidgets('drives the bar, so both nav bars cannot drift apart',
        (tester) async {
      await pumpNav(tester, items: const ['home', 'explore']);

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      // The widget sets no colours of its own — everything resolves from the
      // shared theme, which the Discovery shell's bar also reads.
      expect(bar.backgroundColor, isNull);
      expect(bar.indicatorColor, isNull);

      final theme = buildAppTheme().navigationBarTheme;
      expect(theme.backgroundColor, AppColors.card);
      expect(theme.indicatorColor, AppColors.backgroundDeep);
      expect(
        theme.labelBehavior,
        NavigationDestinationLabelBehavior.alwaysShow,
      );
    });
  });

  group('input decoration theme', () {
    // Regression: the app-wide filled input style once painted a solid white
    // rectangle over the OTP screen's six painted digit boxes, because that
    // screen's transparent hit-target field overrode only the borders.
    test('fills by default, which a transparent overlay field must opt out of',
        () {
      final inputTheme = buildAppTheme().inputDecorationTheme;
      expect(inputTheme.filled, isTrue,
          reason: 'ordinary fields should still get the white fill');

      const borderlessOnly = InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      );
      expect(
        borderlessOnly.applyDefaults(inputTheme).filled,
        isTrue,
        reason: 'clearing the borders alone does NOT clear the fill',
      );

      const optedOut = InputDecoration(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      );
      expect(optedOut.applyDefaults(inputTheme).filled, isFalse);
    });
  });
}
