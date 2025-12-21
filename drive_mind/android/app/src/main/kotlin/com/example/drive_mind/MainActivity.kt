package com.example.drive_mind

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "drive_mind/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "openNativeActivity" -> {
                    val intent = Intent(this, NativeDetectionActivity::class.java)
                    startActivity(intent)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }
}
