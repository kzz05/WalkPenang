// [PlaceResultCard] is the single widget behind every place card on the home
// map — the strip's PageView.builder renders this one class repeatedly — so an
// overflow in it shows up on every card at once, which is exactly how it was
// reported.
//
// It shipped overflowing its box by 18px at the *default* font size on every
// phone width, plus a right-edge overflow that grew with the system font. Both
// came from the same cause: fixed-size children in a Row/Column that had no
// way to give way.
//
// It then shipped a *second* overflow — 26px on the bottom at the largest
// system font — which this file could not see, because it drove the matrix
// with TextScaler.linear while the phone scales fonts on a curve. The two
// additions that close that gap:
//
//   * [_AndroidFontCurve], a scaler that compresses large sizes the way
//     Android 14+ does, so the matrix runs against something shaped like a
//     real device rather than a straight line; and
//   * 'the height budget clears the card it is measuring', which checks
//     PlaceResultCard.heightFor against the card's *measured* height instead
//     of against a second copy of the formula. The old mirror of the formula
//     agreed with the strip by construction and so could never fail.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/models/place_model.dart';
import 'package:walkpenang/theme/app_theme.dart';
import 'package:walkpenang/widgets/map/place_result_card.dart';

/// Android 14+ does not scale every font size by the same factor: it
/// interpolates on a curve that leaves large text nearly untouched while small
/// text scales close to linearly. A 60px value at the largest setting came
/// back off a real SM-A176B as 61 — no growth at all — while the card's 10-15px
/// text grew by about half again. This reproduces that shape: sizes at or
/// below 20 scale linearly, and the factor falls away to nothing by 60.
class _AndroidFontCurve extends TextScaler {
  const _AndroidFontCurve(this.textScaleFactor);

  @override
  final double textScaleFactor;

  @override
  double scale(double fontSize) {
    final double compressed = ((fontSize - 20) / 40).clamp(0.0, 1.0);
    return fontSize * (1 + (textScaleFactor - 1) * (1 - compressed));
  }
}

/// What the strip actually gives a card: the card's own budget plus the
/// strip's 8 top and 16 bottom padding. Taken from the widget rather than
/// restated, so this file cannot drift away from the layout again.
double _stripHeight(TextScaler scaler) =>
    PlaceResultCard.heightFor(scaler) + 24;

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
Widget _inStrip(Widget card, double screenWidth, TextScaler scaler) {
  return MediaQuery(
    data: MediaQueryData(textScaler: scaler),
    child: MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: _stripHeight(scaler),
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

/// Collects RenderFlex overflows raised while [body] runs.
Future<List<String>> _overflowsDuring(Future<void> Function() body) async {
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
    overflows.add(
      '${details.exceptionAsString().split('\n').first}  @ ${where.trim()}',
    );
  };
  await body();
  FlutterError.onError = previous;
  return overflows;
}

void main() {
  // 320dp is the narrowest Android width worth supporting and 1.6x is the
  // largest non-accessibility font setting, so that corner has to hold; 2.0x
  // is included because the accessibility sizes go there and a red overflow
  // stripe is the worst possible answer for someone who needs large text.
  const widths = [320.0, 360.0, 412.0];
  const factors = [1.0, 1.15, 1.3, 1.6, 2.0];

  // Both shapes of scaler. The linear one is what a desktop or a pre-Android-14
  // phone does; the curve is what the test device does, and is the one that
  // caught the 26px bottom overflow.
  final scalers = <String, TextScaler Function(double)>{
    'linear': TextScaler.linear,
    'android-curve': _AndroidFontCurve.new,
  };

  for (final entry in scalers.entries) {
    for (final width in widths) {
      for (final factor in factors) {
        for (final rating in <double?>[4.3, null]) {
          final label = '${width.toInt()}dp @${factor}x ${entry.key}'
              '${rating == null ? ' (unrated)' : ''}';

          testWidgets('does not overflow at $label', (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            final scaler = entry.value(factor);
            final overflows = await _overflowsDuring(() async {
              await tester.pumpWidget(
                _inStrip(_card(rating: rating), width, scaler),
              );
              await tester.pump();
            });

            expect(overflows, isEmpty, reason: overflows.join('\n'));
          });
        }
      }
    }
  }

  // The check the old mirror could not make. `heightFor` is compared against
  // the height the card actually takes when nothing constrains it, so if the
  // card gains a row — or AppType's sizes move — this fails instead of the
  // card quietly overflowing on a phone.
  for (final entry in scalers.entries) {
    for (final factor in factors) {
      testWidgets(
        'the height budget clears the card it is measuring '
        '@${factor}x ${entry.key}',
        (tester) async {
          tester.view.physicalSize = const Size(360, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final scaler = entry.value(factor);

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(textScaler: scaler),
              child: MaterialApp(
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    // Unbounded vertically, so the card reports the height it
                    // actually wants rather than the one it was handed.
                    child: SizedBox(
                      width: 360 * 0.78 - 24,
                      child: _card(),
                    ),
                  ),
                ),
              ),
            ),
          );

          final natural = tester.getSize(find.byType(PlaceResultCard)).height;
          expect(
            PlaceResultCard.heightFor(scaler),
            greaterThanOrEqualTo(natural),
            reason: 'budget ${PlaceResultCard.heightFor(scaler)} is under the '
                "card's natural height $natural — the strip would hand it a "
                'box too small and the action row would fall outside it',
          );
        },
      );
    }
  }

  // The overflow did not merely look wrong: the action row was pushed outside
  // the Column's bounds, and Flutter does not hit-test what falls outside a
  // parent, so Route stopped responding at the largest system font. This is
  // that symptom, not the stripe.
  testWidgets('Route stays tappable even when the strip under-measures',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var routed = 0;
    const scaler = _AndroidFontCurve(1.6);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: scaler),
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                // Deliberately 40px under budget — the situation the old
                // formula created. The card must absorb it, not spill.
                height: _stripHeight(scaler) - 40,
                child: SizedBox(
                  width: 360 * 0.78,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    child: PlaceResultCard(
                      place: _place(rating: 4.3),
                      distanceMeters: 1480,
                      isSelected: true,
                      isRouted: false,
                      isFavorite: true,
                      onToggleFavorite: () {},
                      onRoute: () => routed++,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Route'));
    await tester.pump();
    expect(routed, 1);
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

    await tester.pumpWidget(_inStrip(_card(), 360, TextScaler.noScaling));
    expect(fillOf(tester), Colors.white);

    await tester.pumpWidget(
      _inStrip(_card(routed: true), 360, TextScaler.noScaling),
    );
    await tester.pumpAndSettle();
    expect(fillOf(tester), AppColors.routedSurface);
  });
}
