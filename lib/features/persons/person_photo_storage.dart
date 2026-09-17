import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Stores a person's photo entirely on-device — the same "copy the bytes
/// into the app's own documents directory immediately, write only the path
/// into the database" pattern `ReceiptStorage` uses for receipt images.
///
/// The one source today is a contact picked via `EditPersonSheet._pickFromContacts`:
/// the picker hands back raw bytes (a thumbnail pulled from the device's
/// address book), not a file, so there's nothing to copy — just write them
/// out once and keep only the resulting path.
class PersonPhotoStorage {
  const PersonPhotoStorage._();

  static Future<String> storeBytes(Uint8List bytes) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/person_photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    final path = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }
}
