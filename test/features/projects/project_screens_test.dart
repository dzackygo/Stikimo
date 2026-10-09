import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stikimo/features/image_import/domain/imported_image.dart';
import 'package:stikimo/features/projects/domain/project_repository.dart';

import '../../helpers/memory_project_repository.dart';
import '../../helpers/test_app.dart';

void main() {
  testWidgets('retry reopens storage after repository initialization fails', (
    tester,
  ) async {
    var attempts = 0;
    final repository = MemoryProjectRepository();
    await tester.pumpWidget(
      testApp(
        repositoryFactory: () async {
          if (++attempts == 1) {
            throw const ProjectFailure('Penyimpanan belum siap.');
          }
          return repository;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Proyek saya'));
    await tester.tap(find.text('Proyek saya'));
    await tester.pumpAndSettle();
    expect(find.text('Penyimpanan belum siap.'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada proyek'), findsOneWidget);
    expect(attempts, 2);
  });
  testWidgets(
    'save rename duplicate and confirm deletion preserve other project',
    (tester) async {
      final repository = MemoryProjectRepository();
      await tester.pumpWidget(
        testApp(importService: _ReadyImage(), projectRepository: repository),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buat stiker'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Simpan proyek'));
      await tester.tap(find.text('Simpan proyek'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Kucing');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Kucing'), findsOneWidget);
      expect(repository.projects, hasLength(1));

      await tester.ensureVisible(find.text('Ganti nama'));
      await tester.tap(find.text('Ganti nama'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Kucing lucu');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Kucing lucu'), findsOneWidget);
      await tester.ensureVisible(find.text('Duplikasi'));
      await tester.tap(find.text('Duplikasi'));
      await tester.pumpAndSettle();
      expect(find.text('Kucing lucu salinan'), findsOneWidget);
      expect(repository.projects, hasLength(2));

      await tester.ensureVisible(find.text('Hapus proyek'));
      await tester.tap(find.text('Hapus proyek'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(repository.deletions, 0);
      await tester.tap(find.text('Hapus proyek'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(repository.deletions, 1);
      expect(repository.projects.values.single.document.name, 'Kucing lucu');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('project load failure offers retry and then empty state', (
    tester,
  ) async {
    final repository = _RetryRepository();
    await tester.pumpWidget(testApp(projectRepository: repository));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Proyek saya'));
    await tester.tap(find.text('Proyek saya'));
    await tester.pumpAndSettle();
    expect(find.text('Penyimpanan sementara tidak tersedia.'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada proyek'), findsOneWidget);
  });
}

class _ReadyImage extends EmptyImportService {
  @override
  Future<ImportedImage?> recoverAndImport() async => const ImportedImage(
    id: 'synthetic',
    sourcePath: 'synthetic-source',
    previewPath: 'unused-synthetic-preview.png',
    width: 10,
    height: 10,
  );
}

class _RetryRepository extends MemoryProjectRepository {
  bool _failed = false;
  @override
  Future<List<ProjectSummary>> list() async {
    if (!_failed) {
      _failed = true;
      throw const ProjectFailure('Penyimpanan sementara tidak tersedia.');
    }
    return super.list();
  }
}
