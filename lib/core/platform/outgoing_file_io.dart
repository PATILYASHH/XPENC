import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'outgoing_file.dart';

const _channel = MethodChannel('xpenc/share_targets');

/// Written to the app's cache (`<tmp>/shared/`) — a shared file only has to
/// live until the share sheet has handed it on, and the OS reclaims cache
/// on its own. (Android's ShareFileProvider serves exactly that folder.)
Future<File> _write(OutgoingFile file) async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/shared');
  await dir.create(recursive: true);
  final written = File('${dir.path}/${file.name}');
  await written.writeAsBytes(file.bytes, flush: true);
  return written;
}

Future<void> deliver(
  OutgoingFile file, {
  required String subject,
  String? text,
}) async {
  final written = await _write(file);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(written.path, mimeType: file.mimeType)],
      subject: subject,
      text: text,
    ),
  );
}

/// Android's `xpenc/share_targets` (ShareTargetsChannel.kt). Elsewhere the
/// system share sheet already leads with these apps.
Future<Set<ShareApp>> availableApps() async {
  if (!Platform.isAndroid) return const {};
  try {
    final found = await _channel.invokeMapMethod<String, bool>('available');
    return {
      if (found?['whatsapp'] ?? false) ShareApp.whatsapp,
      if (found?['messages'] ?? false) ShareApp.messages,
    };
  } on PlatformException {
    return const {};
  } on MissingPluginException {
    return const {};
  }
}

Future<ShareAppResult> sendTo(
  OutgoingFile file,
  ShareApp app, {
  String? text,
  String? whatsappJid,
  String? phone,
}) async {
  if (!Platform.isAndroid) return ShareAppResult.failed;
  final written = await _write(file);
  try {
    final result = await _channel.invokeMethod<String>('send', {
      'target': app.name,
      'path': written.path,
      'mimeType': file.mimeType,
      'text': text,
      'jid': whatsappJid,
      'phone': phone,
    });
    return switch (result) {
      'sent' => ShareAppResult.sent,
      'text' => ShareAppResult.textOnly,
      _ => ShareAppResult.failed,
    };
  } on PlatformException {
    return ShareAppResult.failed;
  } on MissingPluginException {
    return ShareAppResult.failed;
  }
}
