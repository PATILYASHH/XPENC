import 'dart:typed_data';

import 'package:flutter/painting.dart';

import 'stored_images_io.dart'
    if (dart.library.js_interop) 'stored_images_web.dart'
    as impl;

/// Receipt photos and person photos, kept in XPENC's own storage: a file in
/// the app's documents folder on a phone, an IndexedDB entry in XPENC web.
/// Either way the database holds only the reference [store] returns.
///
/// A reference made on one platform means nothing on the other — a phone's
/// file path in a backup imported on the web, say — so every reader here
/// treats an unknown reference as a missing image rather than an error.
abstract final class StoredImages {
  /// Saves [bytes] under [folder] (`receipts`, `person_photos`) and returns
  /// the reference to store. [extension] keeps a PNG a PNG.
  static Future<String> store(
    String folder,
    Uint8List bytes, {
    String extension = '.jpg',
  }) => impl.store(folder, bytes, extension);

  static Future<Uint8List?> read(String ref) => impl.read(ref);

  /// Best-effort — an image already gone is not an error.
  static Future<void> delete(String ref) => impl.delete(ref);

  /// For `Image(image: …)`, `CircleAvatar(backgroundImage: …)` and the like;
  /// a missing image fails like any image that can't load, so callers'
  /// error builders still apply.
  static ImageProvider provider(String ref) => impl.provider(ref);

  /// A quick, synchronous "is there plausibly an image here" for widgets
  /// that pick between a photo and a placeholder while building.
  static bool existsSync(String ref) => impl.existsSync(ref);

  /// `.png` from `scan.png` — what [store] wants as its extension, `.jpg`
  /// when the name has none.
  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot == -1 ? '.jpg' : fileName.substring(dot);
  }
}
