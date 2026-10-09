import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:stikimo/features/image_import/data/image_import_service.dart';
import 'package:stikimo/features/image_import/data/image_normalizer.dart';
import 'package:stikimo/features/image_import/data/image_selection_source.dart';
import 'package:stikimo/features/image_import/domain/import_failure.dart';

void main() {
  late Directory temporary;
  late Directory storage;
  late _FakeSelectionSource selection;
  late ImageImportService service;
  late int storageRequests;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('stikimo-import-test-');
    storage = Directory('${temporary.path}/private');
    selection = _FakeSelectionSource();
    storageRequests = 0;
    service = ImageImportService(
      selectionSource: selection,
      rootDirectory: () async {
        storageRequests++;
        return storage;
      },
    );
  });

  tearDown(() async {
    final tempUri = temporary.absolute.uri;
    final systemTempUri = Directory.systemTemp.absolute.uri;
    if (!tempUri.path.startsWith(systemTempUri.path) ||
        !tempUri.pathSegments.any(
          (segment) => segment.startsWith('stikimo-import-test-'),
        )) {
      throw StateError('Unexpected test cleanup location');
    }
    await temporary.delete(recursive: true);
  });

  Future<File> writeFixture({int width = 3, int height = 2}) async {
    final fixture = image.Image(width: width, height: height, numChannels: 4)
      ..textData = {'Comment': 'synthetic-private-metadata'}
      ..setPixelRgba(0, 0, 230, 10, 40, 128)
      ..setPixelRgba(1, 0, 20, 30, 240, 255);
    return File('${temporary.path}/selected.png')
        .writeAsBytes(image.encodePng(fixture), flush: true);
  }

  test('saves_identical_source_and_separate_clean_png_preview', () async {
    final selected = await writeFixture();
    final original = await selected.readAsBytes();
    selection.selected = selected;

    final result = (await service.pickAndImport())!;

    expect(result.id, isNotEmpty);
    expect(result.sourcePath, isNot(selected.path));
    expect(result.previewPath, isNot(result.sourcePath));
    expect(
      File(result.sourcePath).parent.path,
      File(result.previewPath).parent.path,
    );
    expect(await selected.readAsBytes(), orderedEquals(original));
    expect(
      await File(result.sourcePath).readAsBytes(),
      orderedEquals(original),
    );
    final previewBytes = await File(result.previewPath).readAsBytes();
    expect(previewBytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final preview = image.decodePng(previewBytes)!;
    expect([result.width, result.height], [3, 2]);
    expect([preview.width, preview.height], [result.width, result.height]);
    expect(preview.getPixel(0, 0).a, 128);
    expect(preview.getPixel(1, 0).b, 240);
    expect(preview.textData, anyOf(isNull, isEmpty));
    expect(preview.iccProfile, isNull);
    expect(preview.exif.isEmpty, isTrue);
    expect(storageRequests, 1);
  });

  test('reports_normalized_dimensions_without_resizing_source', () async {
    final selected = await writeFixture(width: 4096, height: 2);
    final original = await selected.readAsBytes();
    selection.selected = selected;

    final result = (await service.pickAndImport())!;

    expect([result.width, result.height], [2048, 1]);
    final preview = image.decodePng(
      await File(result.previewPath).readAsBytes(),
    )!;
    expect([preview.width, preview.height], [2048, 1]);
    expect(
      await File(result.sourcePath).readAsBytes(),
      orderedEquals(original),
    );
    expect(await selected.readAsBytes(), orderedEquals(original));
  });

  test('successful_replacement_keeps_only_current_unclaimed_draft', () async {
    final selected = await writeFixture();
    final original = await selected.readAsBytes();
    selection.selected = selected;

    final first = (await service.pickAndImport())!;
    final second = (await service.pickAndImport())!;

    expect(second.id, isNot(first.id));
    expect(second.sourcePath, isNot(first.sourcePath));
    expect(second.previewPath, isNot(first.previewPath));
    expect(await File(first.previewPath).exists(), isFalse);
    expect(await File(first.sourcePath).exists(), isFalse);
    expect(await File(second.sourcePath).readAsBytes(), original);
    expect(await selected.readAsBytes(), original);
    final imports = Directory('${storage.path}/imports');
    final directories = await imports
        .list()
        .where((item) => item is Directory)
        .toList();
    expect(directories, hasLength(1));
    expect(directories.single.uri, File(second.sourcePath).parent.uri);
    final manifest = jsonDecode(
      await File('${imports.path}/current.json').readAsString(),
    ) as Map<String, dynamic>;
    expect(manifest['id'], second.id);
  });

  test('cancelled_picker_returns_null_without_touching_storage', () async {
    expect(await service.pickAndImport(), isNull);
    expect(storageRequests, 0);
    expect(await storage.exists(), isFalse);
    expect(await temporary.list().toList(), isEmpty);
  });

  test('empty_recovery_checks_storage_without_creating_files', () async {
    expect(await service.recoverAndImport(), isNull);
    expect(storageRequests, 1);
    expect(await temporary.list().toList(), isEmpty);
  });

  test('new_service_recovers_saved_draft_after_app_restart', () async {
    final selected = await writeFixture();
    final original = await selected.readAsBytes();
    selection.selected = selected;
    final imported = (await service.pickAndImport())!;
    final restartedSelection = _FakeSelectionSource();
    final restartedService = ImageImportService(
      selectionSource: restartedSelection,
      rootDirectory: () async => storage,
    );

    final restored = (await restartedService.recoverAndImport())!;

    expect(restored.id, imported.id);
    expect(restored.sourcePath, imported.sourcePath);
    expect(restored.previewPath, imported.previewPath);
    expect([restored.width, restored.height], [3, 2]);
    expect(await File(restored.sourcePath).readAsBytes(), original);
    expect(await selected.readAsBytes(), original);
    expect(restartedSelection.pickCalls, 0);
    expect(restartedSelection.recoveryCalls, 1);
  });

  test('cancelled_replacement_preserves_manifest_and_previous_draft', () async {
    final selected = await writeFixture();
    final original = await selected.readAsBytes();
    selection.selected = selected;
    final imported = (await service.pickAndImport())!;
    final manifest = File('${storage.path}/imports/current.json');
    final manifestBytes = await manifest.readAsBytes();
    final previewBytes = await File(imported.previewPath).readAsBytes();
    selection.selected = null;

    expect(await service.pickAndImport(), isNull);

    expect(await manifest.readAsBytes(), manifestBytes);
    expect(await File(imported.sourcePath).readAsBytes(), original);
    expect(await File(imported.previewPath).readAsBytes(), previewBytes);
    expect(await selected.readAsBytes(), original);
    expect((await service.recoverAndImport())!.id, imported.id);
  });

  test('failed_replacement_preserves_manifest_and_previous_draft', () async {
    final selected = await writeFixture();
    final original = await selected.readAsBytes();
    selection.selected = selected;
    final imported = (await service.pickAndImport())!;
    final manifest = File('${storage.path}/imports/current.json');
    final manifestBytes = await manifest.readAsBytes();
    final previewBytes = await File(imported.previewPath).readAsBytes();
    selection.selected = await File('${temporary.path}/invalid-replacement.png')
        .writeAsBytes([1, 2, 3]);

    await expectLater(service.pickAndImport(), throwsA(isA<ImportFailure>()));

    expect(await manifest.readAsBytes(), manifestBytes);
    expect(await File(imported.sourcePath).readAsBytes(), original);
    expect(await File(imported.previewPath).readAsBytes(), previewBytes);
    expect(await selected.readAsBytes(), original);
    expect((await service.recoverAndImport())!.id, imported.id);
  });

  test(
    'startup_removes_orphan_uuid_drafts_without_touching_other_files',
    () async {
      const orphanId = '12345678-1234-4234-8234-123456789abc';
      final imports = Directory('${storage.path}/imports');
      final orphan = await Directory('${imports.path}/$orphanId')
          .create(recursive: true);
      await File('${orphan.path}/source.bin').writeAsBytes([1, 2]);
      final unrelated = await Directory('${imports.path}/unrelated').create();
      final unrelatedFile = await File('${unrelated.path}/keep.txt')
          .writeAsString('synthetic unrelated data');
      final looseFile = await File('${imports.path}/keep.txt')
          .writeAsString('synthetic loose file');

      expect(await service.recoverAndImport(), isNull);

      expect(await orphan.exists(), isFalse);
      expect(await unrelatedFile.readAsString(), 'synthetic unrelated data');
      expect(await looseFile.readAsString(), 'synthetic loose file');
    },
  );

  test('saved_draft_recovery_removes_other_orphan_uuid_directories', () async {
    selection.selected = await writeFixture();
    final imported = (await service.pickAndImport())!;
    final orphan = await Directory(
      '${storage.path}/imports/12345678-1234-4234-8234-123456789abc',
    ).create();
    await File('${orphan.path}/preview.png').writeAsBytes([1, 2]);

    final restored = (await service.recoverAndImport())!;

    expect(restored.id, imported.id);
    expect(await File(restored.previewPath).exists(), isTrue);
    expect(await orphan.exists(), isFalse);
  });

  for (final entry in <String, Object?>{
    'invalid_json': '{',
    'oversized_json': ' ' * 4097,
    'non_object': [],
    'unsupported_version': {
      'version': 2,
      'id': '12345678-1234-4234-8234-123456789abc',
      'width': 3,
      'height': 2,
    },
    'string_version': {
      'version': '1',
      'id': '12345678-1234-4234-8234-123456789abc',
      'width': 3,
      'height': 2,
    },
    'traversal_id': {
      'version': 1,
      'id': '../../outside',
      'width': 3,
      'height': 2,
    },
    'absolute_id': {
      'version': 1,
      'id': '/synthetic/outside',
      'width': 3,
      'height': 2,
    },
    'missing_dimensions': {
      'version': 1,
      'id': '12345678-1234-4234-8234-123456789abc',
    },
    'fractional_dimensions': {
      'version': 1,
      'id': '12345678-1234-4234-8234-123456789abc',
      'width': 3.5,
      'height': 2,
    },
    'zero_dimensions': {
      'version': 1,
      'id': '12345678-1234-4234-8234-123456789abc',
      'width': 0,
      'height': 2,
    },
    'oversized_dimensions': {
      'version': 1,
      'id': '12345678-1234-4234-8234-123456789abc',
      'width': maxWorkingEdge + 1,
      'height': 2,
    },
  }.entries) {
    test(
      'rejects_${entry.key}_manifest_without_touching_other_files',
      () async {
        final imports = await Directory('${storage.path}/imports')
            .create(recursive: true);
        // Aset valid memastikan kasus version/dimensi gagal pada manifest,
        // bukan sekadar karena file yang ditunjuk tidak tersedia.
        final validDraft = await Directory(
          '${imports.path}/12345678-1234-4234-8234-123456789abc',
        ).create();
        final fixtureBytes = image.encodePng(
          image.Image(width: 3, height: 2, numChannels: 4),
        );
        final savedSource = await File('${validDraft.path}/source.bin')
            .writeAsBytes(fixtureBytes);
        await File('${validDraft.path}/preview.png').writeAsBytes(fixtureBytes);
        final manifest = File('${imports.path}/current.json');
        await manifest.writeAsString(
          entry.value is String
              ? entry.value! as String
              : jsonEncode(entry.value),
        );
        final manifestBytes = await manifest.readAsBytes();
        final outside = await File('${temporary.path}/outside')
            .writeAsString('synthetic outside sentinel');

        await expectLater(
          service.recoverAndImport(),
          throwsA(
            isA<ImportFailure>().having(
              (failure) => failure.message,
              'message',
              'Draf foto tidak dapat dipulihkan. Pilih ulang foto.',
            ),
          ),
        );

        expect(await outside.readAsString(), 'synthetic outside sentinel');
        expect(await manifest.readAsBytes(), manifestBytes);
        expect(await savedSource.readAsBytes(), fixtureBytes);
      },
    );
  }

  test('rejects_saved_draft_when_an_asset_is_missing', () async {
    selection.selected = await writeFixture();
    final imported = (await service.pickAndImport())!;
    await File(imported.previewPath).delete();

    await expectLater(
      service.recoverAndImport(),
      throwsA(isA<ImportFailure>()),
    );

    expect(await File(imported.sourcePath).exists(), isTrue);
  });

  test(
    'ignores_manifest_file_paths_and_derives_paths_from_validated_id',
    () async {
      selection.selected = await writeFixture();
      final imported = (await service.pickAndImport())!;
      final manifest = File('${storage.path}/imports/current.json');
      final value =
          jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      final outside = await File('${temporary.path}/outside')
          .writeAsString('synthetic outside sentinel');
      value['sourcePath'] = outside.path;
      value['previewPath'] = outside.path;
      await manifest.writeAsString(jsonEncode(value));

      final restored = (await service.recoverAndImport())!;

      expect(restored.sourcePath, imported.sourcePath);
      expect(restored.previewPath, imported.previewPath);
      expect(await outside.readAsString(), 'synthetic outside sentinel');
    },
  );

  test('manifest_publication_failure_removes_unpublished_assets', () async {
    final selected = await writeFixture();
    final original = await selected.readAsBytes();
    selection.selected = selected;
    final blocker = await Directory('${storage.path}/imports/current.json')
        .create(recursive: true);
    final sentinel = await File('${blocker.path}/keep.txt')
        .writeAsString('keep');

    await expectLater(service.pickAndImport(), throwsA(isA<ImportFailure>()));

    final entries = await Directory('${storage.path}/imports').list().toList();
    expect(entries, hasLength(1));
    expect(entries.single.uri, blocker.uri);
    expect(await sentinel.readAsString(), 'keep');
    expect(await selected.readAsBytes(), original);
  });

  test('recovery_imports_the_recovered_file_without_opening_picker', () async {
    final recovered = await writeFixture();
    final original = await recovered.readAsBytes();
    selection.recovered = recovered;

    final result = (await service.recoverAndImport())!;

    expect(selection.pickCalls, 0);
    expect(selection.recoveryCalls, 1);
    expect(await File(result.sourcePath).readAsBytes(), original);
    expect(await recovered.readAsBytes(), original);
    expect(await File(result.previewPath).exists(), isTrue);
  });

  test('invalid_file_fails_before_creating_storage', () async {
    final selected = await File('${temporary.path}/invalid.png')
        .writeAsBytes([1, 2, 3, 4]);
    selection.selected = selected;

    await expectLater(service.pickAndImport(), throwsA(isA<ImportFailure>()));

    expect(storageRequests, 0);
    expect(await storage.exists(), isFalse);
    expect(await selected.readAsBytes(), [1, 2, 3, 4]);
  });

  test('oversized_source_fails_before_reading_or_creating_storage', () async {
    final selected = File('${temporary.path}/oversized.png');
    final handle = await selected.open(mode: FileMode.write);
    await handle.truncate(maxImportBytes + 1);
    await handle.close();
    selection.selected = selected;

    await expectLater(
      service.pickAndImport(),
      throwsA(
        isA<ImportFailure>().having(
          (failure) => failure.message,
          'message',
          contains('32'),
        ),
      ),
    );

    expect(storageRequests, 0);
    expect(await storage.exists(), isFalse);
    expect(await selected.length(), maxImportBytes + 1);
  });

  test('unreadable_source_returns_safe_failure_without_private_path', () async {
    selection.selected = File('${temporary.path}/missing-private-photo.png');

    await expectLater(
      service.pickAndImport(),
      throwsA(
        isA<ImportFailure>().having(
          (failure) => failure.message,
          'message',
          'Foto tidak dapat dibaca atau disimpan. '
              'Periksa ruang penyimpanan lalu coba lagi.',
        ),
      ),
    );

    expect(storageRequests, 0);
    expect(await storage.exists(), isFalse);
  });

  test('storage_creation_failure_does_not_succeed_or_change_source', () async {
    final selected = await writeFixture();
    final original = await selected.readAsBytes();
    selection.selected = selected;
    final blocker = await File(storage.path).writeAsBytes([7, 8, 9]);

    await expectLater(service.pickAndImport(), throwsA(isA<ImportFailure>()));

    expect(await blocker.readAsBytes(), [7, 8, 9]);
    expect(await selected.readAsBytes(), original);
    expect(await temporary.list().length, 2);
  });

  test('denied_picker_permission_is_mapped_to_safe_failure', () async {
    selection.pickError = PlatformException(
      code: 'photo_access_denied',
      message: 'synthetic sensitive platform detail',
    );

    await expectLater(
      service.pickAndImport(),
      throwsA(
        isA<ImportFailure>().having(
          (failure) => failure.message,
          'message',
          'Pemilih foto tidak dapat dibuka. Periksa akses foto lalu coba lagi.',
        ),
      ),
    );
    expect(storageRequests, 0);
  });

  test('unavailable_plugin_explains_android_requirement', () async {
    selection.pickError = MissingPluginException('synthetic private detail');

    await expectLater(
      service.pickAndImport(),
      throwsA(
        isA<ImportFailure>().having(
          (failure) => failure.message,
          'message',
          'Pemilihan foto tersedia pada aplikasi Android.',
        ),
      ),
    );
    expect(storageRequests, 0);
  });
}

class _FakeSelectionSource implements ImageSelectionSource {
  File? selected;
  File? recovered;
  Object? pickError;
  int pickCalls = 0;
  int recoveryCalls = 0;

  @override
  Future<File?> pick() async {
    pickCalls++;
    if (pickError != null) throw pickError!;
    return selected;
  }

  @override
  Future<File?> recover() async {
    recoveryCalls++;
    return recovered;
  }
}
