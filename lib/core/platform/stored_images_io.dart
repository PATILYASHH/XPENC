import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// `<documents>/<folder>/<microseconds><extension>` — the layout receipts and
/// person photos have always had, so existing paths keep working.
Future<String> store(String folder, Uint8List bytes, String extension) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/$folder');
  if (!await dir.exists()) await dir.create(recursive: true);
  final path = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}$extension';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}

Future<Uint8List?> read(String ref) async {
  final file = File(ref);
  return await file.exists() ? file.readAsBytes() : null;
}

Future<void> delete(String ref) async {
  try {
    final file = File(ref);
    if (await file.exists()) await file.delete();
  } catch (_) {
    // Best-effort, see StoredImages.delete.
  }
}

ImageProvider provider(String ref) => FileImage(File(ref));

bool existsSync(String ref) => File(ref).existsSync();
