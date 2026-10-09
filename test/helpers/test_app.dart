import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stikimo/app/app.dart';
import 'package:stikimo/features/image_import/data/image_import_service.dart';
import 'package:stikimo/features/image_import/domain/imported_image.dart';
import 'package:stikimo/features/image_import/presentation/import_controller.dart';

Widget testApp({ImageImportService? importService}) => ProviderScope(
  overrides: [
    imageImportServiceProvider.overrideWithValue(
      importService ?? EmptyImportService(),
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
