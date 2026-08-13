import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/constants/validation_messages.dart';
import 'package:walkpenang/models/password_strength.dart';
import 'package:walkpenang/theme/app_theme.dart';
import 'package:walkpenang/utils/validators.dart';
import 'package:walkpenang/views/widgets/wp_components.dart';

/// The strength meter widget, and the as-you-type wiring it sits beside.
void main() {
  Future<void> pumpMeter(WidgetTester tester, String password) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WpPasswordStrengthMeter(
            strength: PasswordStrength.of(password),
          ),
        ),
      ),
    );
  }

  /// Ticked requirements are drawn with a filled check icon.
  int tickCount(WidgetTester tester) =>
      tester.widgetList(find.byIcon(Icons.check_circle)).length;

  group('WpPasswordStrengthMeter', () {
    testWidgets('shows no caption and no ticks before anything is typed',
            (tester) async {
          await pumpMeter(tester, '');

          expect(tickCount(tester), 0);
          expect(find.text(ValidationMessages.strengthWeak.toUpperCase()),
              findsNothing);
          // The recommendation nudge is visible from the start.
          expect(find.text(ValidationMessages.strengthHint.toUpperCase()),
              findsOneWidget);
        });

    testWidgets('lists every requirement as an unticked pip', (tester) async {
      await pumpMeter(tester, '');

      expect(find.byIcon(Icons.circle_outlined), findsNWidgets(4));
      expect(find.text(ValidationMessages.requirementLength.toUpperCase()),
          findsOneWidget);
      expect(find.text(ValidationMessages.requirementCases.toUpperCase()),
          findsOneWidget);
      expect(find.text(ValidationMessages.requirementDigit.toUpperCase()),
          findsOneWidget);
      expect(find.text(ValidationMessages.requirementSymbol.toUpperCase()),
          findsOneWidget);
    });

    testWidgets('ticks requirements as they are satisfied', (tester) async {
      await pumpMeter(tester, 'abcdefgh');
      expect(tickCount(tester), 1);

      await pumpMeter(tester, 'Abcdefgh');
      expect(tickCount(tester), 2);

      await pumpMeter(tester, 'Abcd1234');
      expect(tickCount(tester), 3);

      await pumpMeter(tester, 'Abcd123!');
      expect(tickCount(tester), 4);
    });

    testWidgets('captions weak / fair / good / strong', (tester) async {
      Future<void> expectCaption(String password, String caption) async {
        await pumpMeter(tester, password);
        expect(find.text(caption.toUpperCase()), findsOneWidget,
            reason: 'expected "$caption" for "$password"');
      }

      await expectCaption('abc', ValidationMessages.strengthWeak);
      await expectCaption('Abcd1234', ValidationMessages.strengthFair);
      await expectCaption('Abcd123!', ValidationMessages.strengthGood);
      await expectCaption('Penang2026!Walk', ValidationMessages.strengthStrong);
    });

    testWidgets('retires the length nudge once the password is strong',
            (tester) async {
          await pumpMeter(tester, 'Abcd123!');
          expect(find.text(ValidationMessages.strengthHint.toUpperCase()),
              findsOneWidget);

          await pumpMeter(tester, 'Penang2026!Walk');
          expect(
              find.text(ValidationMessages.strengthHint.toUpperCase()), findsNothing);
        });

    testWidgets('colours the filled segments by level', (tester) async {
      Color? fillOf(WidgetTester tester, int index) {
        final container = tester.widgetList<AnimatedContainer>(
          find.byType(AnimatedContainer),
        ).elementAt(index);
        return (container.decoration as BoxDecoration?)?.color;
      }

      await pumpMeter(tester, 'abc');
      expect(fillOf(tester, 0), AppColors.danger);
      // Unreached segments stay on the neutral track colour.
      expect(fillOf(tester, 3), AppColors.placeholder);

      await pumpMeter(tester, 'Abcd1234');
      expect(fillOf(tester, 0), AppColors.warning);

      await pumpMeter(tester, 'Penang2026!Walk');
      expect(fillOf(tester, 3), AppColors.success);
    });
  });

  group('live validation', () {
    testWidgets('a Form on onUserInteraction shows errors while typing',
            (tester) async {
          final controller = TextEditingController();
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Form(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: WpField(
                    label: 'email address',
                    controller: controller,
                    validator: Validators.email,
                  ),
                ),
              ),
            ),
          );

          // Untouched: no error, even though the field is empty and invalid.
          expect(find.text(ValidationMessages.emailInvalid), findsNothing);
          expect(find.text(ValidationMessages.emailRequired), findsNothing);

          await tester.enterText(find.byType(TextFormField), 'ian@');
          await tester.pump();
          expect(find.text(ValidationMessages.emailInvalid), findsOneWidget);

          await tester.enterText(find.byType(TextFormField), 'ian@gmail.com');
          await tester.pump();
          expect(find.text(ValidationMessages.emailInvalid), findsNothing);
        });
  });
}
