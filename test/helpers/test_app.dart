import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stikimo/app/app.dart';
import 'package:stikimo/features/image_import/data/image_import_service.dart';
import 'package:stikimo/features/image_import/domain/imported_image.dart';
import 'package:stikimo/features/image_import/presentation/import_controller.dart';
import 'package:stikimo/features/projects/domain/project_repository.dart';
import 'package:stikimo/features/projects/presentation/project_controller.dart';

import 'memory_project_repository.dart';

Widget testApp({
  ImageImportService? importService,
  ProjectRepository? projectRepository,
  Future<ProjectRepository> Function()? repositoryFactory,
}) => ProviderScope(
  overrides: [
    imageImportServiceProvider.overrideWithValue(
      importService ?? EmptyImportService(),
    ),
    projectRepositoryProvider.overrideWith(
      (ref) async => repositoryFactory == null
          ? projectRepository ?? MemoryProjectRepository()
          : await repositoryFactory(),
    ),
  ],
  child: const StikimoApp(),
);

class EmptyImportService extends ImageImportService {
  @override
  Future<ImportedImage?> recoverAndImport() async => null;

  @override
  Future<ImportedImage?> pickAndImport() async => null;
}
