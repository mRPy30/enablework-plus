package com.enableworkplus.enablework_plus

import android.speech.tts.TextToSpeech
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var textToSpeech: TextToSpeech? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        textToSpeech = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                textToSpeech?.language = Locale("en", "PH")
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "enablework_plus/tts")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val text = call.argument<String>("text").orEmpty()
                        if (text.isBlank()) {
                            result.error("EMPTY_TEXT", "Nothing to read aloud", null)
                        } else {
                            textToSpeech?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "job-fit")
                            result.success(null)
                        }
                    }
                    "stop" -> {
                        textToSpeech?.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        super.onDestroy()
    }
}
