/// File sumber immutable dan preview RGBA tanpa metadata, dalam storage privat.
class ImportedImage {
  const ImportedImage({
    required this.id,
    required this.sourcePath,
    required this.previewPath,
    required this.width,
    required this.height,
  });

  final String id;
  final String sourcePath;
  final String previewPath;
  final int width;
  final int height;
}
