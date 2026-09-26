package com.yash.xpenc

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

private const val PERMISSIONS_CHANNEL = "xpenc/permissions"

// Plain strings rather than `Manifest.permission.*` — test/native_channel_test
// keeps that token out of MainActivity, and these are the only three runtime
// permissions Settings > Permissions surfaces.
private const val NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS"
private val KNOWN = setOf(
    NOTIFICATIONS,
    "android.permission.CAMERA",
    "android.permission.READ_CONTACTS",
)

/**
 * Backs Settings > Permissions (`lib/core/permissions/app_permissions.dart`).
 *
 * Android gives an app no API to revoke its own runtime grant, so this only
 * reports status, asks for a grant, and opens the system App info page —
 * turning something *off* always happens there, by the user.
 *
 * Notifications are reported through [NotificationManagerCompat] rather than
 * `checkSelfPermission`: below Android 13 there is no runtime permission, but
 * the user can still block the app's notifications, and that's what matters.
 *
 * Must be constructed while [activity] is initialising (a field initialiser
 * is fine): `registerForActivityResult` throws once the activity is STARTED.
 */
class PermissionsChannel(private val activity: FragmentActivity) {
    private var pending: MethodChannel.Result? = null
    private var pendingName: String? = null

    private val launcher = activity.registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { _ ->
        val result = pending
        val name = pendingName
        pending = null
        pendingName = null
        if (result != null && name != null) result.success(status(name))
    }

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, PERMISSIONS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> {
                    val names = call.arguments as? List<*> ?: emptyList<Any>()
                    result.success(
                        names.filterIsInstance<String>().associateWith { status(it) },
                    )
                }
                "request" -> request(call.arguments as? String, result)
                "openSettings" -> {
                    openSettings(call.arguments as? String)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** `granted`, `denied`, or `blocked` (denied and Android won't ask again). */
    private fun status(name: String): String {
        val granted = if (name == NOTIFICATIONS) {
            NotificationManagerCompat.from(activity).areNotificationsEnabled()
        } else {
            ContextCompat.checkSelfPermission(activity, name) ==
                PackageManager.PERMISSION_GRANTED
        }
        if (granted) return "granted"
        // Below 13 notifications have no dialog to show — only system settings.
        if (name == NOTIFICATIONS && Build.VERSION.SDK_INT < 33) return "blocked"
        return if (activity.shouldShowRequestPermissionRationale(name)) {
            "denied"
        } else {
            // Also true before the first-ever ask; Dart treats "blocked" as
            // "try the dialog once, then fall back to settings".
            "blocked"
        }
    }

    private fun request(name: String?, result: MethodChannel.Result) {
        if (name == null || name !in KNOWN) {
            result.error("unknown_permission", "Not a permission XPENC uses: $name", null)
            return
        }
        if (name == NOTIFICATIONS && Build.VERSION.SDK_INT < 33) {
            result.success(status(name))
            return
        }
        if (pending != null) {
            result.error("busy", "A permission request is already showing", null)
            return
        }
        pending = result
        pendingName = name
        launcher.launch(name)
    }

    private fun openSettings(name: String?) {
        val intent = if (name == NOTIFICATIONS && Build.VERSION.SDK_INT >= 26) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
        } else {
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", activity.packageName, null),
            )
        }
        activity.startActivity(intent)
    }
}
