package com.example.mybrev_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mybrev/protected-catalog")
            .setMethodCallHandler { call, result ->
                if (call.method != "directory") {
                    result.notImplemented()
                } else {
                    val target = File(noBackupFilesDir, "protected-prayers-v1")
                    if (target.isDirectory || target.mkdirs()) result.success(target.absolutePath)
                    else result.error("STORAGE", null, null)
                }
            }
    }
}
