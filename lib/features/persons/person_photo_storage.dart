import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/platform/platform_features.dart';
import '../../core/platform/stored_images.dart';

/// Stores a person's photo entirely on-device — the same "copy the bytes
/// into the app's own documents directory immediately, write only the path
/// into the database" pattern `ReceiptStorage` uses for receipt images.
///
/// Two sources: a contact picked via `EditPersonSheet._pickFromContacts` —
/// the picker hands back raw bytes (a thumbnail pulled from the device's
/// address book), not a file, so they're written out once ([storeBytes]) —
/// and a photo chosen from the gallery (`EditPersonSheet._pickFromGallery`),
/// which arrives as a temp file to copy in ([storeFile]).
class PersonPhotoStorage {
  const PersonPhotoStorage._();

  /// Copies a picked image into app storage, keeping its extension (a PNG
  /// stays a PNG). Returns the new path.
  static Future<String> storeFile(File source) async {
    final dir = await _dir();
    final dot = source.path.lastIndexOf('.');
    final ext = dot == -1 ? '.jpg' : source.path.substring(dot);
    final path = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}$ext';
    return (await source.copy(path)).path;
  }

  /// A gallery pick by its bytes — the only form the browser hands one
  /// over in.
  static Future<String> storePicked(XFile picked) async {
    if (!PlatformFeatures.isWeb) return storeFile(File(picked.path));
    return StoredImages.store(
      _folder,
      await picked.readAsBytes(),
      extension: StoredImages.extensionOf(picked.name),
    );
  }

  static Future<String> storeBytes(Uint8List bytes) async {
    if (PlatformFeatures.isWeb) return StoredImages.store(_folder, bytes);
    final dir = await _dir();
    final path = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  static const _folder = 'person_photos';

  static Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
