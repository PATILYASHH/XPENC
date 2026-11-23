package com.yash.xpenc

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

private const val SPEECH_CHANNEL = "xpenc/speech"
private const val SPEECH_EVENTS = "xpenc/speech/events"
private const val RECORD_AUDIO_PERMISSION = "android.permission.RECORD_AUDIO"

/**
 * Voice add (`lib/core/voice/speech_input.dart`): live speech-to-text with
 * Android's own recognizer — the **on-device** one only
 * ([SpeechRecognizer.createOnDeviceSpeechRecognizer], Android 12+), so the
 * audio never leaves the phone. Where the phone has no on-device recognizer,
 * or not for this language yet, Dart is told so instead of falling back to
 * an online one.
 *
 * Events to Dart, as maps: `{type: partial|final, text}`,
 * `{type: level, value}` (0–1, the mic's loudness) and
 * `{type: error, code: language|no-match|permission|busy|other}`.
 */
class SpeechChannel(private val context: Context) {
    private var recognizer: SpeechRecognizer? = null
    private var sink: EventChannel.EventSink? = null
    private var lastLevelAt = 0L

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, SPEECH_CHANNEL).setMethodCallHandler { call, result ->
            val locale = call.argument<String>("locale") ?: "en-IN"
            when (call.method) {
                "available" -> result.success(available())
                "start" -> result.success(start(locale))
                "stop" -> {
                    recognizer?.stopListening()
                    result.success(null)
                }
                "cancel" -> {
                    release()
                    result.success(null)
                }
                "download" -> result.success(download(locale))
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, SPEECH_EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sink = events
                }

                override fun onCancel(arguments: Any?) {
                    sink = null
                }
            },
        )
    }

    /** `ok`, or `unsupported` — no on-device recognizer on this phone. */
    private fun available(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return "unsupported"
        return if (SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) "ok"
        else "unsupported"
    }

    /** `ok`, `permission` (Dart asks first), or `unsupported`. */
    private fun start(locale: String): String {
        if (ContextCompat.checkSelfPermission(context, RECORD_AUDIO_PERMISSION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return "permission"
        }
        // Inline, not via available(), so lint sees the API 31 guard.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            !SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        ) {
            return "unsupported"
        }
        release()
        val rec = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        rec.setRecognitionListener(listener)
        recognizer = rec
        rec.startListening(intentFor(locale))
        return "ok"
    }

    /**
     * Asks the system to download [locale]'s offline speech model (Android
     * 13+). False where that can't be asked for — Dart then points the user
     * at the phone's speech settings.
     */
    private fun download(locale: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) return false
        return try {
            val rec = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            rec.triggerModelDownload(intentFor(locale))
            rec.destroy()
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun intentFor(locale: String) =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }

    private fun release() {
        recognizer?.destroy()
        recognizer = null
    }

    private fun emit(event: Map<String, Any?>) {
        sink?.success(event)
    }

    private fun firstText(bundle: Bundle?): String? =
        bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()

    private val listener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {}
        override fun onBeginningOfSpeech() {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}
        override fun onEvent(eventType: Int, params: Bundle?) {}

        override fun onRmsChanged(rmsdB: Float) {
            val now = System.currentTimeMillis()
            if (now - lastLevelAt < 80) return
            lastLevelAt = now
            // Roughly -2 dB (silence) to 10 dB (speaking up), onto 0–1.
            emit(mapOf("type" to "level", "value" to ((rmsdB + 2f) / 12f).coerceIn(0f, 1f).toDouble()))
        }

        override fun onPartialResults(partialResults: Bundle?) {
            val text = firstText(partialResults) ?: return
            if (text.isNotBlank()) emit(mapOf("type" to "partial", "text" to text))
        }

        override fun onResults(results: Bundle?) {
            emit(mapOf("type" to "final", "text" to (firstText(results) ?: "")))
            release()
        }

        override fun onError(error: Int) {
            val code = when (error) {
                SpeechRecognizer.ERROR_NO_MATCH,
                SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "no-match"
                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "permission"
                SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "busy"
                12, 13 -> "language" // ERROR_LANGUAGE_NOT_SUPPORTED / _UNAVAILABLE (API 31)
                else -> "other"
            }
            emit(mapOf("type" to "error", "code" to code))
            release()
        }
    }
}
