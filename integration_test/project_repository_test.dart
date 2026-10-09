import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:stikimo/core/storage/app_storage.dart';
import 'package:stikimo/features/image_import/domain/imported_image.dart';
import 'package:stikimo/features/projects/data/local_project_repository.dart';
import 'package:stikimo/features/projects/domain/project_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  String id() => const Uuid().v4();
  late Directory testRoot;
  late LocalProjectRepository repository;
  late ImportedImage imported;
  late List<int> original;

  setUp(() async {
    final privateRoot = await AppStorage.noBackupRoot();
    testRoot = Directory('${privateRoot.path}/integration-data-${id()}');
    await testRoot.create();
    final fixture = image.Image(width: 8, height: 6, numChannels: 4)
      ..clear(image.ColorRgba8(20, 90, 180, 128));
    original = image.encodePng(fixture);
    final source = File('${testRoot.path}/picked.png');
    final preview = File('${testRoot.path}/preview.png');
    await source.writeAsBytes(original);
    await preview.writeAsBytes(original);
    imported = ImportedImage(
      id: id(),
      sourcePath: source.path,
      previewPath: preview.path,
      width: 8,
      height: 6,
    );
    repository = await LocalProjectRepository.open(root: testRoot);
  });

  tearDown(() async {
    await repository.close();
    final privateRoot = await AppStorage.noBackupRoot();
    if (!testRoot.path.startsWith('${privateRoot.path}/integration-data-')) {
      throw StateError('Test cleanup outside owned directory');
    }
    await testRoot.delete(recursive: true);
  });

  testWidgets(
    'reopen cleans unpublished files and completes pending deletion',
    (tester) async {
      final keep = await repository.create(imported, name: 'Tetap ada');
      final deleted = await repository.create(imported, name: 'Sedang dihapus');
      await repository.close();
      final pendingId = id();
      final pending = Directory('${testRoot.path}/projects/$pendingId');
      await pending.create();
      await File('${pending.path}/.stikimo-project').writeAsString(pendingId);
      await File('${pending.path}/partial.bin').writeAsBytes([1, 2, 3]);
      final extraAsset = File(
        '${testRoot.path}/projects/${keep.document.id}/assets/${id()}.bin',
      );
      final extraRevision = File(
        '${testRoot.path}/projects/${keep.document.id}/revisions/${id()}.tmp',
      );
      await extraAsset.writeAsBytes([1]);
      await extraRevision.writeAsString('{}');
      final control = await openDatabase('${testRoot.path}/stikimo.sqlite');
      await control.update(
        'projects',
        {'is_deleted': 1},
        where: 'id = ?',
        whereArgs: [deleted.document.id],
      );
      await control.close();
      repository = await LocalProjectRepository.open(root: testRoot);
      expect((await repository.list()).single.id, keep.document.id);
      expect(
        (await repository.load(keep.document.id)).document.name,
        'Tetap ada',
      );
      expect(await pending.exists(), isFalse);
      expect(await extraAsset.exists(), isFalse);
      expect(await extraRevision.exists(), isFalse);
      expect(
        await Directory('${testRoot.path}/projects/${deleted.document.id}')
            .exists(),
        isFalse,
      );
    },
  );

  testWidgets(
    'Android rejects linked assets and leaves their target untouched',
    (tester) async {
      final saved = await repository.create(imported, name: 'Uji tautan');
      final asset = saved.document.assets.firstWhere(
        (item) => item.role == AssetRole.working,
      );
      final assetPath = repository.assetPath(saved.document.id, asset.id);
      final outside = File('${testRoot.path}/outside-owned-project.txt');
      await outside.writeAsString('synthetic target');
      await File(assetPath).delete();
      await Link(assetPath).create(outside.path);
      expect(
        () => repository.assetPath(saved.document.id, asset.id),
        throwsA(isA<ProjectFailure>()),
      );
      await expectLater(
        repository.load(saved.document.id),
        throwsA(isA<ProjectFailure>()),
      );
      expect(await outside.readAsString(), 'synthetic target');
    },
  );

  testWidgets(
    'SQLite reopen preserves all layer data, masks and independent copies',
    (tester) async {
      final created = await repository.create(imported, name: 'Fixture proyek');
      final mask = ProjectAssetWrite(
        id: id(),
        role: AssetRole.mask,
        bytes: image.encodePng(
          image.Image(width: 8, height: 6, numChannels: 4)
            ..clear(image.ColorRgba8(255, 255, 255, 96)),
        ),
        width: 8,
        height: 6,
      );
      final initialLayer = created.document.layers.single;
      final initialContent = initialLayer.content as ImageLayerContent;
      final document = created.document.copyWith(
        assets: [...created.document.assets, mask.asset],
        layers: [
          ProjectLayer(
            id: id(),
            centerX: .2,
            centerY: .3,
            width: .7,
            height: .3,
            rotation: -.2,
            isLocked: true,
            content: TextLayerContent(
              text: 'Halo 🌿',
              fontSize: .1,
              colorArgb: 0xff006c60,
              alignment: TextAlignment.right,
              outlineColorArgb: 0xffffffff,
              outlineWidth: .01,
            ),
          ),
          initialLayer.copyWith(
            centerX: .4,
            rotation: .25,
            content: initialContent.copyWith(
              maskAssetId: mask.id,
              flipX: true,
              crop: NormalizedRect(x: .1, y: .2, width: .8, height: .6),
              backgroundRemoval: BackgroundRemovalParameters(
                colorArgb: 0xff00ff00,
                tolerance: .15,
                softness: .03,
              ),
            ),
          ),
          ProjectLayer(
            id: id(),
            isVisible: false,
            content: DrawingLayerContent(
              strokes: [
                DrawingStroke(
                  points: [
                    DrawingPoint(x: .1, y: .2),
                    DrawingPoint(x: .7, y: .8),
                  ],
                  colorArgb: 0xff123456,
                  width: .03,
                  opacity: .5,
                ),
                DrawingStroke(
                  points: [DrawingPoint(x: .4, y: .4)],
                  colorArgb: 0xffffffff,
                  width: .1,
                  tool: DrawingTool.eraser,
                ),
              ],
            ),
          ),
        ],
      );
      final saved = await repository.save(
        created,
        document: document,
        newAssets: [mask],
      );
      final expected = saved.document.toJson();
      await repository.close();
      repository = await LocalProjectRepository.open(root: testRoot);
      final reloaded = await repository.load(saved.document.id);
      expect(reloaded.document.toJson(), expected);
      expect(reloaded.revisionId, saved.revisionId);
      expect(
        await File(repository.assetPath(saved.document.id, mask.id))
            .readAsBytes(),
        mask.bytes,
      );
      final renamed = await repository.rename(reloaded, 'Proyek diubah');
      expect((await repository.list()).single.name, 'Proyek diubah');
      expect(
        renamed.document.layers.map((layer) => layer.toJson()).toList(),
        saved.document.layers.map((layer) => layer.toJson()).toList(),
      );
      final copy = await repository.duplicate(renamed.document.id);
      expect(copy.document.id, isNot(renamed.document.id));
      for (final asset in copy.document.assets) {
        expect(
          await File(repository.assetPath(copy.document.id, asset.id))
              .readAsBytes(),
          await File(repository.assetPath(renamed.document.id, asset.id))
              .readAsBytes(),
        );
      }
      // Pemilik proyek terpisah dari draf; draf boleh diganti/dihapus.
      await File(imported.previewPath).delete();
      expect(await File(imported.sourcePath).readAsBytes(), original);
      expect(
        await File(
          repository.assetPath(copy.document.id, copy.document.sourceAssetId),
        ).readAsBytes(),
        original,
      );
      await repository.delete(renamed.document.id);
      expect((await repository.list()).single.id, copy.document.id);
      expect(
        (await repository.load(copy.document.id)).document.layers.length,
        3,
      );
      await repository.close();
      repository = await LocalProjectRepository.open(root: testRoot);
      expect((await repository.list()).single.id, copy.document.id);
    },
  );

  testWidgets(
    'stale save and SQLite commit failure preserve published revision',
    (tester) async {
      final created = await repository.create(imported, name: 'Awal');
      final updated = await repository.rename(created, 'Terbaru');
      await expectLater(
        repository.rename(created, 'Kedaluwarsa'),
        throwsA(isA<ProjectFailure>()),
      );
      final control = await openDatabase('${testRoot.path}/stikimo.sqlite');
      await control.execute(
        "CREATE TRIGGER fail_project_update BEFORE UPDATE ON projects BEGIN SELECT RAISE(ABORT, 'synthetic write failure'); END",
      );
      await expectLater(
        repository.rename(updated, 'Gagal'),
        throwsA(isA<ProjectFailure>()),
      );
      await control.execute('DROP TRIGGER fail_project_update');
      await control.close();
      final loaded = await repository.load(updated.document.id);
      expect(loaded.document.name, 'Terbaru');
      expect(loaded.revisionId, updated.revisionId);
      expect(
        await File(
          repository.assetPath(
            loaded.document.id,
            loaded.document.sourceAssetId,
          ),
        ).readAsBytes(),
        original,
      );
    },
  );

  testWidgets(
    'rejects unknown document version and missing asset without rewriting data',
    (tester) async {
      final saved = await repository.create(imported, name: 'Uji berkas');
      await expectLater(
        repository.load('../outside'),
        throwsA(isA<ProjectFailure>()),
      );
      final file = File(
        '${testRoot.path}/projects/${saved.document.id}/revisions/${saved.revisionId}.json',
      );
      final before = await file.readAsString();
      final json = jsonDecode(before) as Map<String, dynamic>;
      json['version'] = 999;
      final changed = jsonEncode(json);
      await file.writeAsString(changed);
      await expectLater(
        repository.load(saved.document.id),
        throwsA(isA<ProjectFailure>()),
      );
      expect(await file.readAsString(), changed);
      await file.writeAsString(before);
      final working = saved.document.assets.firstWhere(
        (asset) => asset.role == AssetRole.working,
      );
      await File(repository.assetPath(saved.document.id, working.id)).delete();
      await expectLater(
        repository.load(saved.document.id),
        throwsA(isA<ProjectFailure>()),
      );
    },
  );
}
