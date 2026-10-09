import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

import 'package:stikimo/core/errors/app_error_view.dart';
import 'package:stikimo/main.dart' as bootstrap;

void main() {
  testWidgets('opens_stikimo_with_local_privacy_message', (tester) async {
    await tester.pumpWidget(testApp());
    expect(find.text('Stikimo'), findsOneWidget);
    expect(find.text('Foto pribadi, tetap di perangkat.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses_dark_theme_when_system_requests_it', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(testApp());
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('fits_small_screen_with_large_text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(testApp());
    expect(tester.takeException(), isNull);
  });

  testWidgets('error_fallback_works_without_app_ancestors', (tester) async {
    await tester.pumpWidget(const AppErrorView());
    expect(find.text('Tampilan tidak dapat dimuat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bootstrap_replaces_build_failure_with_safe_fallback', (
    tester,
  ) async {
    final previousBuilder = ErrorWidget.builder;
    try {
      bootstrap.main();
      await tester.pump();
      await tester.pumpWidget(
        Builder(builder: (_) => throw StateError('synthetic private detail')),
      );
      expect(tester.takeException(), isStateError);
      expect(find.text('Tampilan tidak dapat dimuat'), findsOneWidget);
      expect(find.textContaining('synthetic private detail'), findsNothing);
    } finally {
      // Flutter memeriksa global builder sebelum callback addTearDown berjalan.
      ErrorWidget.builder = previousBuilder;
    }
  });
}
