import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final lossless in [true, false]) {
    test(
      'webp_${lossless ? 'lossless' : 'lossy'}_preserves_alpha_in_engine',
      () async {
        final fixture = image.Image(width: 16, height: 16, numChannels: 4);
        fixture.setPixelRgba(8, 8, 240, 60, 30, 255);
        fixture.setPixelRgba(8, 9, 240, 60, 30, 128);
        final encoded = image.encodeWebP(
          fixture,
          singleFrame: true,
          lossless: lossless,
          alphaQuality: 100,
        );

        expect(String.fromCharCodes(encoded.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(encoded.sublist(8, 12)), 'WEBP');
        final codec = await ui.instantiateImageCodec(encoded);
        try {
          expect(codec.frameCount, 1);
          final frame = await codec.getNextFrame();
          try {
            expect(frame.image.width, 16);
            expect(frame.image.height, 16);
            final rgba = await frame.image.toByteData(
              format: ui.ImageByteFormat.rawStraightRgba,
            );
            expect(rgba, isNotNull);
            expect(rgba!.getUint8(3), 0);
            expect(rgba.getUint8((8 * 16 + 8) * 4 + 3), 255);
            expect(rgba.getUint8((9 * 16 + 8) * 4 + 3), 128);
            if (lossless) {
              expect(rgba.getUint8((8 * 16 + 8) * 4), 240);
            }
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      },
    );
  }
}
