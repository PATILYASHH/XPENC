import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'outgoing_file.dart';

/// Written to the app's cache (`<tmp>/shared/`) — a shared file only has to
/// live until the share sheet has handed it on, and the OS reclaims cache
/// on its own.
Future<void> deliver(OutgoingFile file, {required String subject}) async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/shared');
  await dir.create(recursive: true);
  final written = File('${dir.path}/${file.name}');
  await written.writeAsBytes(file.bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(written.path, mimeType: file.mimeType)],
      subject: subject,
    ),
  );
}
