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
/// system share sheet already leads with the apps used most.
bool get canShareToApps => Platform.isAndroid;

Future<ShareTargets> shareTargets() async {
  if (!Platform.isAndroid) return ShareTargets.none;
  try {
    final found = await _channel.invokeMapMethod<String, Object?>('targets');
    if (found == null) return ShareTargets.none;
    final all = [
      for (final t in (found['targets'] as List? ?? const []).cast<Map>())
        ShareTarget(
          id: t['id'] as String,
          label: t['label'] as String,
          appLabel: t['appLabel'] == t['label']
              ? null
              : t['appLabel'] as String?,
          kind: switch (t['kind']) {
            'whatsapp' => ShareTargetKind.whatsapp,
            'messages' => ShareTargetKind.messages,
            _ => ShareTargetKind.app,
          },
          takesImage: t['image'] as bool? ?? false,
          takesPdf: t['pdf'] as bool? ?? false,
        ),
    ];
    return ShareTargets(
      all: all,
      pinnedIds: (found['pinned'] as List? ?? const []).cast<String>(),
      customized: found['customized'] as bool? ?? false,
    );
  } on PlatformException {
    return ShareTargets.none;
  } on MissingPluginException {
    return ShareTargets.none;
  }
}

Future<void> pinShareTargets(List<String>? ids) async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod<void>('pin', {'ids': ids});
  } on PlatformException {
    // Stays as it was.
  } on MissingPluginException {
    // Stays as it was.
  }
}

Future<ShareTargetIcon?> shareTargetIcon(String id, int size) async {
  if (!Platform.isAndroid) return null;
  try {
    final icon = await _channel.invokeMapMethod<String, Object?>('icon', {
      'id': id,
      'size': size,
    });
    final png = icon?['png'];
    if (png is! Uint8List) return null;
    return ShareTargetIcon(png, adaptive: icon?['adaptive'] == true);
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

Future<ShareAppResult> sendTo(
  OutgoingFile file,
  ShareTarget target, {
  String? text,
  String? whatsappJid,
  String? phone,
}) async {
  if (!Platform.isAndroid) return ShareAppResult.failed;
  final written = await _write(file);
  try {
    final result = await _channel.invokeMethod<String>('send', {
      'id': target.id,
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
