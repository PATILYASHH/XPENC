import 'package:flutter/services.dart';

/// A runtime permission XPENC asks for, and why — what Settings > Permissions
/// lists. Each one is optional: the feature that needs it degrades, nothing
/// else breaks.
enum AppPermission {
  notifications(
    androidName: 'android.permission.POST_NOTIFICATIONS',
    title: 'Notifications',
    reason: 'Bill and due-date reminders, quick add from the notification shade',
  ),
  camera(
    androidName: 'android.permission.CAMERA',
    title: 'Camera',
    reason: 'Take a photo of a receipt from Add transaction',
  ),
  contacts(
    androidName: 'android.permission.READ_CONTACTS',
    title: 'Contacts',
    reason:
        'Import a phone number and photo when you pick a person from '
        'contacts. Without it, picking still works — name only',
  );

  const AppPermission({
    required this.androidName,
    required this.title,
    required this.reason,
  });

  final String androidName;
  final String title;
  final String reason;
}

enum PermissionState {
  granted,

  /// Not granted, but Android will still show its dialog.
  denied,

  /// Not granted and Android won't ask (or never can, e.g. notifications
  /// below Android 13) — only system settings can change it.
  blocked,

  /// No Android host (tests, desktop dev runs).
  unavailable,
}

/// Talks to `PermissionsChannel.kt`. Android lets an app *ask* for a grant
/// but never revoke its own, so turning one off always goes through
/// [openSettings].
class AppPermissions {
  const AppPermissions._();

  static const _channel = MethodChannel('xpenc/permissions');

  static Future<Map<AppPermission, PermissionState>> statuses() async {
    try {
      final raw = await _channel.invokeMapMethod<String, String>(
        'status',
        [for (final p in AppPermission.values) p.androidName],
      );
      return {
        for (final p in AppPermission.values) p: _parse(raw?[p.androidName]),
      };
    } on MissingPluginException {
      return _allUnavailable();
    } on PlatformException {
      return _allUnavailable();
    }
  }

  /// Shows Android's dialog; returns the state afterwards. When Android
  /// refuses to show it ([PermissionState.blocked]), the caller should send
  /// the user to [openSettings] instead.
  static Future<PermissionState> request(AppPermission p) async {
    try {
      return _parse(
        await _channel.invokeMethod<String>('request', p.androidName),
      );
    } on MissingPluginException {
      return PermissionState.unavailable;
    } on PlatformException {
      return PermissionState.unavailable;
    }
  }

  /// The app's page in system settings (its notification page for
  /// [AppPermission.notifications]).
  static Future<void> openSettings([AppPermission? p]) async {
    try {
      await _channel.invokeMethod<void>('openSettings', p?.androidName);
    } on MissingPluginException {
      // Nothing to open outside Android.
    } on PlatformException {
      // Best-effort.
    }
  }

  static PermissionState _parse(String? s) => switch (s) {
    'granted' => PermissionState.granted,
    'denied' => PermissionState.denied,
    'blocked' => PermissionState.blocked,
    _ => PermissionState.unavailable,
  };

  static Map<AppPermission, PermissionState> _allUnavailable() => {
    for (final p in AppPermission.values) p: PermissionState.unavailable,
  };
}
