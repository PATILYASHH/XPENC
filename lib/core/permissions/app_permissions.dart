import 'package:flutter/services.dart';
import '../../core/l10n/l10n.dart';

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
        'Pick a person from your contacts, with their phone number and '
        'photo. Without it, XPENC never opens your contacts',
  ),
  microphone(
    androidName: 'android.permission.RECORD_AUDIO',
    title: 'Microphone',
    reason:
        'Voice add: double-tap ➕ and say it. Your phone turns it into text '
        'on the phone; nothing is recorded or sent',
  ),
  sms(
    androidName: 'android.permission.READ_SMS',
    title: 'SMS',
    reason:
        'Auto money tracking: reads bank messages from the senders you '
        'pick, on this phone. Never your other messages',
  );

  const AppPermission({
    required this.androidName,
    required String title,
    required String reason,
  }) : _title = title, _reason = reason;

  final String androidName;
  final String _title;
  String get title => tr(_title);
  final String _reason;
  String get reason => tr(_reason);
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

  /// This build doesn't ask for it at all (READ_SMS outside builds made
  /// with XPENC_SMS=on), so nothing can grant it.
  notDeclared,
}

/// Talks to `PermissionsChannel.kt`. Android lets an app *ask* for a grant
/// but never revoke its own, so turning one off always goes through
/// [openSettings].
class AppPermissions {
  const AppPermissions._();

  static const _channel = MethodChannel('xpenc/permissions');

  static Future<PermissionState> status(AppPermission p) async =>
      (await statuses())[p] ?? PermissionState.unavailable;

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
    'absent' => PermissionState.notDeclared,
    _ => PermissionState.unavailable,
  };

  static Map<AppPermission, PermissionState> _allUnavailable() => {
    for (final p in AppPermission.values) p: PermissionState.unavailable,
  };
}
