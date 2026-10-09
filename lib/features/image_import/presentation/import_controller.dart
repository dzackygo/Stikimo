import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/image_import_service.dart';
import '../domain/import_failure.dart';
import '../domain/imported_image.dart';

final imageImportServiceProvider = Provider<ImageImportService>(
  (ref) => ImageImportService(),
);

// State dan recovery bertahan selama ProviderScope aplikasi hidup.
final importControllerProvider =
    NotifierProvider<ImageImportController, ImportState>(
      ImageImportController.new,
    );

class ImportState {
  const ImportState({this.isBusy = false, this.image, this.message});

  final bool isBusy;
  final ImportedImage? image;
  final String? message;
}

class ImageImportController extends Notifier<ImportState> {
  bool _hasRecovered = false;

  @override
  ImportState build() => const ImportState();

  Future<void> pick() async {
    if (!ref.mounted || state.isBusy) return;
    await _import(recovery: false);
  }

  /// Dipanggil oleh lifecycle UI; tidak membuka picker saat build provider.
  Future<void> recover() async {
    if (!ref.mounted || state.isBusy || _hasRecovered) return;
    _hasRecovered = true;
    await _import(recovery: true);
  }

  Future<void> _import({required bool recovery}) async {
    final operationRef = ref;
    final previousImage = state.image;
    state = ImportState(isBusy: true, image: previousImage);

    try {
      final service = operationRef.read(imageImportServiceProvider);
      final image = await (recovery
          ? service.recoverAndImport()
          : service.pickAndImport());
      // Ref lama juga menjadi unmounted jika provider dibangun ulang.
      if (!operationRef.mounted) return;
      state = ImportState(
        image: image ?? previousImage,
        message: image == null && !recovery
            ? 'Pemilihan foto dibatalkan.'
            : null,
      );
    } on ImportFailure catch (failure) {
      if (!operationRef.mounted) return;
      state = ImportState(image: previousImage, message: failure.message);
    } catch (_) {
      if (!operationRef.mounted) return;
      state = ImportState(
        image: previousImage,
        message: 'Foto tidak dapat diimpor. Silakan coba lagi.',
      );
    }
  }
}
