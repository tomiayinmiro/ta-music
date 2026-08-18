package com.tamusic.app.ta_music

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Must extend AudioServiceActivity, not FlutterActivity, per audio_service's
// "Custom Android activity" docs: AudioServiceActivity overrides
// provideFlutterEngine() to return the plugin's own shared, cached engine.
// Without this, audio_service's background service can't find "the correct
// FlutterEngine" and spins up a second, independent one — which reruns the
// whole Dart main() a second time (see the AppDatabase fix in database.dart
// for why that's dangerous, not just wasteful).
class MainActivity : AudioServiceActivity() {
    private val channelName = "com.tamusic.app.ta_music/media_store"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "queryAudioFiles" -> {
                    try {
                        result.success(MediaStoreScanner.queryAudioFiles(applicationContext))
                    } catch (e: Exception) {
                        result.error("QUERY_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
