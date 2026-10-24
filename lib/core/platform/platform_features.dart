import 'dart:io';

import 'package:flutter/foundation.dart';

/// What the platform this build runs on can actually do — one place for the
/// Android-only features, so a screen hides an entry instead of each feature
/// failing on its own with a `MissingPluginException`.
///
/// iOS's gaps are each a missing native half, not a Dart limitation:
/// home-screen widgets need a WidgetKit extension, share-to-XPENC a Share
/// extension, OCR a Vision-based plugin, and the rest are things iOS simply
/// doesn't offer an app. XPENC web has every one of those gaps and a few
/// more of its own: a browser has no fingerprint unlock, phone dialer,
/// contacts or notifications that outlive the tab.
abstract final class PlatformFeatures {
  /// Pretends to be (or not to be) iOS — for tests, which run on the host OS.
  @visibleForTesting
  static bool? debugIsIOS;

  /// Pretends to be (or not to be) XPENC web — same reason.
  @visibleForTesting
  static bool? debugIsWeb;

  static bool get isWeb => debugIsWeb ?? kIsWeb;

  static bool get isIOS => debugIsIOS ?? (!isWeb && Platform.isIOS);

  static bool get _android => !isWeb && !isIOS;

  /// Home-screen widgets (Android's AppWidgets — see `HomeWidgetService`).
  static bool get homeWidgets => _android;

  /// Picking XPENC from another app's Share sheet (see `ShareIntakeService`).
  static bool get shareIntake => _android;

  /// On-device text recognition — the Tesseract plugin is Android-only.
  static bool get ocr => _android;

  /// The standing quick-add notification. iOS has no ongoing notifications,
  /// and its reply action would need a notification category plus a
  /// background isolate wired up natively.
  static bool get quickAddNotification => _android;

  /// Blocking screenshots and screen recording. iOS lets an app detect a
  /// screenshot after the fact, never prevent one; a browser not even that.
  static bool get screenshotBlocking => _android;

  /// Settings › Permissions. iOS manages every grant from its own Settings
  /// app, and the native half of `AppPermissions` is Android-only.
  static bool get permissionsScreen => _android;

  /// Backups in the public `Download/BACKUP XPENC` folder, which outlives an
  /// uninstall. iOS has no shared folder an app may write to unasked, so
  /// there backups live in the app's own storage instead — see
  /// `BackupService`. On the web a backup is a file the browser downloads.
  static bool get durableBackupFolder => _android;

  /// Reminders, budget alerts and the rest of `NotificationService`. A web
  /// page's notifications die with its tab, so XPENC web shows none.
  static bool get notifications => !isWeb;

  /// Fingerprint / face unlock (`local_auth`).
  static bool get biometrics => !isWeb;

  /// Picking people from the phone's contacts (`flutter_contacts`).
  static bool get contacts => !isWeb;

  /// Paying by dialling a USSD code — needs a phone.
  static bool get ussdPay => !isWeb;
}
