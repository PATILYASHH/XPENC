package com.yash.xpenc

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

private const val VOICE_CHANNEL = "xpenc/voice"
private const val RECORD_AUDIO = "android.permission.RECORD_AUDIO"

/** What whisper.cpp reads: 16 kHz, mono, 16-bit. */
private const val SAMPLE_RATE = 16000

/** A question, not a dictation: anything longer is cut here. */
private const val MAX_SECONDS = 30

/**
 * Voice input for Local AI (`lib/core/ai/voice_input.dart`). Records the
 * microphone into memory while the user holds the 🎤 button and hands the raw
 * samples back to Dart, where the on-device speech model turns them into
 * text. Nothing is written to disk and nothing leaves the phone.
 */
class VoiceChannel(private val context: Context) {
    private var recorder: AudioRecord? = null
    private var reader: Thread? = null
    private var audio = ByteArrayOutputStream()

    @Volatile
    private var recording = false

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, VOICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> result.success(start())
                "stop" -> result.success(stop())
                "cancel" -> {
                    stop()
                    audio = ByteArrayOutputStream()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** `ok`, `permission` (not granted — Dart asks first), or `busy`/`failed`. */
    @SuppressLint("MissingPermission") // checked just below
    private fun start(): String {
        if (ContextCompat.checkSelfPermission(context, RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return "permission"
        }
        if (recording) return "busy"
        val min = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (min <= 0) return "failed"
        val record = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                min * 4,
            )
        } catch (e: Exception) {
            return "failed"
        }
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            return "failed"
        }
        audio = ByteArrayOutputStream()
        recorder = record
        recording = true
        record.startRecording()
        val limit = SAMPLE_RATE * 2 * MAX_SECONDS
        reader = Thread {
            val chunk = ByteArray(min)
            while (recording && audio.size() < limit) {
                val n = record.read(chunk, 0, chunk.size)
                if (n > 0) audio.write(chunk, 0, n)
            }
        }.also { it.start() }
        return "ok"
    }

    /** Stops and returns what was recorded: little-endian 16-bit samples. */
    private fun stop(): ByteArray {
        recording = false
        reader?.join(1000)
        reader = null
        recorder?.let {
            try {
                it.stop()
            } catch (_: IllegalStateException) {
            }
            it.release()
        }
        recorder = null
        return audio.toByteArray()
    }
}
