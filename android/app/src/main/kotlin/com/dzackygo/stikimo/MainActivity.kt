package com.dzackygo.stikimo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.dzackygo.stikimo/storage")
            .setMethodCallHandler { call, result ->
                when {
                    call.method != "noBackupPath" -> result.notImplemented()
                    call.arguments != null -> result.error("invalid_arguments", "No arguments expected", null)
                    else -> result.success(noBackupFilesDir.absolutePath)
                }
            }
    }
}
