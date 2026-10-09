import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stikimo/core/storage/app_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.dzackygo.stikimo/storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('requests_native_no_backup_path_without_arguments', () async {
    const path = '/data/user/0/com.dzackygo.stikimo/no_backup';
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return path;
    });

    final directory = await AppStorage.noBackupRoot();

    expect(directory.path, path);
    expect(received!.method, 'noBackupPath');
    expect(received!.arguments, isNull);
  });

  for (final entry in <String, String?>{
    'null': null,
    'empty': '',
    'relative': 'private/imports',
    'parent_relative': '../private',
    'content_uri': 'content://photos/1',
    'non_android_path': 'C:/private',
  }.entries) {
    test('rejects_${entry.key}_native_path', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => entry.value);

      await expectLater(
        AppStorage.noBackupRoot(),
        throwsA(
          isA<FileSystemException>().having(
            (failure) => failure.message,
            'message',
            'Private storage unavailable',
          ),
        ),
      );
    });
  }

  test(
    'propagates_native_storage_failure_instead_of_selecting_fallback',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'storage_unavailable');
      });

      await expectLater(
        AppStorage.noBackupRoot(),
        throwsA(
          isA<PlatformException>().having(
            (failure) => failure.code,
            'code',
            'storage_unavailable',
          ),
        ),
      );
    },
  );
}
