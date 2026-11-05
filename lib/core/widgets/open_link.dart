import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] outside the app; false when nothing could.
Future<bool> tryLaunchUrl(String url) async {
  try {
    return await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

/// Opens [url] in a browser. If no handler exists — a stripped device, a test
/// harness — [copyValue] (default [url]) goes to the clipboard instead of the
/// tap doing nothing.
Future<void> openLink(
  BuildContext context,
  String url, {
  String? copyValue,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (await tryLaunchUrl(url)) return;

  final fallback = copyValue ?? url;
  await Clipboard.setData(ClipboardData(text: fallback));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('Copied — $fallback')));
}
