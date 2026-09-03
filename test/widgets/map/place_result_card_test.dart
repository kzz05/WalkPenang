// [PlaceResultCard] is the single widget behind every place card on the home
// map — the strip's PageView.builder renders this one class repeatedly — so an
// overflow in it shows up on every card at once, which is exactly how it was
// reported.
//
// It shipped overflowing its box by 18px at the *default* font size on every
// phone width, plus a right-edge overflow that grew with the system font. Both
// came from the same cause: fixed-size children in a Row/Column that had no
// way to give way. The matrix below is the guard.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/models/place_model.dart';
import 'package:walkpenang/theme/app_theme.dart';
import 'package:walkpenang/widgets/map/place_result_card.dart';

/// Mirrors `_MapPanelState._resultsStripHeight`. If that formula changes and
/// this is not updated, the matrix below starts failing — which is the point:
/// the strip and the card have to agree on how tall the card is allowed to be.
double _stripHeight(double textScale) => 124 + 60 * textScale;

PlaceModel _place({double? rating, bool openNow = true}) => PlaceModel(
      placeId: 'p1',
      // Deliberately long: the two-line name is the tallest thing on the card.
      name: 'Penang Road Famous Teochew Chendul Original',
      category: 'attraction',
      latitude: 5.418,
      longitude: 100.332,
      rating: rating,
      address: 'Lebuh Keng Kwee, George Town',
      isOpenNow: openNow,
    );

/// Lays the card out in exactly the box `_ResultsStrip` gives it: the strip's
/// height, a 0.78 viewport fraction of the screen, and the strip's padding.
Widget _inStrip(Widget card, double screenWidth, double textScale) {
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: _stripHeight(textScale),
            child: SizedBox(
              width: screenWidth * 0.78,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: card,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _card({double? rating = 4.3, bool routed = false}) => PlaceResultCard(
      place: _place(rating: rating),
      distanceMeters: 1480,
      isSelected: true,
      isRouted: routed,
      isFavorite: true,
      onToggleFavorite: () {},
      onRoute: () {},
    );

void main() {
  // 320dp is the narrowest Android width worth supporting and 1.6x is the
  // largest non-accessibility font setting, so that corner has to hold; 2.0x
  // is included because the accessibility sizes go there and a red overflow
  // stripe is the worst possible answer for someone who needs large text.
  const widths = [320.0, 360.0, 412.0];
  const scales = [1.0, 1.15, 1.3, 1.6, 2.0];

  for (final width in widths) {
    for (final scale in scales) {
      for (final rating in <double?>[4.3, null]) {
        final label = '${width.toInt()}dp @${scale}x'
            '${rating == null ? ' (unrated)' : ''}';

        testWidgets('does not overflow at $label', (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final overflows = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) {
            final dump = details.toString();
            if (!dump.contains('overflowed')) {
              previous?.call(details);
              return;
            }
            final where = dump.split('\n').firstWhere(
                  (line) => line.contains('.dart:'),
                  orElse: () => '?',
                );
            overflows.add('${details.exceptionAsString().split('\n').first}  @ '
                '${where.trim()}');
          };

          await tester.pumpWidget(
            _inStrip(_card(rating: rating), width, scale),
          );
          await tester.pump();

          FlutterError.onError = previous;
          expect(overflows, isEmpty, reason: overflows.join('\n'));
        });
      }
    }
  }

  testWidgets('the card fits inside the height the strip allots it',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_inStrip(_card(), 360, 1.0));

    // 24 is the strip's own 8 top + 16 bottom padding.
    final double allotted = _stripHeight(1.0) - 24;
    expect(
      tester.getSize(find.byType(PlaceResultCard)).height,
      lessThanOrEqualTo(allotted),
    );
  });

  testWidgets('a routed card is grey, an unrouted one is not', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Color fillOf(WidgetTester t) {
      final container = t.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(PlaceResultCard),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return ((container.decoration as BoxDecoration).color)!;
    }

    await tester.pumpWidget(_inStrip(_card(), 360, 1.0));
    expect(fillOf(tester), Colors.white);

    await tester.pumpWidget(_inStrip(_card(routed: true), 360, 1.0));
    await tester.pumpAndSettle();
    expect(fillOf(tester), AppColors.routedSurface);
  });
}
