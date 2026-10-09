import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stikimo/features/image_import/domain/import_failure.dart';
import 'package:stikimo/features/image_import/domain/imported_image.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets(
    'picker loading disables repeat action and cancellation is visible',
    (tester) async {
      final service = _ControlledImport();
      await tester.pumpWidget(testApp(importService: service));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buat stiker'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilih foto'));
      await tester.pump();
      expect(find.text('Menyiapkan foto…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      service.result.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Pemilihan foto dibatalkan.'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('safe import error shown and retry remains available', (
    tester,
  ) async {
    final service = _ControlledImport();
    await tester.pumpWidget(testApp(importService: service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat stiker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih foto'));
    await tester.pump();
    service.result.completeError(
      const ImportFailure('Gambar rusak. Pilih ulang foto.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gambar rusak. Pilih ulang foto.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('startup recovers once before navigating to selection', (
    tester,
  ) async {
    final service = _ControlledImport();
    await tester.pumpWidget(testApp(importService: service));
    await tester.pumpAndSettle();
    expect(service.recoveryCount, 1);
    await tester.tap(find.text('Buat stiker'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(service.recoveryCount, 1);
  });
}

class _ControlledImport extends EmptyImportService {
  final result = Completer<ImportedImage?>();
  var recoveryCount = 0;

  @override
  Future<ImportedImage?> pickAndImport() => result.future;

  @override
  Future<ImportedImage?> recoverAndImport() async {
    recoveryCount++;
    return null;
  }
}
