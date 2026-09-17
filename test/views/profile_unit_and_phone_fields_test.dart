// ---------------------------------------------------------------------------
// profile_unit_and_phone_fields_test.dart
// Profile — the form must actually change shape with the unit system
// ---------------------------------------------------------------------------
//
// The reported bug, in the user's words: "the input column is always shown
// Height(cm) and Weight(Kg) no matter i switch to imperial". The labels were
// hardcoded literals, so this asserts on the rendered captions rather than on
// controller state — state was never the thing that was wrong.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/constants/country_dial_codes.dart';
import 'package:walkpenang/constants/validation_messages.dart';
import 'package:walkpenang/controllers/profile_form_fields.dart';
import 'package:walkpenang/views/widgets/body_metrics_fields.dart';
import 'package:walkpenang/views/widgets/wp_components.dart';

class _Fields extends ChangeNotifier with ProfileFormFields {
  @override
  void safeNotify() => notifyListeners();
}

void main() {
  late _Fields fields;

  setUp(() => fields = _Fields());
  tearDown(() => fields.disposeProfileFormFields());

  Future<void> pumpMetrics(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnimatedBuilder(
              animation: fields,
              builder: (_, __) => BodyMetricsFields(fields: fields),
            ),
          ),
        ),
      ),
    );
  }

  /// Pumps inside a Form that autovalidates the way both real screens do.
  Future<void> pumpMetricsInForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: AnimatedBuilder(
                animation: fields,
                builder: (_, __) => BodyMetricsFields(fields: fields),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Every error message currently rendered by a field on screen.
  ///
  /// Read off the decoration rather than via find.text, for the reason given in
  /// the header of field_error_wrapping_test.dart — what a Text widget holds
  /// and what the user can see are different questions.
  List<String> visibleErrors(WidgetTester tester) => tester
      .widgetList<TextField>(find.byType(TextField))
      .map((f) => f.decoration?.errorText)
      .whereType<String>()
      .toList();

  group('switching units does not accuse a correct field', () {
    // Both layouts open with Row[Expanded(WpField), SizedBox, Expanded(WpField)]
    // so, unkeyed, Flutter handed the metric height field's FormFieldState to
    // the imperial feet field — interaction flag and stale value included — and
    // an error appeared under boxes the tourist had filled in correctly.
    testWidgets('metric to imperial shows no error', (tester) async {
      fields.seedProfileFields(heightCm: 173, weightKg: 68, units: 'metric');
      await pumpMetricsInForm(tester);
      expect(visibleErrors(tester), isEmpty);

      fields.setUnits('imperial');
      await tester.pumpAndSettle();

      expect(visibleErrors(tester), isEmpty,
          reason: 'the converted 5 ft 8 in / 150 lb are all valid');
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('imperial back to metric shows no error', (tester) async {
      fields.seedProfileFields(
          heightCm: 172.72, weightKg: 68, units: 'imperial');
      await pumpMetricsInForm(tester);

      fields.setUnits('metric');
      await tester.pumpAndSettle();

      expect(visibleErrors(tester), isEmpty);
    });

    testWidgets('toggling repeatedly stays quiet', (tester) async {
      fields.seedProfileFields(heightCm: 173, weightKg: 68, units: 'metric');
      await pumpMetricsInForm(tester);

      for (var i = 0; i < 4; i++) {
        fields.setUnits(i.isEven ? 'imperial' : 'metric');
        await tester.pumpAndSettle();
        expect(visibleErrors(tester), isEmpty, reason: 'after toggle ${i + 1}');
      }
    });

    testWidgets('a genuinely bad value is still reported', (tester) async {
      // The fix must not silence validation altogether — typing into a field
      // is real interaction and still has to raise the error.
      fields.seedProfileFields(heightCm: 173, weightKg: 68, units: 'metric');
      await pumpMetricsInForm(tester);

      await tester.enterText(find.byType(TextFormField).first, '9999');
      await tester.pumpAndSettle();

      expect(visibleErrors(tester), contains(ValidationMessages.heightOutOfRange));
    });
  });

  group('body metric labels follow the unit system', () {
    testWidgets('metric shows centimetres and kilograms', (tester) async {
      fields.seedProfileFields(heightCm: 173, weightKg: 68, units: 'metric');
      await pumpMetrics(tester);

      // WpMonoLabel uppercases its caption.
      expect(find.text('HEIGHT (CM)'), findsOneWidget);
      expect(find.text('WEIGHT (KG)'), findsOneWidget);
      expect(find.text('HEIGHT (FT)'), findsNothing);
    });

    testWidgets('imperial relabels every box', (tester) async {
      fields.seedProfileFields(heightCm: 173, weightKg: 68, units: 'imperial');
      await pumpMetrics(tester);

      expect(find.text('HEIGHT (FT)'), findsOneWidget);
      expect(find.text('HEIGHT (IN)'), findsOneWidget);
      expect(find.text('WEIGHT (LB)'), findsOneWidget);
      // The exact symptom that was reported.
      expect(find.text('HEIGHT (CM)'), findsNothing);
      expect(find.text('WEIGHT (KG)'), findsNothing);
    });

    testWidgets('switching the dropdown relabels and reshapes live',
        (tester) async {
      fields.seedProfileFields(heightCm: 173, weightKg: 68, units: 'metric');
      await pumpMetrics(tester);

      // Two boxes in metric: height and weight.
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('173'), findsOneWidget);

      fields.setUnits('imperial');
      await tester.pumpAndSettle();

      // Three in imperial: feet, inches, weight — and the typed height has
      // been carried across rather than left sitting under a new caption.
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.text('HEIGHT (FT)'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
      expect(find.text('173'), findsNothing);
    });
  });

  group('country phone field', () {
    Future<void> pumpPhone(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: fields,
              builder: (_, __) => WpCountryPhoneField(
                label: 'contact number',
                controller: fields.phoneCtrl,
                country: fields.phoneCountry,
                onCountryChanged: fields.setPhoneCountry,
                validator: fields.validatePhone,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('defaults to Malaysia and shows its dial code',
        (tester) async {
      await pumpPhone(tester);
      expect(find.text('+60'), findsOneWidget);
    });

    testWidgets('picking a country swaps the dial code', (tester) async {
      await pumpPhone(tester);

      await tester.tap(find.text('+60'));
      await tester.pumpAndSettle();

      // The sheet's search box is the last TextField in the tree.
      await tester.enterText(find.byType(TextField).last, 'Australia');
      await tester.pumpAndSettle();

      // Target the list row specifically — the search box now holds the same
      // text, so a bare find.text would match two widgets.
      await tester.tap(find.widgetWithText(ListTile, 'Australia'));
      await tester.pumpAndSettle();

      expect(fields.phoneCountry.isoCode, 'AU');
      expect(find.text('+61'), findsOneWidget);
      expect(find.text('+60'), findsNothing);
    });

    testWidgets('the number box takes digits only', (tester) async {
      await pumpPhone(tester);

      await tester.enterText(
        find.byType(TextFormField),
        '+60 12-345 6789',
      );
      await tester.pump();

      // Formatters strip everything that is not a digit as it is typed, so
      // the stored value can never carry a dial code or separators again.
      expect(fields.phoneCtrl.text, '60123456789');
    });

    testWidgets('validation follows the chosen country', (tester) async {
      fields.setPhoneCountry(countryByIso('US'));
      await pumpPhone(tester);
      expect(fields.validatePhone('4155550100'), isNull);
    });
  });
}
