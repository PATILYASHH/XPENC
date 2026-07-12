package com.yash.xpenc

import android.Manifest
import android.content.pm.PackageManager
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Host activity for the XPENC Flutter app.
 *
 * SMS capture design note
 * -----------------------
 * We deliberately do NOT register a BroadcastReceiver and we do NOT request the
 * RECEIVE_SMS permission. Instead the app scans the SMS inbox on demand (on
 * resume) via the [querySince] method channel call, reading only messages newer
 * than the last scan timestamp.
 *
 * Why the poll-on-resume model instead of a live receiver:
 *  - Simpler: no receiver lifecycle, no background-broadcast restrictions to fight.
 *  - One fewer permission: READ_SMS alone is enough; RECEIVE_SMS (a sensitive
 *    "real-time" permission Google scrutinises heavily on Play) is never needed.
 *  - Matches the product requirement: review cards should appear "when the user
 *    opens the app", which is exactly when an on-resume inbox scan runs.
 *
 * READ_SMS is used ONLY to detect bank transaction SMS on-device. Nothing is
 * ever uploaded off the device.
 */
class MainActivity : FlutterActivity() {

    /** Pending permission result, held while the OS permission dialog is shown. */
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(true)
                    "hasPermission" -> result.success(hasReadSmsPermission())
                    "requestPermission" -> requestReadSmsPermission(result)
                    "querySince" -> {
                        // Flutter may deliver integers as Int or Long depending on
                        // magnitude, so read as Number and normalise to Long.
                        val since = (call.argument<Number>("since"))?.toLong() ?: 0L
                        querySince(since, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasReadSmsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestReadSmsPermission(result: MethodChannel.Result) {
        if (hasReadSmsPermission()) {
            result.success(true)
            return
        }
        // If a request is already in flight, reject this one rather than dropping
        // the earlier result on the floor.
        if (pendingPermissionResult != null) {
            result.error("PERMISSION_IN_PROGRESS", "A permission request is already in progress.", null)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_SMS), REQ_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQ_CODE) return

        val result = pendingPermissionResult ?: return
        // Null out first so the result can never be completed twice (a double
        // completion crashes the Flutter engine).
        pendingPermissionResult = null

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        result.success(granted)
    }

    private fun querySince(since: Long, result: MethodChannel.Result) {
        // No permission -> return an empty list rather than throwing.
        if (!hasReadSmsPermission()) {
            result.success(emptyList<HashMap<String, Any>>())
            return
        }
        try {
            val messages = ArrayList<HashMap<String, Any>>()
            val projection = arrayOf(
                Telephony.Sms.BODY,
                Telephony.Sms.ADDRESS,
                Telephony.Sms.DATE,
            )
            val cursor = contentResolver.query(
                Telephony.Sms.Inbox.CONTENT_URI,
                projection,
                "${Telephony.Sms.DATE} > ?",
                arrayOf(since.toString()),
                "${Telephony.Sms.DATE} ASC",
            )
            if (cursor == null) {
                result.success(messages)
                return
            }
            cursor.use { c ->
                val bodyIdx = c.getColumnIndexOrThrow(Telephony.Sms.BODY)
                val addressIdx = c.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                val dateIdx = c.getColumnIndexOrThrow(Telephony.Sms.DATE)
                while (c.moveToNext()) {
                    val map = HashMap<String, Any>()
                    map["body"] = c.getString(bodyIdx) ?: ""
                    map["sender"] = c.getString(addressIdx) ?: ""
                    map["timestamp"] = c.getLong(dateIdx)
                    messages.add(map)
                }
            }
            // Cap the payload, but return the OLDEST batch, not the newest.
            //
            // The Dart side advances its watermark to the newest message it
            // actually processed, so a truncated batch is simply resumed on the
            // next scan. Returning the newest 500 instead would silently drop
            // every older message once the watermark moved past them.
            val capped = if (messages.size > MAX_RESULTS) {
                messages.subList(0, MAX_RESULTS).toList()
            } else {
                messages
            }
            result.success(capped)
        } catch (e: Exception) {
            result.error("SMS_QUERY_FAILED", e.message, null)
        }
    }

    private companion object {
        // Not renamed with the app. This string only has to match the Dart side
        // (`SmsSource._channel`) byte for byte; no user ever sees it, and no test
        // covers the pairing because the Dart tests use a FakeMessageSource. A
        // cosmetic rename here buys nothing and silently kills SMS capture if the
        // two sides ever drift apart.
        const val CHANNEL = "money_manager/sms"
        const val REQ_CODE = 4201
        const val MAX_RESULTS = 500
    }
}
