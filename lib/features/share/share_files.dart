import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [bytes] to the app's cache (`<tmp>/shared/`) — a shared file only
/// has to live until the share sheet has handed it on, and the OS reclaims
/// cache on its own.
Future<File> writeShareFile(Uint8List bytes, String name) async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/shared');
  await dir.create(recursive: true);
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

/// Hands [file] to the system share sheet — it leaves the app only when the
/// user picks where it goes.
Future<void> shareFile(
  File file, {
  required String mimeType,
  required String subject,
}) => SharePlus.instance.share(
  ShareParams(
    files: [XFile(file.path, mimeType: mimeType)],
    subject: subject,
  ),
);

/// `xpenc-ram-statement-20261008-1042` — safe on every filesystem.
String shareFileStem(String what) {
  final slug = what
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
  return 'xpenc-${slug.isEmpty ? 'share' : slug}-$stamp';
}
