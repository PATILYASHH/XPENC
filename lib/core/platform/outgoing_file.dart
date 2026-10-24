import 'package:flutter/foundation.dart';

import 'outgoing_file_io.dart'
    if (dart.library.js_interop) 'outgoing_file_web.dart'
    as impl;

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

  /// [subject] names it for share targets that ask (email, mostly).
  Future<void> deliver({required String subject}) =>
      debugDeliver?.call(this, subject) ?? impl.deliver(this, subject: subject);
}
