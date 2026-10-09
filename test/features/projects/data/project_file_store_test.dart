import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stikimo/features/projects/data/project_file_store.dart';
import 'package:stikimo/features/projects/domain/project_document.dart';

const _project = '11111111-1111-4111-8111-111111111111';
const _otherProject = '11111111-1111-4111-8111-111111111112';
const _source = '22222222-2222-4222-8222-222222222222';
const _working = '33333333-3333-4333-8333-333333333333';
const _orphan = '44444444-4444-4444-8444-444444444444';
const _revision = '55555555-5555-4555-8555-555555555555';
const _oldRevision = '66666666-6666-4666-8666-666666666666';

void main() {
  late Directory temporary;
  late ProjectFileStore files;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('stikimo-project-test-');
    files = await ProjectFileStore.open(Directory('${temporary.path}/private'));
    await files.createProject(_project);
  });

  tearDown(() async {
    final path = temporary.absolute.uri;
    if (!path.path.startsWith(Directory.systemTemp.absolute.uri.path) ||
        !path.pathSegments.any(
          (part) => part.startsWith('stikimo-project-test-'),
        )) {
      throw StateError('Unexpected test cleanup location');
    }
    await temporary.delete(recursive: true);
  });

  test(
    'copies immutable source independently and rejects replacement',
    () async {
      final source = await File('${temporary.path}/selected.bin')
          .writeAsBytes([1, 8, 3, 4], flush: true);
      expect(await files.copyAsset(_project, _source, source), 4);
      final stored = File(files.assetPath(_project, _source));
      expect(await source.readAsBytes(), [1, 8, 3, 4]);
      await source.writeAsBytes([9, 9], flush: true);
      expect(await stored.readAsBytes(), [1, 8, 3, 4]);
      await expectLater(
        files.copyAsset(_project, _source, source),
        throwsA(isA<ProjectFailure>()),
      );
      await expectLater(
        files.writeAsset(_project, _source, Uint8List.fromList([7])),
        throwsA(isA<ProjectFailure>()),
      );
      expect(await stored.readAsBytes(), [1, 8, 3, 4]);
    },
  );

  test('rejects traversal and absolute asset identifiers', () {
    for (final unsafe in [
      '..',
      '../outside',
      r'C:\outside',
      '/tmp/outside',
      'not-a-uuid',
    ]) {
      expect(
        () => files.assetPath(unsafe, _source),
        throwsA(isA<ProjectFailure>()),
      );
      expect(
        () => files.assetPath(_project, unsafe),
        throwsA(isA<ProjectFailure>()),
      );
    }
    for (final unsafe in [
      '../outside',
      '/outside',
      'projects/../outside',
      r'projects\outside',
    ]) {
      expect(() => files.checkedPath(unsafe), throwsA(isA<ProjectFailure>()));
    }
  });

  test('does not overwrite an existing project directory', () async {
    await expectLater(
      files.createProject(_project),
      throwsA(isA<ProjectFailure>()),
    );
    expect(
      await File(files.checkedPath('projects/$_project/.stikimo-project'))
          .readAsString(),
      _project,
    );
  });

  test(
    'writes complete immutable JSON revision without leftover temp file',
    () async {
      final document = _document();
      await files.writeRevision(_revision, document);
      final loaded = await files.readRevision(_project, _revision);
      expect(loaded.toJson(), document.toJson());
      expect(
        await File(
          files.checkedPath('projects/$_project/revisions/$_revision.tmp'),
        ).exists(),
        isFalse,
      );
      final before = await File(files.revisionPath(_project, _revision))
          .readAsBytes();
      await expectLater(
        files.writeRevision(_revision, document.copyWith(name: 'Changed')),
        throwsA(isA<ProjectFailure>()),
      );
      expect(
        await File(files.revisionPath(_project, _revision)).readAsBytes(),
        before,
      );
    },
  );

  test(
    'rejects truncated JSON, future version and non-object revision',
    () async {
      final revision = File(files.revisionPath(_project, _revision));
      await revision.writeAsString('{"version":');
      await expectLater(
        files.readRevision(_project, _revision),
        throwsA(isA<FormatException>()),
      );
      await revision.writeAsString(
        jsonEncode({..._document().toJson(), 'version': 999}),
      );
      await expectLater(
        files.readRevision(_project, _revision),
        throwsA(isA<ProjectFailure>()),
      );
      await revision.writeAsString('[]');
      await expectLater(
        files.readRevision(_project, _revision),
        throwsA(isA<ProjectFailure>()),
      );
    },
  );

  test('bounds revision reads before parsing oversized JSON', () async {
    final output = await File(files.revisionPath(_project, _revision))
        .open(mode: FileMode.write);
    await output.truncate(ProjectDocument.maxEncodedBytes + 1);
    await output.close();
    await expectLater(
      files.readRevision(_project, _revision),
      throwsA(isA<ProjectFailure>()),
    );
  });

  test(
    'rejects empty asset writes and missing or altered asset lengths',
    () async {
      await expectLater(
        files.writeAsset(_project, _source, Uint8List(0)),
        throwsA(isA<ProjectFailure>()),
      );
      final metadata = _document().assets.first;
      await expectLater(
        files.verifyAsset(_project, metadata),
        throwsA(isA<ProjectFailure>()),
      );
      await files.writeAsset(
        _project,
        _source,
        Uint8List.fromList([1, 2, 3, 4]),
      );
      await files.verifyAsset(_project, metadata);
      await File(files.assetPath(_project, _source)).writeAsBytes([1]);
      await expectLater(
        files.verifyAsset(_project, metadata),
        throwsA(isA<ProjectFailure>()),
      );
    },
  );

  test(
    'cleans only uncommitted UUID files and retains committed history',
    () async {
      for (final id in [_source, _working, _orphan]) {
        await files.writeAsset(_project, id, Uint8List.fromList([1]));
      }
      await files.writeRevision(_revision, _document());
      await files.writeRevision(_oldRevision, _document());
      await files.writeRevision(_orphan, _document());
      final pending = File(
        files.checkedPath('projects/$_project/revisions/$_revision.tmp'),
      );
      await pending.writeAsString('partial');
      final unrelated = File(
        files.checkedPath('projects/$_project/assets/notes.txt'),
      );
      await unrelated.writeAsString('leave this alone');

      await files.cleanupUncommitted(
        _project,
        assetIds: {_source, _working},
        revisionIds: {_revision, _oldRevision},
      );

      expect(await File(files.assetPath(_project, _source)).exists(), isTrue);
      expect(await File(files.assetPath(_project, _working)).exists(), isTrue);
      expect(await File(files.assetPath(_project, _orphan)).exists(), isFalse);
      expect(
        await File(files.revisionPath(_project, _revision)).exists(),
        isTrue,
      );
      expect(
        await File(files.revisionPath(_project, _oldRevision)).exists(),
        isTrue,
      );
      expect(
        await File(files.revisionPath(_project, _orphan)).exists(),
        isFalse,
      );
      expect(await pending.exists(), isFalse);
      expect(await unrelated.readAsString(), 'leave this alone');
    },
  );

  test(
    'removes unpublished owned project but preserves unknown directories',
    () async {
      await files.createProject(_otherProject);
      final unknown = await Directory(files.projectPath(_orphan)).create();
      final unowned = await File('${unknown.path}/keep.txt')
          .writeAsString('keep');
      await files.cleanupUnpublishedProjects({_project});
      expect(await Directory(files.projectPath(_project)).exists(), isTrue);
      expect(
        await Directory(files.projectPath(_otherProject)).exists(),
        isFalse,
      );
      expect(await unowned.readAsString(), 'keep');
    },
  );

  test('deletion requires marker matching the target UUID', () async {
    final marker = File(
      files.checkedPath('projects/$_project/.stikimo-project'),
    );
    await marker.writeAsString(_otherProject);
    await expectLater(
      files.removeProject(_project),
      throwsA(isA<ProjectFailure>()),
    );
    expect(await Directory(files.projectPath(_project)).exists(), isTrue);
    await marker.writeAsString(_project);
    await files.removeProject(_project);
    expect(await Directory(files.projectPath(_project)).exists(), isFalse);
  });

  test('rejects asset symlinks without touching external target', () async {
    final external = await File('${temporary.path}/outside.bin')
        .writeAsBytes([9]);
    final link = Link(files.assetPath(_project, _source));
    try {
      await link.create(external.path);
    } on FileSystemException {
      markTestSkipped('Host does not permit creating symbolic links.');
      return;
    }
    expect(
      () => files.assetPath(_project, _source),
      throwsA(isA<ProjectFailure>()),
    );
    await expectLater(
      files.removeAsset(_project, _source),
      throwsA(isA<ProjectFailure>()),
    );
    expect(await external.readAsBytes(), [9]);
  });
}

ProjectDocument _document() => ProjectDocument(
  id: _project,
  name: 'Test',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  sourceAssetId: _source,
  assets: [
    ProjectAsset(id: _source, role: AssetRole.original, byteLength: 4),
    ProjectAsset(
      id: _working,
      role: AssetRole.working,
      byteLength: 4,
      width: 2,
      height: 2,
    ),
  ],
  layers: [],
);
