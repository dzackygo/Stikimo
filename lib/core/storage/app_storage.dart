import 'dart:io';

import 'package:flutter/services.dart';

/// Root privat Android yang dikecualikan dari backup OS.
class AppStorage {
  static const _channel = MethodChannel('com.dzackygo.stikimo/storage');

  static Future<Directory> noBackupRoot() async {
    final path = await _channel.invokeMethod<String>('noBackupPath');
    if (path == null || path.isEmpty || !path.startsWith('/')) {
      throw const FileSystemException('Private storage unavailable');
    }
    return Directory(path);
  }
}
