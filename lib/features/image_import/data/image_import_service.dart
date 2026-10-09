import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/app_storage.dart';
import '../domain/import_failure.dart';
import '../domain/imported_image.dart';
import '../domain/normalized_image.dart';
import 'image_normalizer.dart';
import 'image_selection_source.dart';

class ImageImportService {
  ImageImportService({
    ImageSelectionSource? selectionSource,
    Future<Directory> Function()? rootDirectory,
  }) : _selectionSource = selectionSource ?? AndroidImageSelectionSource(),
       _rootDirectory = rootDirectory ?? AppStorage.noBackupRoot;

  final ImageSelectionSource _selectionSource;
  final Future<Directory> Function() _rootDirectory;

  Future<ImportedImage?> pickAndImport() =>
      _selectAndImport(_selectionSource.pick);

  Future<ImportedImage?> recoverAndImport() =>
      _selectAndImport(_selectionSource.recover, restoreDraft: true);

  Future<ImportedImage?> _selectAndImport(
    Future<File?> Function() select, {
    bool restoreDraft = false,
  }) async {
    try {
      final file = await select();
      if (file == null) {
        return restoreDraft ? await _loadDraft(await _rootDirectory()) : null;
      }
      return await _importFile(file);
    } on ImportFailure {
      rethrow;
    } on PlatformException {
      throw const ImportFailure(
        'Pemilih foto tidak dapat dibuka. Periksa akses foto lalu coba lagi.',
      );
    } on MissingPluginException {
      throw const ImportFailure(
        'Pemilihan foto tersedia pada aplikasi Android.',
      );
    } on FileSystemException {
      throw const ImportFailure(
        'Foto tidak dapat dibaca atau disimpan. Periksa ruang penyimpanan lalu coba lagi.',
      );
    }
  }

  Future<ImportedImage> _importFile(File selected) async {
    if (await selected.length() > maxImportBytes) {
      throw const ImportFailure('Ukuran foto maksimal 32 MB.');
    }
    final builder = BytesBuilder(copy: false);
    // File pilihan dapat berubah sesudah length(); tetap batasi pembacaan aktual.
    await for (final chunk in selected.openRead()) {
      if (builder.length + chunk.length > maxImportBytes) {
        throw const ImportFailure('Ukuran foto maksimal 32 MB.');
      }
      builder.add(chunk);
    }
    final sourceBytes = builder.takeBytes();
    final normalized = await _normalizeInWorker(sourceBytes);
    final root = await _rootDirectory();
    final id = const Uuid().v4();
    final directory = Directory('${root.path}/imports/$id');
    await directory.create(recursive: true);
    final source = File('${directory.path}/source.bin');
    final preview = File('${directory.path}/preview.png');
    final manifest = File('${root.path}/imports/current.json');
    final pendingManifest = File('${root.path}/imports/current-$id.tmp');
    try {
      await source.writeAsBytes(sourceBytes, flush: true);
      await preview.writeAsBytes(normalized.pngBytes, flush: true);
      await pendingManifest.writeAsString(
        jsonEncode({
          'version': 1,
          'id': id,
          'width': normalized.width,
          'height': normalized.height,
        }),
        flush: true,
      );
      await pendingManifest.rename(manifest.path);
    } on FileSystemException {
      // Hanya direktori UUID baru milik operasi ini; sumber pilihan tak disentuh.
      // Cleanup best-effort tidak boleh menyamarkan kegagalan penyimpanan awal.
      try {
        if (await pendingManifest.exists()) await pendingManifest.delete();
        await directory.delete(recursive: true);
      } on FileSystemException {
        // File parsial tidak pernah diterbitkan sebagai hasil import sukses.
      }
      rethrow;
    }
    await _cleanupOtherDrafts(root, id);
    return ImportedImage(
      id: id,
      sourcePath: source.path,
      previewPath: preview.path,
      width: normalized.width,
      height: normalized.height,
    );
  }

  Future<ImportedImage?> _loadDraft(Directory root) async {
    final manifest = File('${root.path}/imports/current.json');
    if (!await manifest.exists()) {
      await _cleanupOtherDrafts(root, null);
      return null;
    }
    try {
      if (await manifest.length() > 4096) throw const FormatException();
      final value = jsonDecode(await manifest.readAsString());
      if (value is! Map<String, dynamic> || value['version'] != 1) {
        throw const FormatException();
      }
      final id = value['id'];
      final width = value['width'];
      final height = value['height'];
      if (id is! String ||
          !_draftId.hasMatch(id) ||
          width is! int ||
          height is! int ||
          width < 1 ||
          height < 1 ||
          width > maxWorkingEdge ||
          height > maxWorkingEdge) {
        throw const FormatException();
      }
      final source = File('${root.path}/imports/$id/source.bin');
      final preview = File('${root.path}/imports/$id/preview.png');
      if (!await source.exists() || !await preview.exists()) {
        throw const FormatException();
      }
      await _cleanupOtherDrafts(root, id);
      return ImportedImage(
        id: id,
        sourcePath: source.path,
        previewPath: preview.path,
        width: width,
        height: height,
      );
    } on FormatException {
      throw const ImportFailure(
        'Draf foto tidak dapat dipulihkan. Pilih ulang foto.',
      );
    }
  }

  // imports/ hanya menyimpan draf yang belum dimiliki proyek. DATA-01 wajib
  // menyalin aset ke storage proyek sebelum mengklaimnya sebagai proyek tersimpan.
  Future<void> _cleanupOtherDrafts(Directory root, String? keepId) async {
    final drafts = Directory('${root.path}/imports');
    if (!await drafts.exists()) return;
    try {
      await for (final entry in drafts.list(followLinks: false)) {
        final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (entry is Directory && _draftId.hasMatch(name) && name != keepId) {
          await entry.delete(recursive: true);
        }
      }
    } on FileSystemException {
      // Cleanup best-effort: draf baru tetap valid; startup berikutnya mencoba lagi.
    }
  }
}

final _draftId = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

Future<NormalizedImage> _normalizeInWorker(Uint8List bytes) =>
    Isolate.run(() => normalizeImage(bytes));
