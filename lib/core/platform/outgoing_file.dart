import 'package:flutter/foundation.dart';

import 'outgoing_file_io.dart'
    if (dart.library.js_interop) 'outgoing_file_web.dart'
    as impl;

/// A messaging app a share can go to straight, skipping the share sheet —
/// on Android, when it's installed.
enum ShareApp { whatsapp, messages }

/// How [OutgoingFile.sendTo] went. [textOnly]: the messages app wouldn't
/// take the file, so only the message text went.
enum ShareAppResult { sent, textOnly, failed }

/// A file XPENC made for the user to take away — an export, a statement, a
/// share card, a backup. On a phone it goes to the system share sheet, so
/// it leaves only when the user picks where; XPENC web downloads it.
class OutgoingFile {
  const OutgoingFile({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;

  /// Stands in for the share sheet / download — for tests, which have
  /// neither.
  @visibleForTesting
  static Future<void> Function(OutgoingFile file, String subject)? debugDeliver;

  /// For tests: which [ShareApp]s the phone has, and a stand-in for
  /// handing a file to one.
  @visibleForTesting
  static Set<ShareApp>? debugApps;
  @visibleForTesting
  static Future<ShareAppResult> Function(
    OutgoingFile file,
    ShareApp app,
    String? text,
  )?
  debugSendTo;

  /// [subject] names it for share targets that ask (email, mostly); [text]
  /// goes with it as the message, where the target takes one.
  Future<void> deliver({required String subject, String? text}) =>
      debugDeliver?.call(this, subject) ??
      impl.deliver(this, subject: subject, text: text);

  /// The [ShareApp]s this device can send to straight — none off Android.
  static Future<Set<ShareApp>> availableApps() =>
      debugApps != null ? Future.value(debugApps) : impl.availableApps();

  /// Straight into [app], with [text] as the message: into the chat of
  /// [whatsappJid] (international digits, no `+`) on WhatsApp, addressed to
  /// [phone] in Messages. The user still taps Send there.
  Future<ShareAppResult> sendTo(
    ShareApp app, {
    String? text,
    String? whatsappJid,
    String? phone,
  }) =>
      debugSendTo?.call(this, app, text) ??
      impl.sendTo(
        this,
        app,
        text: text,
        whatsappJid: whatsappJid,
        phone: phone,
      );
}
