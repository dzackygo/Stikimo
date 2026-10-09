import 'package:stikimo/features/image_import/domain/imported_image.dart';
import 'package:stikimo/features/projects/domain/project_repository.dart';
import 'package:uuid/uuid.dart';

/// Fake untuk interaksi widget; correctness SQLite diuji terpisah di Android.
class MemoryProjectRepository implements ProjectRepository {
  final projects = <String, SavedProject>{};
  int deletions = 0;

  String _id() => const Uuid().v4();

  @override
  Future<SavedProject> create(
    ImportedImage image, {
    required String name,
  }) async {
    final sourceId = _id();
    final workingId = _id();
    final now = DateTime.utc(2026, 10, 9);
    final document = ProjectDocument(
      id: _id(),
      name: name,
      createdAt: now,
      updatedAt: now,
      sourceAssetId: sourceId,
      assets: [
        ProjectAsset(id: sourceId, role: AssetRole.original, byteLength: 1),
        ProjectAsset(
          id: workingId,
          role: AssetRole.working,
          byteLength: 1,
          width: image.width,
          height: image.height,
        ),
      ],
      layers: [
        ProjectLayer(
          id: _id(),
          content: ImageLayerContent(workingAssetId: workingId),
        ),
      ],
    );
    return projects[document.id] = SavedProject(
      document: document,
      revisionId: _id(),
    );
  }

  @override
  Future<List<ProjectSummary>> list() async => projects.values
      .map(
        (saved) => ProjectSummary(
          id: saved.document.id,
          name: saved.document.name,
          createdAt: saved.document.createdAt,
          updatedAt: saved.document.updatedAt,
          revisionId: saved.revisionId,
        ),
      )
      .toList();

  @override
  Future<SavedProject> load(String id) async =>
      projects[id] ?? (throw const ProjectFailure('Proyek tidak ditemukan.'));

  @override
  Future<SavedProject> save(
    SavedProject current, {
    required ProjectDocument document,
    List<ProjectAssetWrite> newAssets = const [],
  }) async => projects[document.id] = SavedProject(
    document: document,
    revisionId: _id(),
  );

  @override
  Future<SavedProject> rename(SavedProject current, String name) =>
      save(current, document: current.document.copyWith(name: name));

  @override
  Future<SavedProject> duplicate(String id, {String? name}) async {
    final current = await load(id);
    final document = current.document.copyWith(
      id: _id(),
      name: name ?? '${current.document.name} salinan',
    );
    return projects[document.id] = SavedProject(
      document: document,
      revisionId: _id(),
    );
  }

  @override
  Future<void> delete(String id) async {
    projects.remove(id);
    deletions++;
  }

  @override
  Future<void> close() async {}

  @override
  String assetPath(String projectId, String assetId) =>
      'unused-synthetic-preview.png';
}
