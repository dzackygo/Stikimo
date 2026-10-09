import 'dart:io';

import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:uuid/uuid.dart';

import '../../../core/storage/app_storage.dart';
import '../../image_import/domain/imported_image.dart';
import '../domain/project_repository.dart';
import '../domain/project_validation.dart';
import 'project_file_store.dart';

/// SQLite menyimpan pointer revisi; aset dan JSON yang sudah terbit immutable.
class LocalProjectRepository implements ProjectRepository {
  LocalProjectRepository._(this._database, this._files);

  final sqlite.Database _database;
  final ProjectFileStore _files;
  bool _closed = false;

  // Dua instance pada root yang sama juga tidak saling membersihkan file
  // staging. Aplikasi menggunakan satu repository dalam proses Android.
  static final _queues = <String, Future<void>>{};

  static Future<LocalProjectRepository> open({
    Directory? root,
    sqlite.DatabaseFactory? databaseFactory,
  }) async {
    try {
      final files = await ProjectFileStore.open(
        root ?? await AppStorage.noBackupRoot(),
      );
      final database = await (databaseFactory ?? sqlite.databaseFactory)
          .openDatabase(
            files.checkedPath('stikimo.sqlite'),
            options: sqlite.OpenDatabaseOptions(
              version: 1,
              singleInstance: false,
              onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
              onCreate: (db, version) async {
                await db.execute('''
            CREATE TABLE projects (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              revision_id TEXT NOT NULL,
              source_asset_id TEXT NOT NULL,
              is_deleted INTEGER NOT NULL DEFAULT 0 CHECK(is_deleted IN (0, 1))
            )
          ''');
                await db.execute('''
            CREATE TABLE project_assets (
              project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
              id TEXT NOT NULL,
              role TEXT NOT NULL,
              byte_length INTEGER NOT NULL,
              width INTEGER,
              height INTEGER,
              PRIMARY KEY(project_id, id)
            )
          ''');
                await db.execute('''
            CREATE TABLE project_revisions (
              project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
              id TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              PRIMARY KEY(project_id, id)
            )
          ''');
              },
            ),
          );
      final repository = LocalProjectRepository._(database, files);
      try {
        await repository._enqueue(repository._recoverCleanup);
        return repository;
      } catch (_) {
        await database.close();
        rethrow;
      }
    } on ProjectFailure {
      rethrow;
    } on FileSystemException {
      throw const ProjectFailure(
        'Penyimpanan proyek tidak tersedia. Periksa ruang penyimpanan.',
      );
    } on sqlite.DatabaseException {
      throw const ProjectFailure(
        'Database proyek tidak dapat dibuka. Coba lagi.',
      );
    }
  }

  @override
  Future<List<ProjectSummary>> list() => _enqueue(() async {
    final rows = await _database.query(
      'projects',
      where: 'is_deleted = 0',
      orderBy: 'updated_at DESC, id ASC',
    );
    return rows.map(_summary).toList(growable: false);
  });

  @override
  Future<SavedProject> create(ImportedImage image, {required String name}) =>
      _enqueue(() async {
        final normalizedName = normalizeProjectName(name);
        if (image.width < 1 ||
            image.width > 2048 ||
            image.height < 1 ||
            image.height > 2048) {
          throw const ProjectFailure(
            'Dimensi foto pilihan tidak valid. Pilih ulang foto.',
          );
        }
        final projectId = _newId();
        final sourceId = _newId();
        final workingId = _newId();
        final revisionId = _newId();
        var ownedDirectory = false;
        try {
          await _files.createProject(projectId);
          ownedDirectory = true;
          final sourceLength = await _files.copyAsset(
            projectId,
            sourceId,
            File(image.sourcePath),
          );
          final workingLength = await _files.copyAsset(
            projectId,
            workingId,
            File(image.previewPath),
          );
          final timestamp = _now();
          final document = ProjectDocument(
            id: projectId,
            name: normalizedName,
            createdAt: timestamp,
            updatedAt: timestamp,
            sourceAssetId: sourceId,
            assets: [
              ProjectAsset(
                id: sourceId,
                role: AssetRole.original,
                byteLength: sourceLength,
              ),
              ProjectAsset(
                id: workingId,
                role: AssetRole.working,
                byteLength: workingLength,
                width: image.width,
                height: image.height,
              ),
            ],
            layers: [
              ProjectLayer(
                id: _newId(),
                content: ImageLayerContent(workingAssetId: workingId),
                width: image.width >= image.height
                    ? 1
                    : image.width / image.height,
                height: image.height >= image.width
                    ? 1
                    : image.height / image.width,
              ),
            ],
          );
          await _files.writeRevision(revisionId, document);
          await _publishNew(document, revisionId, document.assets);
          return SavedProject(document: document, revisionId: revisionId);
        } catch (_) {
          if (ownedDirectory &&
              !await _revisionMayBeCommitted(projectId, revisionId)) {
            await _tryRemoveProject(projectId);
          }
          rethrow;
        }
      });

  @override
  Future<SavedProject> load(String id) => _enqueue(() => _load(id));

  Future<SavedProject> _load(String id) async {
    final row = await _projectRow(id);
    final revisionId = jsonString(row['revision_id']);
    final document = await _files.readRevision(id, revisionId);
    if (document.id != id ||
        document.name != row['name'] ||
        document.sourceAssetId != row['source_asset_id'] ||
        document.createdAt.millisecondsSinceEpoch != row['created_at'] ||
        document.updatedAt.millisecondsSinceEpoch != row['updated_at']) {
      throw const ProjectFailure(
        'Metadata proyek tidak sesuai dengan dokumennya.',
      );
    }
    final registered = {
      for (final asset in await _registeredAssets(id)) asset.id: asset,
    };
    for (final asset in document.assets) {
      if (!_sameAsset(asset, registered[asset.id])) {
        throw const ProjectFailure('Daftar aset proyek tidak valid.');
      }
      await _files.verifyAsset(id, asset);
    }
    return SavedProject(document: document, revisionId: revisionId);
  }

  @override
  Future<SavedProject> save(
    SavedProject current, {
    required ProjectDocument document,
    List<ProjectAssetWrite> newAssets = const [],
  }) =>
      _enqueue(() => _save(current, document: document, newAssets: newAssets));

  Future<SavedProject> _save(
    SavedProject current, {
    required ProjectDocument document,
    List<ProjectAssetWrite> newAssets = const [],
  }) async {
    final existing = await _load(current.document.id);
    if (existing.revisionId != current.revisionId) throw _stale;
    if (document.id != existing.document.id ||
        document.sourceAssetId != existing.document.sourceAssetId ||
        document.createdAt != existing.document.createdAt) {
      throw const ProjectFailure(
        'Identitas dan sumber asli proyek tidak boleh diubah.',
      );
    }
    final registered = {
      for (final asset in await _registeredAssets(document.id)) asset.id: asset,
    };
    final writes = <String, ProjectAssetWrite>{};
    for (final write in newAssets) {
      if (registered.containsKey(write.id) || writes.containsKey(write.id)) {
        throw const ProjectFailure(
          'Aset yang sudah tersimpan tidak boleh ditimpa.',
        );
      }
      writes[write.id] = write;
    }
    for (final asset in document.assets) {
      final known = registered[asset.id] ?? writes[asset.id]?.asset;
      if (!_sameAsset(asset, known)) {
        throw const ProjectFailure(
          'Byte dan metadata aset proyek tidak sesuai.',
        );
      }
      if (registered.containsKey(asset.id)) {
        await _files.verifyAsset(document.id, asset);
      }
    }
    final declaredIds = document.assets.map((asset) => asset.id).toSet();
    if (writes.keys.any((id) => !declaredIds.contains(id))) {
      throw const ProjectFailure(
        'Aset baru harus terdaftar pada dokumen proyek.',
      );
    }
    final timestamp = _nowAfter(existing.document.updatedAt);
    final next = document.copyWith(updatedAt: timestamp);
    final revisionId = _newId();
    final stagedAssets = <String>[];
    var revisionWritten = false;
    try {
      for (final write in writes.values) {
        await _files.writeAsset(document.id, write.id, write.bytes);
        stagedAssets.add(write.id);
      }
      await _files.writeRevision(revisionId, next);
      revisionWritten = true;
      await _database.transaction((transaction) async {
        final count = await transaction.update(
          'projects',
          {
            'name': next.name,
            'updated_at': next.updatedAt.millisecondsSinceEpoch,
            'revision_id': revisionId,
          },
          where: 'id = ? AND revision_id = ? AND is_deleted = 0',
          whereArgs: [next.id, current.revisionId],
        );
        if (count != 1) throw _stale;
        for (final write in writes.values) {
          await transaction.insert(
            'project_assets',
            _assetRow(next.id, write.asset),
          );
        }
        await transaction.insert('project_revisions', {
          'project_id': next.id,
          'id': revisionId,
          'created_at': next.updatedAt.millisecondsSinceEpoch,
        });
      });
      return SavedProject(document: next, revisionId: revisionId);
    } catch (_) {
      if (!await _revisionMayBeCommitted(document.id, revisionId)) {
        for (final assetId in stagedAssets) {
          try {
            await _files.removeAsset(document.id, assetId);
          } on FileSystemException {
            /* File orphan dibersihkan saat open. */
          } on ProjectFailure {
            /* Jangan memperluas target cleanup yang ditolak. */
          }
        }
        if (revisionWritten) {
          try {
            await _files.removeRevision(document.id, revisionId);
          } on FileSystemException {
            /* File orphan dibersihkan saat open. */
          } on ProjectFailure {
            /* Jangan memperluas target cleanup yang ditolak. */
          }
        }
      }
      rethrow;
    }
  }

  @override
  Future<SavedProject> rename(SavedProject current, String name) => _enqueue(
    () => _save(
      current,
      document: current.document.copyWith(name: normalizeProjectName(name)),
    ),
  );

  @override
  Future<SavedProject> duplicate(String id, {String? name}) =>
      _enqueue(() async {
        final original = await _load(id);
        final assets = await _registeredAssets(id);
        final newId = _newId();
        final revisionId = _newId();
        final normalizedName = normalizeProjectName(
          name ?? _copyName(original.document.name),
        );
        var ownedDirectory = false;
        try {
          await _files.createProject(newId);
          ownedDirectory = true;
          for (final asset in assets) {
            await _files.verifyAsset(id, asset);
            final length = await _files.copyAsset(
              newId,
              asset.id,
              File(_files.assetPath(id, asset.id)),
            );
            if (length != asset.byteLength) {
              throw const ProjectFailure(
                'Aset proyek berubah saat disalin. Coba lagi.',
              );
            }
          }
          final timestamp = _now();
          final document = original.document.copyWith(
            id: newId,
            name: normalizedName,
            createdAt: timestamp,
            updatedAt: timestamp,
          );
          await _files.writeRevision(revisionId, document);
          await _publishNew(document, revisionId, assets);
          return SavedProject(document: document, revisionId: revisionId);
        } catch (_) {
          if (ownedDirectory &&
              !await _revisionMayBeCommitted(newId, revisionId)) {
            await _tryRemoveProject(newId);
          }
          rethrow;
        }
      });

  @override
  Future<void> delete(String id) => _enqueue(() async {
    validateProjectId(id);
    final rows = await _database.query(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    await _database.update(
      'projects',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _finishDeletion(id);
  });

  Future<void> _finishDeletion(String id) async {
    await _files.removeProject(id);
    await _database.delete(
      'projects',
      where: 'id = ? AND is_deleted = 1',
      whereArgs: [id],
    );
  }

  @override
  Future<void> close() => _enqueue(() async {
    if (_closed) return;
    _closed = true;
    await _database.close();
  }, allowClosed: true);

  @override
  String assetPath(String projectId, String assetId) {
    if (_closed) {
      throw const ProjectFailure('Penyimpanan proyek sudah ditutup.');
    }
    try {
      return _files.assetPath(projectId, assetId);
    } on FileSystemException {
      throw const ProjectFailure('Aset proyek tidak dapat dibaca.');
    }
  }

  Future<void> _publishNew(
    ProjectDocument document,
    String revisionId,
    List<ProjectAsset> assets,
  ) => _database.transaction((transaction) async {
    await transaction.insert('projects', {
      'id': document.id,
      'name': document.name,
      'created_at': document.createdAt.millisecondsSinceEpoch,
      'updated_at': document.updatedAt.millisecondsSinceEpoch,
      'revision_id': revisionId,
      'source_asset_id': document.sourceAssetId,
      'is_deleted': 0,
    });
    for (final asset in assets) {
      await transaction.insert('project_assets', _assetRow(document.id, asset));
    }
    await transaction.insert('project_revisions', {
      'project_id': document.id,
      'id': revisionId,
      'created_at': document.updatedAt.millisecondsSinceEpoch,
    });
  });

  Future<Map<String, Object?>> _projectRow(String id) async {
    validateProjectId(id);
    final rows = await _database.query(
      'projects',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const ProjectFailure('Proyek tidak ditemukan atau sudah dihapus.');
    }
    return rows.single;
  }

  Future<List<ProjectAsset>> _registeredAssets(String id) async {
    final rows = await _database.query(
      'project_assets',
      where: 'project_id = ?',
      whereArgs: [id],
    );
    return rows
        .map(
          (row) => ProjectAsset(
            id: jsonString(row['id']),
            role: jsonEnum(row['role'], AssetRole.values),
            byteLength: jsonInt(row['byte_length']),
            width: row['width'] == null ? null : jsonInt(row['width']),
            height: row['height'] == null ? null : jsonInt(row['height']),
          ),
        )
        .toList(growable: false);
  }

  Future<bool> _revisionMayBeCommitted(
    String projectId,
    String revisionId,
  ) async {
    try {
      final rows = await _database.query(
        'project_revisions',
        columns: ['id'],
        where: 'project_id = ? AND id = ?',
        whereArgs: [projectId, revisionId],
        limit: 1,
      );
      return rows.isNotEmpty;
    } on sqlite.DatabaseException {
      // Hasil commit tidak diketahui: mempertahankan file lebih aman daripada
      // menghapus aset yang mungkin sudah direferensikan DB.
      return true;
    }
  }

  Future<void> _tryRemoveProject(String id) async {
    try {
      await _files.removeProject(id);
    } on FileSystemException {
      /* Folder belum dipublikasikan; sumber tidak dihapus. */
    } on ProjectFailure {
      /* Target yang gagal diverifikasi tidak dihapus. */
    }
  }

  Future<void> _recoverCleanup() async {
    final rows = await _database.query('projects');
    for (final row in rows) {
      final id = jsonString(row['id']);
      try {
        if (row['is_deleted'] == 1) {
          await _finishDeletion(id);
          continue;
        }
        final assets = await _registeredAssets(id);
        final revisions = await _database.query(
          'project_revisions',
          columns: ['id'],
          where: 'project_id = ?',
          whereArgs: [id],
        );
        await _files.cleanupUncommitted(
          id,
          assetIds: assets.map((asset) => asset.id).toSet(),
          revisionIds: revisions.map((row) => jsonString(row['id'])).toSet(),
        );
      } on FileSystemException {
        // Cleanup bisa dicoba saat open berikutnya tanpa menghalangi proyek lain.
      } on ProjectFailure {
        // Tidak menghapus isi folder yang kepemilikan/path-nya tidak valid.
      }
    }
    await _files.cleanupUnpublishedProjects(
      rows.map((row) => jsonString(row['id'])).toSet(),
    );
  }

  Future<T> _enqueue<T>(
    Future<T> Function() operation, {
    bool allowClosed = false,
  }) {
    final key = Platform.isWindows
        ? _files.root.path.toLowerCase()
        : _files.root.path;
    final previous = _queues[key] ?? Future<void>.value();
    final result = previous.then((_) async {
      if (_closed && !allowClosed) {
        throw const ProjectFailure('Penyimpanan proyek sudah ditutup.');
      }
      try {
        return await operation();
      } on ProjectFailure {
        rethrow;
      } on FileSystemException {
        throw const ProjectFailure(
          'Proyek tidak dapat dibaca atau disimpan. Periksa ruang penyimpanan.',
        );
      } on sqlite.DatabaseException {
        throw const ProjectFailure(
          'Perubahan proyek tidak dapat disimpan. Coba lagi.',
        );
      } on FormatException {
        throw const ProjectFailure('Dokumen proyek rusak atau tidak didukung.');
      }
    });
    final tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    _queues[key] = tail;
    tail.then((_) {
      if (identical(_queues[key], tail)) _queues.remove(key);
    });
    return result;
  }

  static Map<String, Object?> _assetRow(String projectId, ProjectAsset asset) =>
      {
        'project_id': projectId,
        'id': asset.id,
        'role': asset.role.name,
        'byte_length': asset.byteLength,
        'width': asset.width,
        'height': asset.height,
      };

  static ProjectSummary _summary(Map<String, Object?> row) => ProjectSummary(
    id: jsonString(row['id']),
    name: jsonString(row['name']),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      jsonInt(row['created_at']),
      isUtc: true,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      jsonInt(row['updated_at']),
      isUtc: true,
    ),
    revisionId: jsonString(row['revision_id']),
  );

  static bool _sameAsset(ProjectAsset asset, ProjectAsset? other) =>
      other != null &&
      asset.id == other.id &&
      asset.role == other.role &&
      asset.byteLength == other.byteLength &&
      asset.width == other.width &&
      asset.height == other.height;

  static DateTime _now() => DateTime.fromMillisecondsSinceEpoch(
    DateTime.now().millisecondsSinceEpoch,
    isUtc: true,
  );
  static DateTime _nowAfter(DateTime previous) {
    final now = _now();
    return now.isBefore(previous) ? previous : now;
  }

  static String _newId() => const Uuid().v4();
  static String _copyName(String original) {
    const suffix = ' (salinan)';
    return '${String.fromCharCodes(original.runes.take(80 - suffix.length))}$suffix';
  }
}

const _stale = ProjectFailure(
  'Proyek sudah berubah. Buka ulang sebelum menyimpan lagi.',
);
