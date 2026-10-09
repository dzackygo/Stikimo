import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('home opens each destination and back returns home', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    for (final destination in <String, String>{
      'Buat stiker': 'Mulai dari foto',
      'Proyek saya': 'Belum ada proyek',
      'Paket stiker': 'Belum ada paket',
      'Tentang & privasi': 'Dibuat di perangkatmu',
    }.entries) {
      final button = find.text(destination.key);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text(destination.value), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Stikimo'), findsOneWidget);
    }
  });

  testWidgets('empty projects opens creation and back preserves navigation', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.tap(find.text('Proyek saya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat stiker'));
    await tester.pumpAndSettle();
    expect(find.text('Mulai dari foto'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Belum ada proyek'), findsOneWidget);
  });

  testWidgets('Android back returns from a destination to home', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.tap(find.text('Buat stiker'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Stikimo'), findsOneWidget);
    expect(find.text('Mulai dari foto'), findsNothing);
  });

  testWidgets('all destinations fit a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(testApp());
    for (final label in [
      'Buat stiker',
      'Proyek saya',
      'Paket stiker',
      'Tentang & privasi',
    ]) {
      final button = find.text(label);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
