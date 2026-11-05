package com.yash.xpenc

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

private const val CHANNEL = "xpenc/share_targets"

// WhatsApp, then WhatsApp Business.
private val WHATSAPP_PACKAGES = listOf("com.whatsapp", "com.whatsapp.w4b")

private const val MIME_IMAGE = "image/png"
private const val MIME_PDF = "application/pdf"

private const val PREFS = "xpenc_share_targets"
private const val KEY_PINNED = "pinned"

/**
 * Serves the files Share writes to `<cache>/shared/` (see
 * `res/xml/share_file_paths.xml`). A subclass, not androidx's FileProvider
 * itself, so it can never clash with a plugin's own provider entry when the
 * manifests merge.
 */
class ShareFileProvider : FileProvider()

/**
 * `xpenc/share_targets`: hands a share — a statement image or PDF — straight
 * to an app on the share screen's row, rather than through the system share
 * sheet ("More" still goes there, through share_plus).
 *
 * A target is one share activity, `package/activity`, as the system share
 * sheet lists them (WhatsApp's chat picker, Gmail, Drive's "Save to Drive").
 *
 * - `targets`: every activity that takes a PNG or a PDF — `id`, `label`,
 *   `appLabel`, `kind` (`whatsapp` / `messages` / `app`), `image`, `pdf` —
 *   and the ids `pinned` to the row: the user's own pick once they've made
 *   one (`customized`), else WhatsApp and the default messages app.
 * - `pin`: `ids` to keep on the row, in order; null goes back to the
 *   default.
 * - `icon`: an `id`'s icon as a `png` (`size` px square). `adaptive`: drawn
 *   full-bleed, for the caller to mask round.
 * - `send`: the target `id`, the file's `path` and `mimeType`, the message
 *   `text`, and optionally the recipient: `jid` (international digits, no
 *   `+`) opens their WhatsApp chat; `phone` addresses the text. Answers
 *   `sent`, `text` (the messages app wouldn't take the file, so only the
 *   text went) or `failed`.
 *
 * No permission needed: these are ordinary share intents, and the manifest's
 * `<queries>` names the SEND intent, not every package. This reads and sends
 * nothing itself. Dart side: `lib/core/platform/outgoing_file_io.dart`.
 */
class ShareTargetsChannel(private val activity: Activity) {
    private val pm: PackageManager get() = activity.packageManager
    private val prefs get() = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // Labels and icons come off the package manager, which can take a
    // while with many apps installed: off the UI thread, one at a time.
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        worker.execute {
            val value = try {
                work()
            } catch (e: Exception) {
                main.post { result.error("share_targets", e.message, null) }
                return@execute
            }
            main.post { result.success(value) }
        }
    }

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "targets" -> background(result) { targets() }
                "pin" -> {
                    val ids = call.argument<List<String>>("ids")
                    val editor = prefs.edit()
                    if (ids == null) {
                        editor.remove(KEY_PINNED)
                    } else {
                        editor.putString(KEY_PINNED, ids.joinToString("\n"))
                    }
                    editor.apply()
                    result.success(null)
                }
                "icon" -> {
                    val id = call.argument<String>("id")
                    val size = call.argument<Int>("size") ?: 192
                    background(result) { id?.let { icon(it, size.coerceIn(48, 512)) } }
                }
                "send" -> result.success(
                    send(
                        id = call.argument<String>("id"),
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

    private class Target(
        val pkg: String,
        val cls: String,
        val label: String,
        val appLabel: String,
        var image: Boolean = false,
        var pdf: Boolean = false,
    ) {
        val id get() = "$pkg/$cls"
    }

    @Suppress("DEPRECATION")
    private fun shareActivities(mime: String, pkg: String? = null) =
        pm.queryIntentActivities(
            Intent(Intent.ACTION_SEND).setType(mime).apply { pkg?.let(::setPackage) },
            PackageManager.MATCH_DEFAULT_ONLY,
        )

    private fun collect(): List<Target> {
        val found = LinkedHashMap<String, Target>()
        val appLabels = HashMap<String, String>()
        for (mime in listOf(MIME_IMAGE, MIME_PDF)) {
            for (info in shareActivities(mime)) {
                val a = info.activityInfo ?: continue
                // XPENC takes images itself (screenshot intake).
                if (a.packageName == activity.packageName) continue
                val target = found.getOrPut("${a.packageName}/${a.name}") {
                    val appLabel = appLabels.getOrPut(a.packageName) {
                        a.applicationInfo.loadLabel(pm).toString()
                    }
                    Target(
                        pkg = a.packageName,
                        cls = a.name,
                        label = info.loadLabel(pm).toString().ifBlank { appLabel },
                        appLabel = appLabel,
                    )
                }
                if (mime == MIME_IMAGE) target.image = true else target.pdf = true
            }
        }
        return found.values.sortedBy { it.label.lowercase() }
    }

    /** An app's own share entry — the one carrying its name — else its first. */
    private fun mainTarget(all: List<Target>, pkg: String?): Target? {
        if (pkg == null) return null
        val own = all.filter { it.pkg == pkg }
        return own.firstOrNull { it.label == it.appLabel } ?: own.firstOrNull()
    }

    private fun kindOf(pkg: String, messages: String?) = when {
        pkg in WHATSAPP_PACKAGES -> "whatsapp"
        pkg == messages -> "messages"
        else -> "app"
    }

    private fun targets(): Map<String, Any> {
        val all = collect()
        val messages = messagesApp()
        val saved = prefs.getString(KEY_PINNED, null)
        val pinned = saved?.split("\n")?.filter { it.isNotEmpty() }
            ?: listOfNotNull(mainTarget(all, whatsApp()), mainTarget(all, messages)).map { it.id }
        return mapOf(
            "targets" to all.map {
                mapOf(
                    "id" to it.id,
                    "label" to it.label,
                    "appLabel" to it.appLabel,
                    "kind" to kindOf(it.pkg, messages),
                    "image" to it.image,
                    "pdf" to it.pdf,
                )
            },
            "pinned" to pinned,
            "customized" to (saved != null),
        )
    }

    private fun icon(id: String, size: Int): Map<String, Any>? {
        val (pkg, cls) = split(id) ?: return null
        val drawable: Drawable = try {
            pm.getActivityInfo(ComponentName(pkg, cls), 0).loadIcon(pm)
        } catch (e: PackageManager.NameNotFoundException) {
            null
        } ?: return null
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val adaptive = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            drawable is AdaptiveIconDrawable
        if (adaptive) {
            // Both layers are 108dp, and a launcher shows their middle 72dp:
            // drawn half as big again, that middle fills the square.
            val d = drawable as AdaptiveIconDrawable
            val bleed = size / 4
            for (layer in listOfNotNull(d.background, d.foreground)) {
                layer.setBounds(-bleed, -bleed, size + bleed, size + bleed)
                layer.draw(canvas)
            }
        } else {
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
        }
        val png = ByteArrayOutputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
            it.toByteArray()
        }
        bitmap.recycle()
        return mapOf("png" to png, "adaptive" to adaptive)
    }

    private fun split(id: String): Pair<String, String>? {
        val slash = id.indexOf('/')
        if (slash <= 0 || slash == id.length - 1) return null
        return id.substring(0, slash) to id.substring(slash + 1)
    }

    private fun installed(pkg: String): Boolean = try {
        pm.getPackageInfo(pkg, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    private fun whatsApp(): String? = WHATSAPP_PACKAGES.firstOrNull(::installed)

    /** The app that answers an `smsto:` link — the default messages app. */
    private fun messagesApp(): String? {
        val pkg = pm.resolveActivity(
            Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:")),
            PackageManager.MATCH_DEFAULT_ONLY,
        )?.activityInfo?.packageName
        // "android" is the system's app chooser: no default to go straight to.
        return if (pkg == null || pkg == "android") null else pkg
    }

    private fun send(
        id: String?,
        path: String?,
        mimeType: String?,
        text: String?,
        jid: String?,
        phone: String?,
    ): String {
        if (path == null || mimeType == null) return "failed"
        val (pkg, cls) = id?.let(::split) ?: return "failed"
        val kind = kindOf(pkg, messagesApp())
        // An explicit intent skips the type check, so make it here: a
        // messages app that takes images may still refuse a PDF — send the
        // text, to the right number, rather than nothing.
        val takes = shareActivities(mimeType, pkg).any { it.activityInfo?.name == cls }
        if (!takes) return if (kind == "messages") textOnly(pkg, text, phone) else "failed"
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
            setClassName(pkg, cls)
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newRawUri(null, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (!text.isNullOrEmpty()) {
                putExtra(Intent.EXTRA_TEXT, text)
                if (kind == "messages") putExtra("sms_body", text)
            }
            // Not a documented extra, but what WhatsApp opens a chat by.
            if (kind == "whatsapp" && !jid.isNullOrEmpty()) {
                putExtra("jid", "$jid@s.whatsapp.net")
            }
            if (kind == "messages" && !phone.isNullOrEmpty()) {
                putExtra("address", phone)
            }
        }
        return try {
            activity.startActivity(intent)
            "sent"
        } catch (e: ActivityNotFoundException) {
            if (kind == "messages") textOnly(pkg, text, phone) else "failed"
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
