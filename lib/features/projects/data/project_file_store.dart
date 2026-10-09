import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/project_document.dart';
import '../domain/project_validation.dart';

/// Hanya menghasilkan path dari ID tervalidasi di dalam root privat kanonik.
class ProjectFileStore {
  ProjectFileStore._(this.root);

  final Directory root;
  static const maxAssetBytes = ProjectAsset.maxByteLength;

  static Future<ProjectFileStore> open(Directory requestedRoot) async {
    if (await FileSystemEntity.type(requestedRoot.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const ProjectFailure('Lokasi penyimpanan proyek tidak aman.');
    }
    await requestedRoot.create(recursive: true);
    final root = Directory(await requestedRoot.resolveSymbolicLinks());
    final store = ProjectFileStore._(root);
    store.checkedPath('projects');
    await Directory('${root.path}/projects').create();
    for (final suffix in ['', '-journal', '-wal', '-shm']) {
      store.checkedPath('stikimo.sqlite$suffix');
    }
    return store;
  }

  /// Memeriksa setiap komponen yang ada, termasuk parent dan symlink file.
  String checkedPath(String relative) {
    if (FileSystemEntity.typeSync(root.path, followLinks: false) !=
            FileSystemEntityType.directory ||
        _comparisonPath(root.resolveSymbolicLinksSync()) !=
            _comparisonPath(root.path)) {
      throw const ProjectFailure('Lokasi penyimpanan proyek tidak aman.');
    }
    final segments = relative.split('/');
    if (segments.any(
      (part) =>
          part.isEmpty ||
          part == '.' ||
          part == '..' ||
          part.contains('\\') ||
          part.contains(':'),
    )) {
      throw const ProjectFailure('Lokasi penyimpanan proyek tidak aman.');
    }
    var path = root.path;
    for (var index = 0; index < segments.length; index++) {
      path = '$path/${segments[index]}';
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type == FileSystemEntityType.link ||
          (index < segments.length - 1 &&
              type != FileSystemEntityType.directory)) {
        throw const ProjectFailure('Lokasi penyimpanan proyek tidak aman.');
      }
      final resolved = File(path).resolveSymbolicLinksSync();
      final rootPath = _comparisonPath(root.path);
      if (!_comparisonPath(resolved).startsWith('$rootPath/')) {
        throw const ProjectFailure('Lokasi penyimpanan proyek tidak aman.');
      }
    }
    return path;
  }

  String projectPath(String projectId) {
    validateProjectId(projectId);
    return checkedPath('projects/$projectId');
  }

  String assetPath(String projectId, String assetId) {
    validateProjectId(projectId);
    validateProjectId(assetId);
    return checkedPath('projects/$projectId/assets/$assetId.bin');
  }

  String revisionPath(String projectId, String revisionId) {
    validateProjectId(projectId);
    validateProjectId(revisionId);
    return checkedPath('projects/$projectId/revisions/$revisionId.json');
  }

  Future<void> createProject(String projectId) async {
    final directory = Directory(projectPath(projectId));
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const ProjectFailure('ID proyek sudah digunakan. Coba lagi.');
    }
    await directory.create();
    await File(checkedPath('projects/$projectId/.stikimo-project'))
        .writeAsString(projectId, flush: true);
    await Directory(checkedPath('projects/$projectId/assets')).create();
    await Directory(checkedPath('projects/$projectId/revisions')).create();
  }

  Future<int> copyAsset(String projectId, String assetId, File source) async {
    if (await FileSystemEntity.type(source.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const ProjectFailure(
        'Aset gambar tidak tersedia. Pilih ulang foto.',
      );
    }
    final destination = File(assetPath(projectId, assetId));
    await _requireNewFile(destination);
    final output = await destination.open(mode: FileMode.write);
    var length = 0;
    try {
      await for (final chunk in source.openRead()) {
        length += chunk.length;
        if (length > maxAssetBytes) {
          throw const ProjectFailure('Ukuran aset proyek terlalu besar.');
        }
        await output.writeFrom(chunk);
      }
      if (length == 0) throw const ProjectFailure('Aset gambar kosong.');
      await output.flush();
    } finally {
      await output.close();
    }
    return length;
  }

  Future<void> writeAsset(
    String projectId,
    String assetId,
    Uint8List bytes,
  ) async {
    if (bytes.isEmpty || bytes.length > maxAssetBytes) {
      throw const ProjectFailure('Ukuran aset proyek tidak valid.');
    }
    final file = File(assetPath(projectId, assetId));
    await _requireNewFile(file);
    try {
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      try {
        await _deleteFile(file);
      } on FileSystemException {
        /* Coba lagi saat open. */
      }
      rethrow;
    }
  }

  Future<void> writeRevision(
    String revisionId,
    ProjectDocument document,
  ) async {
    final bytes = utf8.encode(jsonEncode(document.toJson()));
    if (bytes.length > ProjectDocument.maxEncodedBytes) {
      throw const ProjectFailure('Dokumen proyek terlalu besar.');
    }
    final destination = File(revisionPath(document.id, revisionId));
    final pending = File(
      checkedPath('projects/${document.id}/revisions/$revisionId.tmp'),
    );
    await _requireNewFile(destination);
    await _requireNewFile(pending);
    try {
      await pending.writeAsBytes(bytes, flush: true);
      await pending.rename(destination.path);
    } catch (_) {
      try {
        await _deleteFile(pending);
      } on FileSystemException {
        /* Coba lagi saat open. */
      }
      rethrow;
    }
  }

  Future<ProjectDocument> readRevision(
    String projectId,
    String revisionId,
  ) async {
    final file = File(revisionPath(projectId, revisionId));
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (bytes.length + chunk.length > ProjectDocument.maxEncodedBytes) {
        throw const ProjectFailure('Dokumen proyek terlalu besar.');
      }
      bytes.add(chunk);
    }
    final value = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (value is! Map<String, dynamic>) {
      throw const ProjectFailure('Dokumen proyek tidak dapat dibaca.');
    }
    return ProjectDocument.fromJson(value);
  }

  Future<void> verifyAsset(String projectId, ProjectAsset asset) async {
    final file = File(assetPath(projectId, asset.id));
    if (!await file.exists() || await file.length() != asset.byteLength) {
      throw const ProjectFailure('Aset proyek hilang atau rusak.');
    }
  }

  Future<void> removeAsset(String projectId, String assetId) async {
    await _deleteFile(File(assetPath(projectId, assetId)));
  }

  Future<void> removeRevision(String projectId, String revisionId) async {
    await _deleteFile(File(revisionPath(projectId, revisionId)));
    await _deleteFile(
      File(checkedPath('projects/$projectId/revisions/$revisionId.tmp')),
    );
  }

  /// Pemanggil harus membuktikan kepemilikan melalui row DB atau operasi baru.
  Future<void> removeProject(String projectId) async {
    final directory = Directory(projectPath(projectId));
    if (!await directory.exists()) return;
    final marker = File(checkedPath('projects/$projectId/.stikimo-project'));
    if (!await marker.exists() ||
        await marker.length() != projectId.length ||
        await marker.readAsString() != projectId) {
      throw const ProjectFailure(
        'Kepemilikan folder proyek tidak dapat diverifikasi.',
      );
    }
    // checkedPath telah memastikan target UUID berada di bawah root kanonik.
    // Directory.delete tidak mengikuti symlink anak saat recursive=true.
    await directory.delete(recursive: true);
  }

  Future<void> cleanupUncommitted(
    String projectId, {
    required Set<String> assetIds,
    required Set<String> revisionIds,
  }) async {
    validateProjectId(projectId);
    assetIds.forEach(validateProjectId);
    revisionIds.forEach(validateProjectId);
    for (final folder in ['assets', 'revisions']) {
      final directory = Directory(checkedPath('projects/$projectId/$folder'));
      if (!await directory.exists()) continue;
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is! File) continue;
        final name = entry.uri.pathSegments.last;
        final match = _ownedFile.firstMatch(name);
        if (match == null) continue;
        final id = match.group(1)!;
        final extension = match.group(2)!;
        if (folder == 'assets' &&
            extension == 'bin' &&
            !assetIds.contains(id)) {
          await removeAsset(projectId, id);
        } else if (folder == 'revisions' &&
            (extension == 'tmp' ||
                (extension == 'json' && !revisionIds.contains(id)))) {
          await _deleteFile(
            File(checkedPath('projects/$projectId/$folder/$name')),
          );
        }
      }
    }
  }

  /// Folder dari create/duplicate yang terputus sebelum transaksi SQLite.
  /// Marker membuktikan kepemilikan; folder lain tidak disentuh.
  Future<void> cleanupUnpublishedProjects(Set<String> publishedIds) async {
    publishedIds.forEach(validateProjectId);
    final projects = Directory(checkedPath('projects'));
    await for (final entry in projects.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final id = entry.uri.pathSegments.where((part) => part.isNotEmpty).last;
      if (publishedIds.contains(id)) continue;
      try {
        validateProjectId(id);
        await removeProject(id);
      } on FileSystemException {
        // Simpan folder bila cleanup gagal; coba lagi pada open berikutnya.
      } on ProjectFailure {
        // Folder tanpa marker yang sesuai bukan target cleanup.
      }
    }
  }

  static Future<void> _requireNewFile(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const ProjectFailure('Aset proyek tidak boleh ditimpa.');
    }
  }

  static Future<void> _deleteFile(File file) async {
    if (await file.exists()) await file.delete();
  }

  static String _comparisonPath(String path) {
    final normalized = path
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'/$'), '');
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }
}

final _ownedFile = RegExp(
  r'^([0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\.(bin|json|tmp)$',
);
