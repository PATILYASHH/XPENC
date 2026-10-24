package com.yash.xpenc

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "xpenc/connector_friends"
private const val CONNECTOR_PACKAGE = "com.yash.xpenc.conectr"
private const val FRIENDS_AUTHORITY = "com.yash.xpenc.conectr.friends"

/**
 * `xpenc/connector_friends`: reads the friends list the Connector app shares
 * (its `FriendsProvider`), so a person can be linked to a Connector friend.
 * App to app on the device — XPENC still has no INTERNET permission, and
 * sends Connector nothing but the request. Connector answers only XPENC,
 * checked by package name and signing certificate on its side.
 *
 * Dart side: `AndroidFriendsSource` in
 * `lib/core/connector/friends/connector_friends_source.dart`, which reads the
 * reply's shape.
 */
class ConnectorFriendsChannel(private val context: Context) {
    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "load" -> result.success(load())
                "open" -> result.success(open())
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

    private fun load(): Map<String, Any?> {
        if (!installed()) return mapOf("installed" to false)
        @Suppress("DEPRECATION")
        val provider = context.packageManager.resolveContentProvider(FRIENDS_AUTHORITY, 0)
        // A Connector from before friends were shared — or something else
        // answering to the name, which isn't asked.
        if (provider == null || provider.packageName != CONNECTOR_PACKAGE) {
            return mapOf("installed" to true, "outdated" to true)
        }
        val reply = try {
            context.contentResolver.call(
                Uri.parse("content://$FRIENDS_AUTHORITY"),
                "friends",
                null,
                null,
            )
        } catch (e: SecurityException) {
            return mapOf("installed" to true, "refused" to true)
        } catch (e: IllegalArgumentException) {
            return mapOf("installed" to true, "outdated" to true)
        }
        return mapOf("installed" to true, "json" to reply?.getString("json"))
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
