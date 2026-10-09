import '../../image_import/domain/imported_image.dart';
import 'project_document.dart';

export 'project_document.dart';

/// Penyimpanan snapshot: file baru diterbitkan sebelum metadata revisi berganti.
abstract interface class ProjectRepository {
  Future<List<ProjectSummary>> list();
  Future<SavedProject> create(ImportedImage image, {required String name});
  Future<SavedProject> load(String id);
  Future<SavedProject> save(
    SavedProject current, {
    required ProjectDocument document,
    List<ProjectAssetWrite> newAssets = const [],
  });
  Future<SavedProject> rename(SavedProject current, String name);
  Future<SavedProject> duplicate(String id, {String? name});
  Future<void> delete(String id);
  Future<void> close();
  String assetPath(String projectId, String assetId);
}
