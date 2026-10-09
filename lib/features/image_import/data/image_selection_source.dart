import 'dart:io';

import 'package:image_picker/image_picker.dart';

import '../domain/import_failure.dart';

abstract interface class ImageSelectionSource {
  Future<File?> pick();
  Future<File?> recover();
}

class AndroidImageSelectionSource implements ImageSelectionSource {
  AndroidImageSelectionSource({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<File?> pick() async {
    // Tanpa resize/quality: salinan sumber harus mempertahankan byte pilihan.
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    return image == null ? null : File(image.path);
  }

  @override
  Future<File?> recover() async {
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) return null;
    if (response.exception != null) throw response.exception!;
    final files = response.files;
    if (files == null ||
        files.length != 1 ||
        response.type == RetrieveType.video) {
      throw const ImportFailure(
        'Foto sebelumnya tidak dapat dipulihkan. Pilih ulang foto.',
      );
    }
    return File(files.single.path);
  }
}
