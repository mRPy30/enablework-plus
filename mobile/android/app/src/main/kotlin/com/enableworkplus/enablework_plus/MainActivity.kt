package com.enableworkplus.enablework_plus

import android.app.AlertDialog
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import io.flutter.plugin.common.EventChannel
import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.SpeechRecognizer
import android.content.Intent
import android.speech.RecognizerIntent
import android.speech.tts.TextToSpeech
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var welcomePlayer: MediaPlayer? = null
    private var connectivityCallback: ConnectivityManager.NetworkCallback? = null
    private val connectivity get() = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val audio = getSystemService(AUDIO_SERVICE) as AudioManager
        if (savedInstanceState == null && audio.ringerMode == AudioManager.RINGER_MODE_NORMAL &&
            audio.getStreamVolume(AudioManager.STREAM_MUSIC) > 0) {
            welcomePlayer = MediaPlayer.create(this, R.raw.enablework_welcome)
            welcomePlayer?.setOnCompletionListener {
                it.release()
                welcomePlayer = null
            }
            welcomePlayer?.start()
        }
    }

    private fun online(): Boolean {
        val caps = connectivity.getNetworkCapabilities(connectivity.activeNetwork)
        return caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
    }

    private fun unsubscribe() {
        connectivityCallback?.let { connectivity.unregisterNetworkCallback(it) }
        connectivityCallback = null
    }
    private var textToSpeech: TextToSpeech? = null

    private var voiceResult: MethodChannel.Result? = null
    private val voiceRequest = 7132
    private var recognizer: SpeechRecognizer? = null
    private var listeningDialog: AlertDialog? = null
    private var voicePrompt = ""

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "enablework_plus/connectivity")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    unsubscribe()
                    val callback = object : ConnectivityManager.NetworkCallback() {
                        private fun report() = runOnUiThread {
                            if (connectivityCallback === this) events.success(online())
                        }
                        override fun onAvailable(network: Network) = report()
                        override fun onLost(network: Network) = report()
                        override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) = report()
                    }
                    connectivityCallback = callback
                    connectivity.registerDefaultNetworkCallback(callback)
                    events.success(online())
                }
                override fun onCancel(arguments: Any?) = unsubscribe()
            })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "enablework_plus/voice_search")
            .setMethodCallHandler { call, result ->
                if (call.method != "listen") {
                    result.notImplemented()
                } else if (voiceResult != null) {
                    result.error("BUSY", "Voice search is already open", null)
                } else {
                    textToSpeech?.stop()
                    voiceResult = result
                    voicePrompt = call.argument<String>("prompt") ?: "Say a job title, company or city"
                    if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                        beginListening()
                    } else {
                        AlertDialog.Builder(this)
                            .setTitle("Use voice input?")
                            .setMessage("Microphone access lets Android turn your words into editable text. You can also type.")
                            .setPositiveButton("Continue") { _, _ -> requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), voiceRequest) }
                            .setNegativeButton("Use keyboard") { _, _ -> finishListening() }
                            .setOnCancelListener { finishListening() }.show()
                    }
                }
            }
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
                        val accessibility = getSystemService(ACCESSIBILITY_SERVICE) as android.view.accessibility.AccessibilityManager
                        if (call.argument<Boolean>("automatic") == true && accessibility.isTouchExplorationEnabled) {
                            result.success(null)
                        } else if (text.isBlank()) {
                            result.error("EMPTY_TEXT", "Nothing to read aloud", null)
                        } else {
                            val engine = textToSpeech
                            val requested = call.argument<String>("language") ?: "en-PH"
                            if (engine != null && engine.setLanguage(Locale.forLanguageTag(requested)) < 0) {
                                engine.language = Locale.getDefault()
                            }
                            if (engine != null && text.chunked(TextToSpeech.getMaxSpeechInputLength()).withIndex().all { (i, part) ->
                                engine.speak(part, if (i == 0) TextToSpeech.QUEUE_FLUSH else TextToSpeech.QUEUE_ADD, null, "enablework-$i") == TextToSpeech.SUCCESS
                            }) {
                                result.success(null)
                            } else {
                                result.error("UNAVAILABLE", "Speech output unavailable", null)
                            }
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

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != voiceRequest || voiceResult == null) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) beginListening()
        else finishListening(error = "Microphone permission is required for voice input")
    }

    private fun beginListening() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            finishListening(error = "Voice recognition unavailable")
            return
        }
        try {
            val engine = SpeechRecognizer.createSpeechRecognizer(this)
            recognizer = engine
            engine.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {
                    if (recognizer === engine) {
                        listeningDialog?.setTitle("Processing speech")
                        listeningDialog?.setMessage("Preparing your editable text.")
                        listeningDialog?.getButton(AlertDialog.BUTTON_POSITIVE)?.isEnabled = false
                    }
                }
                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
                override fun onError(error: Int) {
                    if (recognizer !== engine) return
                    if (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) finishListening("")
                    else finishListening(error = "Speech recognition unavailable")
                }
                override fun onResults(results: Bundle?) {
                    if (recognizer === engine) finishListening(results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty())
                }
            })
            listeningDialog = AlertDialog.Builder(this)
                .setTitle("Listening").setMessage(voicePrompt)
                .setPositiveButton("Finish speaking", null)
                .setNegativeButton("Cancel") { _, _ -> finishListening() }
                .setOnCancelListener { finishListening() }.show()
            listeningDialog?.getButton(AlertDialog.BUTTON_POSITIVE)?.setOnClickListener {
                engine.stopListening()
                listeningDialog?.setTitle("Processing speech")
                it.isEnabled = false
            }
            engine.startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM))
        } catch (e: RuntimeException) {
            finishListening(error = "Voice input unavailable")
        }
    }

    private fun finishListening(words: String? = null, error: String? = null) {
        val pending = voiceResult
        voiceResult = null
        val engine = recognizer
        recognizer = null
        engine?.destroy()
        listeningDialog?.dismiss()
        listeningDialog = null
        if (error == null) pending?.success(words) else pending?.error("VOICE_INPUT", error, null)
    }

    override fun onStop() {
        if (recognizer != null) finishListening()
        textToSpeech?.stop()
        super.onStop()
    }

    override fun onDestroy() {
        unsubscribe()
        welcomePlayer?.release()
        welcomePlayer = null
        finishListening()
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        super.onDestroy()
    }
}
