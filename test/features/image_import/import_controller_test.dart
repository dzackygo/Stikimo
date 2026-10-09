import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stikimo/features/image_import/data/image_import_service.dart';
import 'package:stikimo/features/image_import/domain/import_failure.dart';
import 'package:stikimo/features/image_import/domain/imported_image.dart';
import 'package:stikimo/features/image_import/presentation/import_controller.dart';

const _image = ImportedImage(
  id: 'fixture',
  sourcePath: '/synthetic/source.png',
  previewPath: '/synthetic/preview.png',
  width: 24,
  height: 16,
);

void main() {
  late _FakeImageImportService service;
  late ProviderContainer container;

  setUp(() {
    service = _FakeImageImportService();
    container = ProviderContainer(
      overrides: [imageImportServiceProvider.overrideWithValue(service)],
    );
  });

  tearDown(() => container.dispose());

  test('starts_empty_without_opening_picker_or_recovery', () {
    final state = container.read(importControllerProvider);

    expect(state.isBusy, isFalse);
    expect(state.image, isNull);
    expect(state.message, isNull);
    expect(service.pickCalls, 0);
    expect(service.recoveryCalls, 0);
  });

  test('reports_loading_then_selected_image', () async {
    final pending = Completer<ImportedImage?>();
    service.pickResult = () => pending.future;
    final states = <ImportState>[];
    container.listen(importControllerProvider, (_, next) => states.add(next));

    final operation = container.read(importControllerProvider.notifier).pick();
    expect(container.read(importControllerProvider).isBusy, isTrue);

    pending.complete(_image);
    await operation;

    expect(states.map((state) => state.isBusy), [true, false]);
    expect(states.last.image, same(_image));
    expect(states.last.message, isNull);
  });

  test('cancelled_selection_preserves_previously_selected_image', () async {
    final controller = container.read(importControllerProvider.notifier);
    service.pickResult = () async => _image;
    await controller.pick();
    service.pickResult = () async => null;

    await controller.pick();

    final state = container.read(importControllerProvider);
    expect(state.isBusy, isFalse);
    expect(state.image, same(_image));
    expect(state.message, 'Pemilihan foto dibatalkan.');
  });

  test('known_failure_preserves_image_and_shows_safe_message', () async {
    final controller = container.read(importControllerProvider.notifier);
    service.pickResult = () async => _image;
    await controller.pick();
    service.pickResult = () async =>
        throw const ImportFailure('Foto tidak dapat dibaca. Pilih foto lain.');

    await controller.pick();

    final state = container.read(importControllerProvider);
    expect(state.isBusy, isFalse);
    expect(state.image, same(_image));
    expect(state.message, 'Foto tidak dapat dibaca. Pilih foto lain.');
  });

  test('unknown_failure_does_not_expose_private_details', () async {
    final controller = container.read(importControllerProvider.notifier);
    service.pickResult = () async => _image;
    await controller.pick();
    service.pickResult = () async =>
        throw StateError('synthetic secret /private/photo.png');

    await controller.pick();

    final state = container.read(importControllerProvider);
    expect(state.isBusy, isFalse);
    expect(state.image, same(_image));
    expect(state.message, 'Foto tidak dapat diimpor. Silakan coba lagi.');
  });

  test('new_selection_clears_previous_message_while_loading', () async {
    final controller = container.read(importControllerProvider.notifier);
    await controller.pick();
    final pending = Completer<ImportedImage?>();
    service.pickResult = () => pending.future;

    final operation = controller.pick();

    expect(container.read(importControllerProvider).message, isNull);
    pending.complete(_image);
    await operation;
    expect(container.read(importControllerProvider).message, isNull);
  });

  test('recovery_runs_once_and_restores_image', () async {
    final controller = container.read(importControllerProvider.notifier);
    final pending = Completer<ImportedImage?>();
    service.recoveryResult = () => pending.future;

    final operation = controller.recover();
    await controller.recover();
    expect(container.read(importControllerProvider).isBusy, isTrue);
    pending.complete(_image);
    await operation;
    await controller.recover();

    expect(service.recoveryCalls, 1);
    expect(container.read(importControllerProvider).image, same(_image));
    expect(container.read(importControllerProvider).isBusy, isFalse);
  });

  test('empty_recovery_is_silent_and_runs_once', () async {
    final controller = container.read(importControllerProvider.notifier);

    await controller.recover();
    await controller.recover();

    final state = container.read(importControllerProvider);
    expect(service.recoveryCalls, 1);
    expect(state.isBusy, isFalse);
    expect(state.image, isNull);
    expect(state.message, isNull);
  });

  test('failed_recovery_is_safe_and_not_retried_automatically', () async {
    final controller = container.read(importControllerProvider.notifier);
    service.recoveryResult = () async =>
        throw const ImportFailure('Foto sebelumnya tidak dapat dipulihkan.');

    await controller.recover();
    await controller.recover();

    expect(service.recoveryCalls, 1);
    expect(container.read(importControllerProvider).isBusy, isFalse);
    expect(
      container.read(importControllerProvider).message,
      'Foto sebelumnya tidak dapat dipulihkan.',
    );
  });

  test('ignores_selection_while_another_selection_is_busy', () async {
    final pending = Completer<ImportedImage?>();
    service.pickResult = () => pending.future;
    final controller = container.read(importControllerProvider.notifier);

    final operation = controller.pick();
    await controller.pick();

    expect(service.pickCalls, 1);
    expect(container.read(importControllerProvider).isBusy, isTrue);
    pending.complete(_image);
    await operation;
    expect(container.read(importControllerProvider).image, same(_image));
  });

  test('ignores_selection_while_recovery_is_busy', () async {
    final pending = Completer<ImportedImage?>();
    service.recoveryResult = () => pending.future;
    final controller = container.read(importControllerProvider.notifier);

    final operation = controller.recover();
    await controller.pick();

    expect(service.pickCalls, 0);
    pending.complete(_image);
    await operation;
    expect(container.read(importControllerProvider).image, same(_image));
  });

  test(
    'old_operation_cannot_replace_state_after_provider_is_rebuilt',
    () async {
      final pending = Completer<ImportedImage?>();
      service.pickResult = () => pending.future;
      final operation = container
          .read(importControllerProvider.notifier)
          .pick();
      container.invalidate(importControllerProvider);
      const newImage = ImportedImage(
        id: 'new-fixture',
        sourcePath: '/synthetic/new-source.png',
        previewPath: '/synthetic/new-preview.png',
        width: 8,
        height: 12,
      );
      service.pickResult = () async => newImage;
      await container.read(importControllerProvider.notifier).pick();

      pending.complete(_image);
      await operation;

      expect(container.read(importControllerProvider).image, same(newImage));
      expect(container.read(importControllerProvider).isBusy, isFalse);
    },
  );

  test('ignores_success_after_provider_is_disposed', () async {
    final pending = Completer<ImportedImage?>();
    service.pickResult = () => pending.future;
    final operation = container.read(importControllerProvider.notifier).pick();
    container.dispose();

    pending.complete(_image);

    await expectLater(operation, completes);
  });

  test('ignores_failure_after_provider_is_disposed', () async {
    final pending = Completer<ImportedImage?>();
    service.pickResult = () => pending.future;
    final operation = container.read(importControllerProvider.notifier).pick();
    container.dispose();

    pending.completeError(StateError('synthetic private detail'));

    await expectLater(operation, completes);
  });
}

class _FakeImageImportService extends ImageImportService {
  Future<ImportedImage?> Function() pickResult = () async => null;
  Future<ImportedImage?> Function() recoveryResult = () async => null;
  int pickCalls = 0;
  int recoveryCalls = 0;

  @override
  Future<ImportedImage?> pickAndImport() {
    pickCalls++;
    return pickResult();
  }

  @override
  Future<ImportedImage?> recoverAndImport() {
    recoveryCalls++;
    return recoveryResult();
  }
}
