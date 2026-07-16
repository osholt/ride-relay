package me.osholt.ride_relay

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "me.osholt.ride_relay/nearby",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCapabilities" -> result.success(
                    mapOf(
                        "platform" to "android",
                        "nativeBridgeReady" to true,
                        "nearbyApiLinked" to false,
                        "status" to "phase0",
                    ),
                )
                else -> result.notImplemented()
            }
        }
    }
}
