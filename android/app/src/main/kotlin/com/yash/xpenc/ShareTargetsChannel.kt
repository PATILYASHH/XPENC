package com.yash.xpenc

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

private const val CHANNEL = "xpenc/share_targets"

// WhatsApp, then WhatsApp Business.
private val WHATSAPP_PACKAGES = listOf("com.whatsapp", "com.whatsapp.w4b")

/**
 * Serves the files Share writes to `<cache>/shared/` (see
 * `res/xml/share_file_paths.xml`). A subclass, not androidx's FileProvider
 * itself, so it can never clash with a plugin's own provider entry when the
 * manifests merge.
 */
class ShareFileProvider : FileProvider()

/**
 * `xpenc/share_targets`: hands a share — a statement image or PDF — straight
 * to WhatsApp or the messages app, rather than through the system share
 * sheet ("More" still goes there, through share_plus).
 *
 * - `available`: which of the two are on the phone.
 * - `send`: `target` (`whatsapp` / `messages`), the file's `path` and
 *   `mimeType`, the message `text`, and optionally the recipient: `jid`
 *   (international digits, no `+`) opens their WhatsApp chat; `phone`
 *   addresses the text. Answers `sent`, `text` (the messages app wouldn't
 *   take the file, so only the text went) or `failed`.
 *
 * No permission needed: these are ordinary share intents — this reads and
 * sends nothing itself. Dart side: `lib/core/platform/outgoing_file_io.dart`.
 */
class ShareTargetsChannel(private val activity: Activity) {
    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(
                    mapOf(
                        "whatsapp" to (whatsApp() != null),
                        "messages" to (messagesApp() != null),
                    ),
                )
                "send" -> result.success(
                    send(
                        target = call.argument<String>("target"),
                        path = call.argument<String>("path"),
                        mimeType = call.argument<String>("mimeType"),
                        text = call.argument<String>("text"),
                        jid = call.argument<String>("jid"),
                        phone = call.argument<String>("phone"),
                    ),
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun installed(pkg: String): Boolean = try {
        activity.packageManager.getPackageInfo(pkg, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    private fun whatsApp(): String? = WHATSAPP_PACKAGES.firstOrNull(::installed)

    /** The app that answers an `smsto:` link — the default messages app. */
    private fun messagesApp(): String? {
        val pkg = activity.packageManager.resolveActivity(
            Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:")),
            PackageManager.MATCH_DEFAULT_ONLY,
        )?.activityInfo?.packageName
        // "android" is the system's app chooser: no default to go straight to.
        return if (pkg == null || pkg == "android") null else pkg
    }

    private fun send(
        target: String?,
        path: String?,
        mimeType: String?,
        text: String?,
        jid: String?,
        phone: String?,
    ): String {
        if (path == null || mimeType == null) return "failed"
        val pkg = when (target) {
            "whatsapp" -> whatsApp()
            "messages" -> messagesApp()
            else -> null
        } ?: return "failed"
        val uri = try {
            FileProvider.getUriForFile(
                activity,
                "${activity.packageName}.share_files",
                File(path),
            )
        } catch (e: IllegalArgumentException) {
            return "failed"
        }
        val intent = Intent(Intent.ACTION_SEND).apply {
            setPackage(pkg)
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newRawUri(null, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (!text.isNullOrEmpty()) {
                putExtra(Intent.EXTRA_TEXT, text)
                putExtra("sms_body", text)
            }
            // Not a documented extra, but what WhatsApp opens a chat by.
            if (target == "whatsapp" && !jid.isNullOrEmpty()) {
                putExtra("jid", "$jid@s.whatsapp.net")
            }
            if (target == "messages" && !phone.isNullOrEmpty()) {
                putExtra("address", phone)
            }
        }
        return try {
            activity.startActivity(intent)
            "sent"
        } catch (e: ActivityNotFoundException) {
            // A messages app that takes images may still refuse a PDF: send
            // the text, to the right number, rather than nothing.
            if (target == "messages") textOnly(pkg, text, phone) else "failed"
        } catch (e: SecurityException) {
            "failed"
        }
    }

    private fun textOnly(pkg: String, text: String?, phone: String?): String {
        val intent = Intent(
            Intent.ACTION_SENDTO,
            Uri.parse("smsto:${Uri.encode(phone ?: "")}"),
        ).apply {
            setPackage(pkg)
            if (!text.isNullOrEmpty()) putExtra("sms_body", text)
        }
        return try {
            activity.startActivity(intent)
            "text"
        } catch (e: ActivityNotFoundException) {
            "failed"
        }
    }
}
