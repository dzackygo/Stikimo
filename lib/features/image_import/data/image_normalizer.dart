import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;

import '../domain/import_failure.dart';
import '../domain/normalized_image.dart';

/// Batas sumber; pembaca file juga memakai batas ini sebelum membuat isolate.
const maxImportBytes = 32 * 1024 * 1024;
const maxImportPixels = 16000000;
const maxImportEdge = 8192;
const maxWorkingEdge = 2048;

const _invalid = ImportFailure(
  'Gambar rusak atau tidak dapat dibaca. Pilih gambar lain.',
);
const _tooLarge = ImportFailure(
  'Resolusi gambar terlalu besar. Perkecil hingga 16 MP dan sisi maksimal 8192 piksel.',
);
const _animated = ImportFailure(
  'Gambar animasi belum didukung. Pilih JPEG atau PNG statis.',
);
const _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

/// Menghasilkan salinan PNG RGBA tanpa metadata, tanpa mengubah [bytes].
///
/// Pemanggil menjalankan fungsi sinkron ini di isolate. Batas input membatasi
/// pekerjaan decoder, tetapi bukan jaminan memori perangkat selalu mencukupi.
NormalizedImage normalizeImage(Uint8List bytes) {
  if (bytes.length > maxImportBytes) {
    throw const ImportFailure(
      'Ukuran gambar maksimal 32 MiB. Pilih file yang lebih kecil.',
    );
  }
  try {
    image.Image? decoded;
    if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xd8) {
      final safeJpeg = _checkJpeg(bytes);
      // JpegDecoder.startDecode juga mengalokasikan blok DCT. Pemeriksaan
      // manual menghindari alokasi tersebut sebelum dimensi dibatasi.
      // decodeJpg sudah menerapkan EXIF orientation dan menghapus tag itu.
      try {
        decoded = image.decodeJpg(safeJpeg);
      } on Error {
        // JPEG tanpa tabel Huffman memicu LateInitializationError di codec.
        // Kesalahan dari data decoder tetap diterjemahkan ke domain impor.
        throw _invalid;
      }
    } else if (_isPng(bytes)) {
      final (safePng, orientation) = _checkPng(bytes);
      final decoder = image.PngDecoder();
      final info = decoder.startDecode(safePng);
      if (info == null) throw _invalid;
      _checkDimensions(info.width, info.height);
      decoded = decoder.decodeFrame(0);
      if (decoded != null && orientation != 1) {
        decoded.exif.imageIfd.orientation = orientation;
        decoded = image.bakeOrientation(decoded);
      }
    } else {
      throw const ImportFailure(
        'Format tidak didukung. Pilih gambar JPEG atau PNG statis.',
      );
    }
    if (decoded == null) throw _invalid;
    _checkDimensions(decoded.width, decoded.height);
    final longest = math.max(decoded.width, decoded.height);
    if (longest > maxWorkingEdge) {
      decoded = image.copyResize(
        decoded,
        width: math.max(1, (decoded.width * maxWorkingEdge / longest).round()),
        height: math.max(
          1,
          (decoded.height * maxWorkingEdge / longest).round(),
        ),
        interpolation: image.Interpolation.average,
      );
    }
    // convert mengubah rentang 16-bit/palette secara benar, tetapi masih
    // menyalin metadata. Image baru dari piksel saja menghapus semua metadata.
    final rgba = decoded
        .convert(format: image.Format.uint8, numChannels: 4, withPalette: false)
        .getBytes(order: image.ChannelOrder.rgba);
    final clean = image.Image.fromBytes(
      width: decoded.width,
      height: decoded.height,
      bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes,
      numChannels: 4,
      order: image.ChannelOrder.rgba,
    );
    return NormalizedImage(
      pngBytes: image.encodePng(clean),
      width: clean.width,
      height: clean.height,
    );
  } on ImportFailure {
    rethrow;
  } on Exception {
    throw _invalid;
  } on RangeError {
    // Decoder dapat melempar RangeError untuk buffer yang terpotong.
    throw _invalid;
  } on ArgumentError {
    throw _invalid;
  }
}

void _checkDimensions(int width, int height) {
  if (width <= 0 || height <= 0) throw _invalid;
  if (width > maxImportEdge ||
      height > maxImportEdge ||
      width * height > maxImportPixels) {
    throw _tooLarge;
  }
}

Uint8List _checkJpeg(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final clean = BytesBuilder()..add([0xff, 0xd8]);
  var offset = 2;
  var hasFrame = false;
  var hasScan = false;
  int? orientation;
  while (offset < bytes.length) {
    final start = offset;
    if (bytes[offset++] != 0xff) throw _invalid;
    while (offset < bytes.length && bytes[offset] == 0xff) {
      offset++;
    }
    if (offset >= bytes.length) throw _invalid;
    final marker = bytes[offset++];
    if (marker == 0xd9) {
      if (!hasFrame || !hasScan || offset != bytes.length) throw _invalid;
      clean.add(Uint8List.sublistView(bytes, start, offset));
      final jpeg = clean.takeBytes();
      if (orientation == null || orientation == 1) return jpeg;
      // Sisakan hanya tag orientasi yang tervalidasi. Decoder JPEG menerapkan
      // rotasi saat membangun raster, tanpa membaca pointer EXIF sumber.
      return (BytesBuilder()
            ..add([0xff, 0xd8])
            ..add(_jpegOrientation(orientation))
            ..add(Uint8List.sublistView(jpeg, 2)))
          .takeBytes();
    }
    // Hanya struktur JPEG yang didukung diteruskan. Decoder mencoba recovery
    // untuk marker asing; kebijakan impor menolaknya secara deterministik.
    if (!const [
          0xc0,
          0xc1,
          0xc2,
          0xc4,
          0xdb,
          0xdd,
          0xda,
          0xfe,
        ].contains(marker) &&
        !(marker >= 0xe0 && marker <= 0xef)) {
      throw _invalid;
    }
    if (offset + 2 > bytes.length) throw _invalid;
    final length = data.getUint16(offset);
    if (length < 2 || offset + length > bytes.length) throw _invalid;
    if (marker == 0xc0 || marker == 0xc1 || marker == 0xc2) {
      if (hasFrame || length < 11 || bytes[offset + 2] != 8) throw _invalid;
      final height = data.getUint16(offset + 3);
      final width = data.getUint16(offset + 5);
      _checkDimensions(width, height);
      final components = bytes[offset + 7];
      if (![1, 3, 4].contains(components) || length != 8 + components * 3) {
        throw _invalid;
      }
      final ids = <int>{};
      var sampleCount = 0;
      for (var i = 0; i < components; i++) {
        final position = offset + 8 + i * 3;
        final horizontal = bytes[position + 1] >> 4;
        final vertical = bytes[position + 1] & 15;
        if (!ids.add(bytes[position]) ||
            horizontal < 1 ||
            horizontal > 4 ||
            vertical < 1 ||
            vertical > 4 ||
            bytes[position + 2] > 3) {
          throw _invalid;
        }
        sampleCount += horizontal * vertical;
      }
      if (sampleCount > 10) throw _invalid;
      hasFrame = true;
    }
    if (marker == 0xe1) {
      final payload = offset + 2;
      if (length >= 8 &&
          data.getUint32(payload) == 0x45786966 &&
          data.getUint16(payload + 4) == 0) {
        if (orientation != null) throw _invalid;
        orientation = _readTiffOrientation(
          Uint8List.sublistView(bytes, payload + 6, offset + length),
        );
      }
      // Seluruh APP1 (EXIF/XMP) dihapus, termasuk yang berada antar-scan.
      // Parser EXIF package mengikuti IFD siklik tanpa batas; jangan diteruskan.
    } else {
      clean.add(Uint8List.sublistView(bytes, start, offset + length));
    }
    if (marker == 0xda) {
      if (!hasFrame) throw _invalid;
      hasScan = true;
      final scanStart = offset + length;
      offset = scanStart;
      // Lewati byte entropy, FF00 stuffing, dan marker restart; header marker
      // berikutnya tetap diperiksa, sehingga metadata setelah SOS juga aman.
      while (offset < bytes.length) {
        if (bytes[offset] != 0xff) {
          offset++;
          continue;
        }
        final markerStart = offset;
        while (offset < bytes.length && bytes[offset] == 0xff) {
          offset++;
        }
        if (offset >= bytes.length) throw _invalid;
        final next = bytes[offset];
        if (next == 0 || (next >= 0xd0 && next <= 0xd7)) {
          offset++;
          continue;
        }
        clean.add(Uint8List.sublistView(bytes, scanStart, markerStart));
        offset = markerStart;
        break;
      }
    } else {
      offset += length;
    }
  }
  throw _invalid;
}

Uint8List _jpegOrientation(int orientation) => Uint8List.fromList([
  0xff,
  0xe1,
  0,
  34,
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
  orientation,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
]);

bool _isPng(Uint8List bytes) {
  if (bytes.length < 8) return false;
  for (var i = 0; i < 8; i++) {
    if (bytes[i] != _pngSignature[i]) return false;
  }
  return true;
}

(Uint8List, int) _checkPng(Uint8List bytes) {
  if (bytes.length < 33) throw _invalid;
  final data = ByteData.sublistView(bytes);
  if (data.getUint32(8) != 13 || data.getUint32(12) != 0x49484452) {
    throw _invalid;
  }
  final width = data.getUint32(16);
  final height = data.getUint32(20);
  _checkDimensions(width, height);
  final bits = bytes[24];
  final colorType = bytes[25];
  final channels = switch (colorType) {
    0 || 3 => 1,
    2 => 3,
    4 => 2,
    6 => 4,
    _ => 0,
  };
  final allowedBits = switch (colorType) {
    0 => [1, 2, 4, 8, 16],
    3 => [1, 2, 4, 8],
    _ => [8, 16],
  };
  final interlace = bytes[28];
  if (channels == 0 ||
      !allowedBits.contains(bits) ||
      bytes[26] != 0 ||
      bytes[27] != 0 ||
      interlace > 1) {
    throw _invalid;
  }

  final expectedBytes = _pngInflatedSize(
    width,
    height,
    channels * bits,
    interlace,
  );
  final counter = _InflatedByteCounter(expectedBytes);
  final inflater = ZLibDecoder().startChunkedConversion(counter);
  final clean = BytesBuilder()..add(_pngSignature);
  var offset = 8;
  var paletteEntries = 0;
  var hasTransparency = false;
  int? orientation;
  var idatCount = 0;
  var endedIdat = false;
  var hasEnd = false;
  while (offset + 12 <= bytes.length) {
    final length = data.getUint32(offset);
    final end = offset + length + 12;
    if (end > bytes.length) throw _invalid;
    final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
    if (_crc32(bytes, offset + 4, end - 4) != data.getUint32(end - 4)) {
      throw _invalid;
    }
    if (type == 'acTL' || type == 'fcTL' || type == 'fdAT') throw _animated;
    if (type != 'IDAT' && idatCount > 0) endedIdat = true;
    switch (type) {
      case 'IHDR':
        if (offset != 8 || length != 13) throw _invalid;
      case 'PLTE':
        if (paletteEntries != 0 ||
            idatCount > 0 ||
            length == 0 ||
            length > 768 ||
            length % 3 != 0 ||
            colorType == 0 ||
            colorType == 4) {
          throw _invalid;
        }
        paletteEntries = length ~/ 3;
        if (colorType == 3 && paletteEntries > (1 << bits)) throw _invalid;
      case 'tRNS':
        if (hasTransparency ||
            idatCount > 0 ||
            !switch (colorType) {
              0 => length == 2,
              2 => length == 6,
              3 => length > 0 && length <= paletteEntries,
              _ => false,
            }) {
          throw _invalid;
        }
        hasTransparency = true;
      case 'IDAT':
        if (endedIdat || (colorType == 3 && paletteEntries == 0)) {
          throw _invalid;
        }
        // Batasi juga banyaknya chunk kosong agar indeks decoder tetap kecil.
        if (++idatCount > 4096) throw _invalid;
        // Input kecil + sink tanpa buffer membatasi inflate berheader palsu.
        for (var i = offset + 8; i < end - 4; i += 1024) {
          inflater.add(
            Uint8List.sublistView(bytes, i, math.min(i + 1024, end - 4)),
          );
        }
      case 'IEND':
        if (length != 0 || idatCount == 0 || end != bytes.length) {
          throw _invalid;
        }
        hasEnd = true;
      case 'eXIf':
        if (orientation != null) throw _invalid;
        orientation = _readTiffOrientation(
          Uint8List.sublistView(bytes, offset + 8, end - 4),
        );
      default:
        // Chunk kritis yang tidak dikenal tidak boleh diam-diam diabaikan.
        if ((bytes[offset + 4] & 32) == 0) throw _invalid;
    }
    // Metadata tidak diteruskan ke decoder (termasuk profil terkompresi).
    if (const ['IHDR', 'PLTE', 'tRNS', 'IDAT', 'IEND'].contains(type)) {
      clean.add(Uint8List.sublistView(bytes, offset, end));
    }
    offset = end;
  }
  if (!hasEnd || offset != bytes.length) throw _invalid;
  inflater.close();
  if (counter.count != expectedBytes) throw _invalid;
  return (clean.takeBytes(), orientation ?? 1);
}

int _readTiffOrientation(Uint8List bytes) {
  // Hanya IFD utama dan nilai inline SHORT dibaca; tidak mengikuti pointer
  // GPS/thumbnail atau mendekode metadata lain yang tidak dibutuhkan editor.
  if (bytes.length < 8) throw _invalid;
  final endian = switch ((bytes[0], bytes[1])) {
    (0x49, 0x49) => Endian.little,
    (0x4d, 0x4d) => Endian.big,
    _ => throw _invalid,
  };
  final data = ByteData.sublistView(bytes);
  if (data.getUint16(2, endian) != 42) throw _invalid;
  final directory = data.getUint32(4, endian);
  if (directory == 0) return 1;
  if (directory < 8 || directory + 2 > bytes.length) throw _invalid;
  final count = data.getUint16(directory, endian);
  if (directory + 2 + count * 12 + 4 > bytes.length) throw _invalid;
  int? orientation;
  for (var i = 0; i < count; i++) {
    final offset = directory + 2 + i * 12;
    if (data.getUint16(offset, endian) != 0x0112) continue;
    if (orientation != null ||
        data.getUint16(offset + 2, endian) != 3 ||
        data.getUint32(offset + 4, endian) != 1) {
      throw _invalid;
    }
    orientation = data.getUint16(offset + 8, endian);
    if (orientation < 1 || orientation > 8) throw _invalid;
  }
  return orientation ?? 1;
}

int _pngInflatedSize(int width, int height, int bitsPerPixel, int interlace) {
  if (interlace == 0) return height * (1 + (width * bitsPerPixel + 7) ~/ 8);
  const passes = [
    (0, 0, 8, 8),
    (4, 0, 8, 8),
    (0, 4, 4, 8),
    (2, 0, 4, 4),
    (0, 2, 2, 4),
    (1, 0, 2, 2),
    (0, 1, 1, 2),
  ];
  var size = 0;
  for (final (x, y, dx, dy) in passes) {
    if (width <= x || height <= y) continue;
    final passWidth = (width - x + dx - 1) ~/ dx;
    final passHeight = (height - y + dy - 1) ~/ dy;
    size += passHeight * (1 + (passWidth * bitsPerPixel + 7) ~/ 8);
  }
  return size;
}

class _InflatedByteCounter implements Sink<List<int>> {
  _InflatedByteCounter(this.limit);
  final int limit;
  int count = 0;

  @override
  void add(List<int> data) {
    count += data.length;
    if (count > limit) throw _invalid;
  }

  @override
  void close() {}
}

final _crcTable = List<int>.generate(256, (value) {
  for (var bit = 0; bit < 8; bit++) {
    value = (value >> 1) ^ ((value & 1) != 0 ? 0xedb88320 : 0);
  }
  return value;
});

int _crc32(Uint8List bytes, int start, int end) {
  var crc = 0xffffffff;
  for (var i = start; i < end; i++) {
    crc = _crcTable[(crc ^ bytes[i]) & 255] ^ (crc >> 8);
  }
  return crc ^ 0xffffffff;
}
