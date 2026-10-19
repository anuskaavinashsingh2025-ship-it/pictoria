package com.example.pictoria

import android.os.Build
import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Small bridge for facts plugins don't expose (see platform_info.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pictora/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Used to choose between the system trash and permanent deletion.
                    "androidSdkInt" -> result.success(Build.VERSION.SDK_INT)
                    // Size of the internal data partition, as the OS reports it.
                    "deviceStorage" -> try {
                        val stats = StatFs(Environment.getDataDirectory().path)
                        result.success(
                            mapOf(
                                "totalBytes" to stats.totalBytes,
                                "availableBytes" to stats.availableBytes,
                            )
                        )
                    } catch (e: Exception) {
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
