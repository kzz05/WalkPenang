// ---------------------------------------------------------------------------
// field_error_wrapping_test.dart
// Forms — validation messages must be readable, not just correct
// ---------------------------------------------------------------------------
//
// The bug this guards: WpField never set errorMaxLines, and Flutter defaults it
// to 1. Height and weight sit in Expanded halves of a Row, so
// "Height must be between 50-250 cm" rendered as "Height must be be…". The
// validation was working perfectly; the user just could not read what rule they
// had broken.
//
// Note on how this is asserted. `find.text(message)` would NOT catch it — an
// ellipsis is a painting decision, so the Text widget's `data` is the full
// string either way and the finder passes on a clipped field. The decoration
// has to be read directly. That is the whole reason this file exists rather
// than a simpler-looking assertion.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/constants/validation_messages.dart';
import 'package:walkpenang/utils/validators.dart';
import 'package:walkpenang/views/widgets/wp_components.dart';

void main() {
  /// The longest messages in the app, and the ones on the narrowest fields.
  /// If someone adds a longer message later, this is where to add it.
  const List<String> longestMessages = <String>[
    ValidationMessages.phoneInvalid,
    ValidationMessages.heightOutOfRange,
    ValidationMessages.weightOutOfRange,
    ValidationMessages.nicknameInvalid,
    ValidationMessages.nicknameProfane,
    ValidationMessages.emailInvalid,
  ];

  Future<InputDecoration> decorationOf(
    WidgetTester tester,
    Widget field,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Form(child: field))),
    );
    final TextField rendered = tester.widget<TextField>(find.byType(TextField));
    return rendered.decoration!;
  }

  group('WpField gives error messages room to wrap', () {
    testWidgets('errorMaxLines is set above 1', (WidgetTester tester) async {
      final InputDecoration decoration = await decorationOf(
        tester,
        WpField(
          label: 'height',
          controller: TextEditingController(),
          validator: Validators.heightCm,
        ),
      );

      expect(
        decoration.errorMaxLines,
        isNotNull,
        reason: 'null means Flutter uses its default of 1, which clips every '
            'message longer than the field',
      );
      expect(decoration.errorMaxLines, greaterThan(1));
    });

    testWidgets('a half-width field can show the full range message',
        (WidgetTester tester) async {
      // Reproduces the reported layout: two fields sharing a Row, so each is
      // about half the screen — the case where clipping was visible.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: WpField(
                      label: 'height',
                      controller: TextEditingController(text: '-170'),
                      validator: Validators.heightCm,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: WpField(
                      label: 'weight',
                      controller: TextEditingController(text: '-70'),
                      validator: Validators.weightKg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final FormState form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isFalse, reason: 'negatives must be rejected');
      await tester.pump();

      expect(find.text(ValidationMessages.heightOutOfRange), findsOneWidget);
      expect(find.text(ValidationMessages.weightOutOfRange), findsOneWidget);

      for (final TextField field
          in tester.widgetList<TextField>(find.byType(TextField))) {
        expect(field.decoration!.errorMaxLines, greaterThan(1));
      }
    });

    testWidgets('every long message fits within the allowed lines',
        (WidgetTester tester) async {
      // A rough character budget rather than a pixel measurement: at the error
      // text size a half-width field holds roughly 28 characters per line, and
      // this is the narrowest case in the app.
      const int charsPerLineHalfWidth = 28;

      final InputDecoration decoration = await decorationOf(
        tester,
        WpField(
          label: 'phone',
          controller: TextEditingController(),
          validator: Validators.phone,
        ),
      );
      final int allowed = decoration.errorMaxLines! * charsPerLineHalfWidth;

      for (final String message in longestMessages) {
        expect(
          message.length,
          lessThanOrEqualTo(allowed),
          reason: '"$message" is ${message.length} chars, which will not fit '
              'in ${decoration.errorMaxLines} lines of a narrow field. Either '
              'shorten the message or raise errorMaxLines.',
        );
      }
    });
  });
}
