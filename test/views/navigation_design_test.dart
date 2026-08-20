import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/theme/app_theme.dart';

/// The shared navigation-bar theme, and the input-theme trap that hid the
/// OTP boxes.
void main() {
  // buildAppTheme() resolves google_fonts, which reads the asset bundle and
  // so needs a binding. It used to be initialised as a side effect of the
  // testWidgets cases that pumped WpBottomNav; those are gone with the
  // widget, so the dependency is now stated rather than inherited.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('navigation bar theme', () {
    // testWidgets, not test: buildAppTheme() resolves google_fonts, which
    // attempts a font fetch. The widget-test binding stubs HTTP so the
    // lookup fails closed to the bundled fallback; a plain test lets the
    // exception escape.
    testWidgets('the shared theme still supplies the Discovery bar its colours',
        (tester) async {
      // WpBottomNav is gone — HomeView replaced it with WpTabSheet, and the
      // map got the bottom of the screen back. The theme is still live
      // though: main_discovery.dart's standalone shell builds a NavigationBar
      // and sets no colours of its own, so these values are what it renders.
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
