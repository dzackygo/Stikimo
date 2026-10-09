import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:stikimo/features/image_import/data/image_normalizer.dart';
import 'package:stikimo/features/image_import/domain/import_failure.dart';

void main() {
  test('preserves_png_alpha_and_leaves_source_bytes_unchanged', () {
    final fixture = image.Image(width: 3, height: 2, numChannels: 4)
      ..setPixelRgba(0, 0, 255, 40, 20, 0)
      ..setPixelRgba(1, 0, 20, 100, 200, 128)
      ..setPixelRgba(2, 0, 90, 180, 30, 255);
    final bytes = image.encodePng(fixture);
    final original = Uint8List.fromList(bytes);

    final normalized = normalizeImage(bytes);
    final decoded = image.decodePng(normalized.pngBytes)!;

    expect([normalized.width, normalized.height], [3, 2]);
    expect(decoded.numChannels, 4);
    expect(decoded.getPixel(0, 0).a, 0);
    expect(decoded.getPixel(1, 0).a, 128);
    expect(decoded.getPixel(1, 0).g, 100);
    expect(decoded.getPixel(2, 0).a, 255);
    expect(bytes, orderedEquals(original));
  });

  test('bakes_jpeg_exif_orientation_once_and_removes_metadata', () {
    final fixture = image.Image(width: 32, height: 16);
    for (final pixel in fixture) {
      pixel.setRgb(pixel.x < 16 ? 240 : 10, 15, pixel.x < 16 ? 10 : 240);
    }
    fixture.exif.imageIfd
      ..orientation = 6
      ..make = 'synthetic-test-camera';
    final bytes = image.encodeJpg(fixture, quality: 100);
    final original = Uint8List.fromList(bytes);

    final normalized = normalizeImage(bytes);
    final decoded = image.decodePng(normalized.pngBytes)!;

    expect([normalized.width, normalized.height], [16, 32]);
    expect(decoded.getPixel(8, 8).r, greaterThan(200));
    expect(decoded.getPixel(8, 24).b, greaterThan(200));
    expect(decoded.exif.isEmpty, isTrue);
    expect(_chunkTypes(normalized.pngBytes), ['IHDR', 'IDAT', 'IEND']);
    expect(bytes, orderedEquals(original));
  });

  test('strips_png_text_and_icc_metadata_from_working_image', () {
    final fixture = image.Image(width: 2, height: 2, numChannels: 4)
      ..textData = {'Comment': 'synthetic-private-metadata'}
      ..iccProfile = image.IccProfile(
        'synthetic-profile',
        image.IccProfileCompression.none,
        Uint8List.fromList([1, 2, 3, 4]),
      );
    final source = image.encodePng(fixture);
    expect(_chunkTypes(source), containsAll(['iCCP', 'tEXt']));

    final result = normalizeImage(source);
    final decoded = image.decodePng(result.pngBytes)!;

    expect(decoded.iccProfile, isNull);
    expect(decoded.textData, anyOf(isNull, isEmpty));
    expect(decoded.exif.isEmpty, isTrue);
    expect(_chunkTypes(result.pngBytes), ['IHDR', 'IDAT', 'IEND']);
  });

  test('bakes_png_exif_orientation_before_removing_exif', () {
    final fixture = image.Image(width: 2, height: 1, numChannels: 4)
      ..setPixelRgba(0, 0, 250, 10, 20, 255)
      ..setPixelRgba(1, 0, 10, 20, 250, 128);
    final png = image.encodePng(fixture);
    final source = Uint8List.fromList([
      ...png.sublist(0, 33),
      ..._chunk('eXIf', [
        0x49,
        0x49,
        42,
        0,
        8,
        0,
        0,
        0,
        1,
        0,
        0x12,
        1,
        3,
        0,
        1,
        0,
        0,
        0,
        6,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ]),
      ...png.sublist(33),
    ]);
    final result = normalizeImage(source);
    final decoded = image.decodePng(result.pngBytes)!;
    expect([result.width, result.height], [1, 2]);
    expect(decoded.getPixel(0, 0).r, 250);
    expect(decoded.getPixel(0, 1).b, 250);
    expect(decoded.getPixel(0, 1).a, 128);
    expect(_chunkTypes(result.pngBytes), ['IHDR', 'IDAT', 'IEND']);
  });

  for (final format in ['jpeg', 'png']) {
    test('resizes_large_${format}_with_aspect_ratio_preserved', () {
      final fixture = image.Image(width: 3072, height: 1536, numChannels: 4)
        ..clear(image.ColorRgba8(80, 160, 220, format == 'jpeg' ? 255 : 180));
      final bytes = format == 'jpeg'
          ? image.encodeJpg(fixture)
          : image.encodePng(fixture);

      final result = normalizeImage(bytes);
      final decoded = image.decodePng(result.pngBytes)!;

      expect([result.width, result.height], [2048, 1024]);
      expect(decoded.getPixel(100, 100).a, format == 'png' ? 180 : 255);
      expect(decoded.getPixel(100, 100).g, closeTo(160, 3));
    });
  }

  test('keeps_thin_image_dimension_at_least_one_pixel', () {
    final source = image.encodePng(image.Image(width: 8192, height: 1));
    final result = normalizeImage(source);
    expect([result.width, result.height], [2048, 1]);
  });

  test('preserves_multicolor_and_partial_alpha_regions_when_resizing_png', () {
    final fixture = image.Image(width: 3072, height: 1536, numChannels: 4)
      ..clear(image.ColorRgba8(230, 245, 235, 255));
    // Piksel eksplisit menghindari bug alphaBlend pada fillRect image4.10.1.
    for (var y = 260; y <= 1260; y++) {
      for (var x = 1700; x <= 2760; x++) {
        fixture.setPixelRgba(x, y, 240, 160, 30, 180);
      }
    }
    final bytes = image.encodePng(fixture);
    expect(image.decodePng(bytes)!.getPixel(2250, 750).a, 180);
    final output = image.decodePng(normalizeImage(bytes).pngBytes)!;
    final rectangle = output.getPixel(1500, 500);
    final background = output.getPixel(100, 100);
    expect(
      [rectangle.r, rectangle.g, rectangle.b, rectangle.a],
      [240, 160, 30, 180],
    );
    expect(
      [background.r, background.g, background.b, background.a],
      [230, 245, 235, 255],
    );
  });

  test('converts_16_bit_png_to_full_range_rgba8', () {
    final fixture = image.Image(
      width: 1,
      height: 1,
      format: image.Format.uint16,
      numChannels: 4,
    )..setPixelRgba(0, 0, 65535, 32768, 0, 32768);
    final decoded = image.decodePng(
      normalizeImage(image.encodePng(fixture)).pngBytes,
    )!;
    expect(decoded.format, image.Format.uint8);
    expect(decoded.getPixel(0, 0).r, 255);
    expect(decoded.getPixel(0, 0).g, closeTo(128, 1));
    expect(decoded.getPixel(0, 0).a, closeTo(128, 1));
  });

  test('accepts_static_adam7_png', () {
    final raw = <int>[];
    for (final (width, height) in [
      (1, 1),
      (1, 1),
      (2, 1),
      (2, 2),
      (4, 2),
      (4, 4),
      (8, 4),
    ]) {
      for (var y = 0; y < height; y++) {
        raw.add(0);
        for (var x = 0; x < width; x++) {
          raw.addAll([20, 40, 60, 128]);
        }
      }
    }
    final source = _png(width: 8, height: 8, interlace: 1, raw: raw);
    final result = normalizeImage(source);
    final pixel = image.decodePng(result.pngBytes)!.getPixel(7, 7);
    expect([pixel.r, pixel.g, pixel.b, pixel.a], [20, 40, 60, 128]);
  });

  test('reports_safe_failure_for_decoder_tiny_adam7_limitation', () {
    final source = _png(
      width: 1,
      height: 1,
      interlace: 1,
      raw: [0, 20, 40, 60, 128],
    );
    expect(() => normalizeImage(source), throwsA(isA<ImportFailure>()));
  });

  test('rejects_input_over_byte_limit_before_inspecting_contents', () {
    expect(
      () => normalizeImage(Uint8List(maxImportBytes + 1)),
      throwsA(
        isA<ImportFailure>().having(
          (e) => e.message,
          'message',
          contains('32'),
        ),
      ),
    );
  });

  for (final bytes in [
    Uint8List(0),
    Uint8List.fromList('GIF89a'.codeUnits),
    Uint8List.fromList('RIFFxxxxWEBP'.codeUnits),
    Uint8List.fromList([0xff, 0xd8, 0xff]),
    Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
  ]) {
    test(
      'rejects_unsupported_or_truncated_${bytes.length}_${bytes.firstOrNull}',
      () {
        expect(() => normalizeImage(bytes), throwsA(isA<ImportFailure>()));
      },
    );
  }

  for (final dimensions in [(8193, 1), (4000, 4001), (0, 10)]) {
    test('rejects_png_header_dimensions_${dimensions}_before_decode', () {
      final bytes = _png(width: dimensions.$1, height: dimensions.$2, raw: []);
      expect(
        () => normalizeImage(bytes),
        throwsA(
          isA<ImportFailure>().having(
            (e) => e.message,
            'message',
            contains(dimensions.$1 == 0 ? 'rusak' : 'Resolusi'),
          ),
        ),
      );
    });
    test('rejects_jpeg_header_dimensions_${dimensions}_before_decode', () {
      final bytes = Uint8List.fromList([
        0xff,
        0xd8,
        0xff,
        0xc0,
        0,
        11,
        8,
        dimensions.$2 >> 8,
        dimensions.$2 & 255,
        dimensions.$1 >> 8,
        dimensions.$1 & 255,
        1,
        1,
        0x11,
        0,
        0xff,
        0xd9,
      ]);
      expect(
        () => normalizeImage(bytes),
        throwsA(
          isA<ImportFailure>().having(
            (e) => e.message,
            'message',
            contains(dimensions.$1 == 0 ? 'rusak' : 'Resolusi'),
          ),
        ),
      );
    });
  }

  test('rejects_jpeg_invalid_sampling_and_duplicate_frame_headers', () {
    final valid = image.encodeJpg(image.Image(width: 8, height: 8));
    final start = _jpegFrameOffset(valid);
    for (final invalidSampling in [0, 0x44, 0xff]) {
      final malformed = Uint8List.fromList(valid);
      malformed[start + 11] = invalidSampling;
      expect(() => normalizeImage(malformed), throwsA(isA<ImportFailure>()));
    }
    final frameLength = ByteData.sublistView(valid).getUint16(start + 2) + 2;
    final duplicate = Uint8List.fromList([
      ...valid.sublist(0, start),
      ...valid.sublist(start, start + frameLength),
      ...valid.sublist(start),
    ]);
    expect(() => normalizeImage(duplicate), throwsA(isA<ImportFailure>()));
  });

  test('rejects_a_truncated_real_jpeg_without_returning_partial_pixels', () {
    final valid = image.encodeJpg(image.Image(width: 16, height: 16));
    expect(
      () => normalizeImage(Uint8List.sublistView(valid, 0, valid.length - 3)),
      throwsA(isA<ImportFailure>()),
    );
  });

  test('rejects_unsupported_jpeg_marker_without_decoder_recovery', () {
    final valid = image.encodeJpg(image.Image(width: 8, height: 8));
    final source = Uint8List.fromList([
      ...valid.sublist(0, 2),
      0xff,
      0xf0,
      0,
      2,
      ...valid.sublist(2),
    ]);
    expect(() => normalizeImage(source), throwsA(isA<ImportFailure>()));
  });

  test('reports_import_failure_when_jpeg_huffman_tables_are_missing', () {
    final valid = image.encodeJpg(image.Image(width: 8, height: 8));
    final data = ByteData.sublistView(valid);
    final malformed = BytesBuilder()..add(valid.sublist(0, 2));
    var offset = 2;
    while (offset < valid.length) {
      final marker = valid[offset + 1];
      if (marker == 0xda) {
        malformed.add(valid.sublist(offset));
        break;
      }
      final end = offset + 2 + data.getUint16(offset + 2);
      if (marker != 0xc4) malformed.add(valid.sublist(offset, end));
      offset = end;
    }
    expect(
      () => normalizeImage(malformed.takeBytes()),
      throwsA(isA<ImportFailure>()),
    );
  });

  for (final afterScan in [false, true]) {
    test('strips_cyclic_jpeg_exif_${afterScan ? 'after' : 'before'}_scan', () {
      final valid = image.encodeJpg(image.Image(width: 8, height: 4));
      // IFD 8 -> 14 -> 8: decoder package akan berulang tanpa batas jika APP1
      // sumber diteruskan. Normalizer hanya membaca orientasi IFD pertama.
      final cyclicExif = [
        0x45,
        0x78,
        0x69,
        0x66,
        0,
        0,
        0x49,
        0x49,
        42,
        0,
        8,
        0,
        0,
        0,
        0,
        0,
        14,
        0,
        0,
        0,
        0,
        0,
        8,
        0,
        0,
        0,
      ];
      final offset = afterScan ? valid.length - 2 : 2;
      final source = Uint8List.fromList([
        ...valid.sublist(0, offset),
        0xff,
        0xe1,
        0,
        cyclicExif.length + 2,
        ...cyclicExif,
        ...valid.sublist(offset),
      ]);
      final result = normalizeImage(source);
      expect([result.width, result.height], [8, 4]);
      expect(_chunkTypes(result.pngBytes), ['IHDR', 'IDAT', 'IEND']);
    });
  }

  test('rejects_apng_even_when_animation_has_only_one_frame', () {
    final source = _png(
      width: 1,
      height: 1,
      raw: [0, 0, 0, 0, 0],
      animation: true,
    );
    expect(
      () => normalizeImage(source),
      throwsA(
        isA<ImportFailure>().having(
          (e) => e.message,
          'message',
          contains('animasi'),
        ),
      ),
    );
  });

  test('rejects_png_deflate_output_larger_than_claimed_dimensions', () {
    final source = _png(width: 1, height: 1, raw: Uint8List(8 * 1024 * 1024));
    expect(source.length, lessThan(10000));
    expect(() => normalizeImage(source), throwsA(isA<ImportFailure>()));
  });

  test('rejects_png_crc_corruption_and_missing_pixel_bytes', () {
    final source = _png(width: 1, height: 1, raw: [0, 1, 2, 3]);
    expect(() => normalizeImage(source), throwsA(isA<ImportFailure>()));
    final brokenCrc = _png(width: 1, height: 1, raw: [0, 1, 2, 3, 4]);
    brokenCrc[brokenCrc.length - 1] ^= 1;
    expect(() => normalizeImage(brokenCrc), throwsA(isA<ImportFailure>()));
  });
}

int _jpegFrameOffset(Uint8List bytes) {
  for (var i = 2; i + 1 < bytes.length; i++) {
    if (bytes[i] == 0xff && bytes[i + 1] == 0xc0) return i;
  }
  throw StateError('Fixture JPEG tidak memiliki baseline frame.');
}

List<String> _chunkTypes(Uint8List bytes) {
  final types = <String>[];
  final data = ByteData.sublistView(bytes);
  for (var offset = 8; offset + 12 <= bytes.length;) {
    types.add(String.fromCharCodes(bytes.sublist(offset + 4, offset + 8)));
    offset += 12 + data.getUint32(offset);
  }
  return types;
}

Uint8List _png({
  required int width,
  required int height,
  required List<int> raw,
  int interlace = 0,
  bool animation = false,
}) {
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 6)
    ..setUint8(12, interlace);
  return (BytesBuilder()
        ..add([137, 80, 78, 71, 13, 10, 26, 10])
        ..add(_chunk('IHDR', header.buffer.asUint8List()))
        ..add(animation ? _chunk('acTL', [0, 0, 0, 1, 0, 0, 0, 0]) : [])
        ..add(_chunk('IDAT', ZLibEncoder().convert(raw)))
        ..add(_chunk('IEND', [])))
      .takeBytes();
}

List<int> _chunk(String type, List<int> payload) {
  final body = [...type.codeUnits, ...payload];
  var crc = 0xffffffff;
  for (final byte in body) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc >> 1) ^ ((crc & 1) != 0 ? 0xedb88320 : 0);
    }
  }
  return [
    ...(ByteData(4)..setUint32(0, payload.length)).buffer.asUint8List(),
    ...body,
    ...(ByteData(4)..setUint32(0, crc ^ 0xffffffff)).buffer.asUint8List(),
  ];
}
