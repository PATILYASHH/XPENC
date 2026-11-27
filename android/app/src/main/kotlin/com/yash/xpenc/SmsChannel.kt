package com.yash.xpenc

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

private const val SMS_CHANNEL = "xpenc/sms"
private const val READ_SMS_PERMISSION = "android.permission.READ_SMS"

/** The most inbox rows one [SmsChannel.senders] pass looks at. */
private const val SENDER_SCAN_CAP = 5000

/** A sender ID or code the user tracks: `HDFCBK`, `FEDBNK`, `56161`. */
private val SENDER_CODE = Regex("^[A-Z0-9]{3,12}$")

/**
 * A person's number, never a bank: `+919876543210`, `98765 43210`. Their
 * messages are never read, whatever the user tracks.
 */
private val PHONE_NUMBER = Regex("^\\+?[0-9][0-9 -]{6,}$")

/** Whether this build's manifest asks for [permission] at all. */
internal fun declares(context: Context, permission: String): Boolean {
    val info = try {
        if (Build.VERSION.SDK_INT >= 33) {
            context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.GET_PERMISSIONS,
            )
        }
    } catch (e: PackageManager.NameNotFoundException) {
        return false
    }
    return info.requestedPermissions?.contains(permission) == true
}

/**
 * Auto money tracking (Settings → Advanced Features) — reads bank SMS for
 * `lib/features/message_capture/sms_inbox.dart`.
 *
 * Read-only: it queries the inbox and does nothing else — never writes,
 * deletes, sends or listens for new messages (no RECEIVE_SMS). Only messages
 * from the sender codes Dart passes come back with their text, and never one
 * from a phone number. [senders] lists who has written so the user can pick
 * their bank. Nothing leaves the phone: XPENC has no internet permission.
 *
 * Works only in builds whose manifest declares READ_SMS
 * (android/app/build.gradle.kts adds it for `XPENC_SMS=on`, and to debug
 * builds); everywhere else each read answers "absent".
 */
class SmsChannel(private val context: Context) {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "declared" -> result.success(declares(context, READ_SMS_PERMISSION))
                "messages" -> read(result) {
                    messages(
                        since = (call.argument<Number>("since") ?: 0).toLong(),
                        senders = call.argument<List<String>>("senders").orEmpty(),
                        limit = call.argument<Int>("limit") ?: 500,
                        newestFirst = call.argument<Boolean>("newestFirst") ?: false,
                    )
                }
                "senders" -> read(result) {
                    senders(
                        since = (call.argument<Number>("since") ?: 0).toLong(),
                        samples = call.argument<Int>("samples") ?: 3,
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Runs [query] off the main thread, once SMS is declared and allowed. */
    private fun read(result: MethodChannel.Result, query: () -> Any) {
        if (!declares(context, READ_SMS_PERMISSION)) {
            result.error("absent", "This build doesn't read SMS", null)
            return
        }
        if (ContextCompat.checkSelfPermission(context, READ_SMS_PERMISSION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("permission", "SMS isn't allowed", null)
            return
        }
        worker.execute {
            try {
                val value = query()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("read_failed", e.message, null) }
            }
        }
    }

    /**
     * Inbox messages after [since] (epoch ms) whose sender contains one of
     * [senders] — oldest first (a capture scan resumes from its watermark),
     * or newest first (the list on screen). At most [limit].
     */
    private fun messages(
        since: Long,
        senders: List<String>,
        limit: Int,
        newestFirst: Boolean,
    ): List<Map<String, Any>> {
        val codes = senders.map { it.uppercase() }.filter { SENDER_CODE.matches(it) }
        if (codes.isEmpty()) return emptyList()
        val where = StringBuilder("${Telephony.Sms.DATE} > ? AND (")
        val args = mutableListOf(since.toString())
        codes.forEachIndexed { i, code ->
            if (i > 0) where.append(" OR ")
            // SQLite's LIKE ignores ASCII case; codes are [A-Z0-9] only, so
            // there is nothing to escape.
            where.append("${Telephony.Sms.ADDRESS} LIKE ?")
            args.add("%$code%")
        }
        where.append(")")

        val out = ArrayList<Map<String, Any>>()
        val cursor = context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE),
            where.toString(),
            args.toTypedArray(),
            "${Telephony.Sms.DATE} ${if (newestFirst) "DESC" else "ASC"}",
        ) ?: return out
        cursor.use { c ->
            val addressAt = c.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val bodyAt = c.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val dateAt = c.getColumnIndexOrThrow(Telephony.Sms.DATE)
            while (out.size < limit && c.moveToNext()) {
                val address = c.getString(addressAt)
                val body = c.getString(bodyAt)
                if (address != null && body != null && !PHONE_NUMBER.matches(address.trim())) {
                    out.add(mapOf("sender" to address, "body" to body, "date" to c.getLong(dateAt)))
                }
            }
        }
        return out
    }

    /**
     * Who has written since [since]: each sender that isn't a phone number,
     * with how many messages and its newest [samples] texts — Dart checks
     * those for payments to suggest the user's bank, then drops them.
     * Busiest first.
     */
    private fun senders(since: Long, samples: Int): List<Map<String, Any>> {
        class Seen(var count: Int, var last: Long, val texts: MutableList<String>)

        val seen = LinkedHashMap<String, Seen>()
        val cursor = context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE),
            "${Telephony.Sms.DATE} > ?",
            arrayOf(since.toString()),
            "${Telephony.Sms.DATE} DESC",
        ) ?: return emptyList()
        cursor.use { c ->
            val addressAt = c.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val bodyAt = c.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val dateAt = c.getColumnIndexOrThrow(Telephony.Sms.DATE)
            var rows = 0
            while (rows < SENDER_SCAN_CAP && c.moveToNext()) {
                rows++
                val address = c.getString(addressAt)?.trim()
                if (address.isNullOrEmpty() || PHONE_NUMBER.matches(address)) continue
                val entry = seen.getOrPut(address) { Seen(0, c.getLong(dateAt), mutableListOf()) }
                entry.count++
                val body = c.getString(bodyAt)
                if (body != null && entry.texts.size < samples) entry.texts.add(body)
            }
        }
        return seen.entries
            .sortedByDescending { it.value.count }
            .map { (address, s) ->
                mapOf("sender" to address, "count" to s.count, "last" to s.last, "samples" to s.texts)
            }
    }
}
