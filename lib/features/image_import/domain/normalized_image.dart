import 'dart:typed_data';

/// Salinan kerja PNG dengan orientasi tetap dan metadata sumber dihapus.
class NormalizedImage {
  const NormalizedImage({
    required this.pngBytes,
    required this.width,
    required this.height,
  });

  final Uint8List pngBytes;
  final int width;
  final int height;
}
