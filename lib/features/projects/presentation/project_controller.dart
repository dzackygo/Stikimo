import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../image_import/domain/imported_image.dart';
import '../data/local_project_repository.dart';
import '../domain/project_repository.dart';

final projectRepositoryProvider = FutureProvider<ProjectRepository>((
  ref,
) async {
  final repository = await LocalProjectRepository.open();
  if (!ref.mounted) {
    await repository.close();
    throw const ProjectFailure('Penyimpanan sudah ditutup.');
  }
  ref.onDispose(() => unawaited(repository.close()));
  return repository;
}, retry: (_, _) => null);

final projectListProvider = FutureProvider<List<ProjectSummary>>(
  (ref) async => (await ref.watch(projectRepositoryProvider.future)).list(),
  retry: (_, _) => null,
);

final savedProjectProvider = FutureProvider.family<SavedProject, String>(
  (ref, id) async =>
      (await ref.watch(projectRepositoryProvider.future)).load(id),
  retry: (_, _) => null,
);

final projectPreviewPathProvider = FutureProvider.family<String?, String>((
  ref,
  id,
) async {
  final saved = await ref.watch(savedProjectProvider(id).future);
  final repository = await ref.watch(projectRepositoryProvider.future);
  final asset = saved.document.assets
      .where((asset) => asset.role == AssetRole.working)
      .firstOrNull;
  return asset == null ? null : repository.assetPath(id, asset.id);
});

final projectActionsProvider = Provider(ProjectActions.new);

class ProjectActions {
  ProjectActions(this._ref);
  final Ref _ref;

  void retry({String? projectId}) {
    if (_ref.read(projectRepositoryProvider).hasError) {
      _ref.invalidate(projectRepositoryProvider);
    }
    _ref.invalidate(projectListProvider);
    if (projectId != null) _ref.invalidate(savedProjectProvider(projectId));
  }

  Future<ProjectRepository> _repository() {
    if (_ref.read(projectRepositoryProvider).hasError) {
      _ref.invalidate(projectRepositoryProvider);
    }
    return _ref.read(projectRepositoryProvider.future);
  }

  Future<SavedProject> create(ImportedImage image, String name) async {
    final repository = await _repository();
    final saved = await repository.create(image, name: name);
    if (_ref.mounted) _ref.invalidate(projectListProvider);
    return saved;
  }

  Future<SavedProject> rename(SavedProject current, String name) async {
    final repository = await _repository();
    final saved = await repository.rename(current, name);
    if (_ref.mounted) {
      _ref.invalidate(projectListProvider);
      _ref.invalidate(savedProjectProvider(current.document.id));
    }
    return saved;
  }

  Future<SavedProject> duplicate(String id) async {
    final repository = await _repository();
    final saved = await repository.duplicate(id);
    if (_ref.mounted) _ref.invalidate(projectListProvider);
    return saved;
  }

  Future<void> delete(String id) async {
    final repository = await _repository();
    await repository.delete(id);
    if (_ref.mounted) _ref.invalidate(projectListProvider);
  }
}

String projectErrorMessage(Object error) => error is ProjectFailure
    ? error.message
    : 'Proyek tidak dapat diproses. Periksa ruang penyimpanan lalu coba lagi.';
