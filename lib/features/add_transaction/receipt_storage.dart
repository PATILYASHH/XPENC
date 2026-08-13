import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Picks and stores receipt photos entirely on-device.
///
/// Uses the same picker as backup import (`file_picker`, not `image_picker`)
/// so attaching a receipt needs no camera or storage permission — matching
/// this app's existing "pick any file, need zero extra permissions" pattern
/// (see `BackupService`). A picked file is copied into the app's own
/// documents directory immediately on pick; the caller only writes the
/// returned path into the database once the transaction is actually saved.
class ReceiptStorage {
  const ReceiptStorage._();

  /// Opens the system file picker filtered to images. Returns the path the
  /// receipt now lives at (inside the app's own storage), or null if the
  /// user cancelled.
  static Future<String?> pickAndStore() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final pickedPath = result?.files.single.path;
    if (pickedPath == null) return null;
    return _copyIntoAppStorage(File(pickedPath));
  }

  /// Same copy-into-app-storage step as [pickAndStore], for a file that
  /// arrived some other way than the file picker — namely a screenshot
  /// handed to XPENC through the Android Share sheet (see
  /// `message_capture/share_intake.dart`), which the sharing plugin only
  /// ever hands back a path into a *temp* cache folder for.
  static Future<String> storeExternalFile(File source) =>
      _copyIntoAppStorage(source);

  static Future<String> _copyIntoAppStorage(File source) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/receipts');
    if (!await dir.exists()) await dir.create(recursive: true);

    final dot = source.path.lastIndexOf('.');
    final ext = dot == -1 ? '' : source.path.substring(dot);
    final destPath = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}$ext';
    final copy = await source.copy(destPath);
    return copy.path;
  }
}
