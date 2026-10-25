package com.yash.xpenc

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "xpenc/connector"
private const val CONNECTOR_PACKAGE = "com.yash.xpenc.conectr"

// The Connector app's XpencProvider. (The authority's name predates the
// backup hand-off.)
private const val AUTHORITY = "com.yash.xpenc.conectr.friends"

/**
 * `xpenc/connector`: what the Connector app shares with XPENC on the phone,
 * through its `XpencProvider` — which answers XPENC alone, checked by
 * package name and signing certificate on its side:
 *
 * - `load`: the friends list, so a person can be linked to a friend.
 * - `inbox` / `readPending` / `confirmImport`: a backup Connector pulled from
 *   another device, taken in without Import from file, and Connector told.
 * - `open`: opens Connector.
 *
 * App to app on the device — XPENC still has no INTERNET permission. Dart
 * side: `lib/core/connector/friends/connector_friends_source.dart` and
 * `lib/core/connector/inbox/connector_inbox.dart`.
 */
class ConnectorChannel(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "load" -> result.success(loadFriends())
                "open" -> result.success(open())
                "inbox" -> result.success(inbox())
                "readPending" -> readPending(result)
                "confirmImport" -> result.success(
                    confirmImport(
                        call.argument<String>("sha"),
                        call.argument<Number>("at")?.toLong() ?: 0L,
                    ),
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun installed(): Boolean = try {
        context.packageManager.getPackageInfo(CONNECTOR_PACKAGE, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    /** Connector's provider, when it's Connector's — never an impostor's. */
    private fun providerIsConnector(): Boolean {
        @Suppress("DEPRECATION")
        val provider = context.packageManager.resolveContentProvider(AUTHORITY, 0)
        return provider != null && provider.packageName == CONNECTOR_PACKAGE
    }

    private fun call(method: String, arg: String? = null, extras: Bundle? = null): Bundle? =
        context.contentResolver.call(Uri.parse("content://$AUTHORITY"), method, arg, extras)

    private fun loadFriends(): Map<String, Any?> {
        if (!installed()) return mapOf("installed" to false)
        // A Connector from before friends were shared — or something else
        // answering to the name, which isn't asked.
        if (!providerIsConnector()) return mapOf("installed" to true, "outdated" to true)
        val reply = try {
            call("friends")
        } catch (e: SecurityException) {
            return mapOf("installed" to true, "refused" to true)
        } catch (e: IllegalArgumentException) {
            return mapOf("installed" to true, "outdated" to true)
        }
        return mapOf("installed" to true, "json" to reply?.getString("json"))
    }

    /** Connector's inbox JSON; null when there's no Connector that shares one. */
    private fun inbox(): String? {
        if (!installed() || !providerIsConnector()) return null
        return try {
            call("pendingBackup")?.getString("json")
        } catch (e: RuntimeException) {
            null
        }
    }

    /** The waiting backup's bytes — read off the main thread. */
    private fun readPending(result: MethodChannel.Result) {
        if (!installed() || !providerIsConnector()) {
            result.error("unavailable", "Connector isn't installed.", null)
            return
        }
        Thread {
            try {
                val bytes = context.contentResolver
                    .openInputStream(Uri.parse("content://$AUTHORITY/pending-backup"))
                    ?.use { it.readBytes() }
                main.post {
                    if (bytes == null) {
                        result.error("missing", "No backup is waiting.", null)
                    } else {
                        result.success(bytes)
                    }
                }
            } catch (e: Exception) {
                main.post { result.error("unreadable", e.message, null) }
            }
        }.start()
    }

    private fun confirmImport(sha: String?, at: Long): Boolean {
        if (sha == null || at <= 0L || !installed() || !providerIsConnector()) return false
        return try {
            call("confirmImport", sha, Bundle().apply { putLong("at", at) })
                ?.getBoolean("ok") ?: false
        } catch (e: RuntimeException) {
            false
        }
    }

    /** Opens Connector — to sign in, add friends, or refresh what it shares. */
    private fun open(): Boolean {
        val launch = context.packageManager.getLaunchIntentForPackage(CONNECTOR_PACKAGE)
            ?: return false
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(launch)
        return true
    }
}
