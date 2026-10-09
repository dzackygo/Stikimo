import 'dart:io';

import 'package:image/image.dart' as image;

/// Fixture sintetis lokal untuk pengujian Photo Picker Android, tanpa foto privat.
void main() {
  final output = Directory('build/verification/import-fixtures')
    ..createSync(recursive: true);
  final fixture = image.Image(width: 3072, height: 1536, numChannels: 4)
    ..clear(image.ColorRgba8(230, 245, 235, 255));
  image.fillCircle(
    fixture,
    x: 768,
    y: 768,
    radius: 540,
    color: image.ColorRgba8(0, 108, 96, 255),
  );
  image.fillRect(
    fixture,
    x1: 1700,
    y1: 260,
    x2: 2760,
    y2: 1260,
    color: image.ColorRgba8(240, 160, 30, 180),
    alphaBlend: false,
  );
  if (fixture.getPixel(2250, 750).a != 180) {
    throw StateError('Fixture harus memiliki alpha 180 pada persegi.');
  }
  File('${output.path}/stikimo-large.png')
      .writeAsBytesSync(image.encodePng(fixture));
  fixture.exif.imageIfd.orientation = 6;
  File('${output.path}/stikimo-rotated.jpg')
      .writeAsBytesSync(image.encodeJpg(fixture, quality: 90));
}
