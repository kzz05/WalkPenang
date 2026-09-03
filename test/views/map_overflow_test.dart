// Regression cover for the two RenderFlex overflows the map screen shipped
// with, both plain Rows that had nowhere to put their excess width:
//   - the radius chips           (map_view.dart, "overflowed by 18 pixels")
//   - the labelled map pill      (map_action_button.dart, "by 30 pixels")
//
// Neither showed up at the default font size on a wide phone, which is why
// they survived to a device: the matrix below has to reach the corner (narrow
// screen AND a large system font), not just the middle of it.
//
// The screen is pumped with no platform plugins available, so location fails
// and the map settles into its message-banner state — which is the layout
// that was overflowing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/views/map_view.dart';

void main() {
  // 320 is the narrowest Android width still worth supporting; 1.6x is
  // Android's largest non-accessibility font setting.
  const sizes = [Size(320, 640), Size(360, 800), Size(412, 915)];
  const scales = [1.0, 1.3, 1.6];

  for (final size in sizes) {
    for (final scale in scales) {
      final label = '${size.width.toInt()}x${size.height.toInt()} @${scale}x';

      testWidgets('map screen does not overflow at $label', (tester) async {
        tester.view.physicalSize = size;
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
          final where = dump
              .split('\n')
              .firstWhere((line) => line.contains('.dart:'), orElse: () => '?');
          overflows.add('${details.exceptionAsString().split('\n').first}  @ '
              '${where.trim()}');
        };

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const MaterialApp(home: MapView()),
          ),
        );
        // Long enough for loadMap to fall through to its message state and for
        // the marker bitmaps to finish rasterising.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        FlutterError.onError = previous;
        expect(overflows, isEmpty, reason: overflows.join('\n'));
      });
    }
  }
}
