import 'dart:io';

import 'package:flutter/foundation.dart';

/// What the platform this build runs on can actually do — one place for the
/// Android-only features, so a screen hides an entry instead of each feature
/// failing on its own with a `MissingPluginException`.
///
/// iOS is the only platform with gaps today. Each one is a missing native
/// half, not a Dart limitation: home-screen widgets need a WidgetKit
/// extension, share-to-XPENC a Share extension, OCR a Vision-based plugin,
/// and the rest are things iOS simply doesn't offer an app.
abstract final class PlatformFeatures {
  /// Pretends to be (or not to be) iOS — for tests, which run on the host OS.
  @visibleForTesting
  static bool? debugIsIOS;

  static bool get isIOS => debugIsIOS ?? (!kIsWeb && Platform.isIOS);

  /// Home-screen widgets (Android's AppWidgets — see `HomeWidgetService`).
  static bool get homeWidgets => !isIOS;

  /// Picking XPENC from another app's Share sheet (see `ShareIntakeService`).
  static bool get shareIntake => !isIOS;

  /// On-device text recognition — the Tesseract plugin is Android-only.
  static bool get ocr => !isIOS;

  /// The standing quick-add notification. iOS has no ongoing notifications,
  /// and its reply action would need a notification category plus a
  /// background isolate wired up natively.
  static bool get quickAddNotification => !isIOS;

  /// Blocking screenshots and screen recording. iOS lets an app detect a
  /// screenshot after the fact, never prevent one.
  static bool get screenshotBlocking => !isIOS;

  /// Settings › Permissions. iOS manages every grant from its own Settings
  /// app, and the native half of `AppPermissions` is Android-only.
  static bool get permissionsScreen => !isIOS;

  /// Backups in the public `Download/BACKUP XPENC` folder, which outlives an
  /// uninstall. iOS has no shared folder an app may write to unasked, so
  /// there backups live in the app's own storage instead — see
  /// `BackupService`.
  static bool get durableBackupFolder => !isIOS;
}
