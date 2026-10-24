import 'dart:async';
import 'dart:js_interop';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Every reference this file hands out starts with this — a phone's file
/// path never does.
const _prefix = 'xpenc-web-image:';

/// An IndexedDB database of XPENC's own, next to the one drift keeps the
/// ledger in: the same storage, so wherever the ledger can be saved its
/// photos can too, and the browser keeps (or clears) them together.
const _dbName = 'xpenc-images';
const _storeName = 'images';

Future<_Database>? _opening;

Future<_Database> _database() => _opening ??= _open().catchError((Object e) {
  _opening = null; // let the next call try again
  throw e;
});

Future<_Database> _open() {
  final done = Completer<_Database>();
  final request = _indexedDB.open(_dbName, 1);
  request.onupgradeneeded = ((JSObject _) {
    (request.result! as _Database).createObjectStore(_storeName);
  }).toJS;
  request.onsuccess = ((JSObject _) {
    done.complete(request.result! as _Database);
  }).toJS;
  request.onerror = ((JSObject _) {
    done.completeError(StateError('Couldn\'t open image storage.'));
  }).toJS;
  return done.future;
}

/// Resolves once the write is committed, not merely queued.
Future<void> _write(void Function(_Store store) change) async {
  final database = await _database();
  final transaction = database.transaction(_storeName.toJS, 'readwrite');
  final done = Completer<void>();
  void failed(JSObject _) {
    if (!done.isCompleted) {
      done.completeError(StateError('Couldn\'t save the image.'));
    }
  }

  transaction.oncomplete = ((JSObject _) => done.complete()).toJS;
  transaction.onerror = failed.toJS;
  transaction.onabort = failed.toJS;
  change(transaction.objectStore(_storeName));
  return done.future;
}

Future<String> store(String folder, Uint8List bytes, String extension) async {
  final ref =
      '$_prefix$folder/${DateTime.now().microsecondsSinceEpoch}$extension';
  await _write((store) => store.put(bytes.toJS, ref.toJS));
  return ref;
}

Future<Uint8List?> read(String ref) async {
  if (!ref.startsWith(_prefix)) return null;
  final database = await _database();
  final request = database
      .transaction(_storeName.toJS, 'readonly')
      .objectStore(_storeName)
      .get(ref.toJS);
  final done = Completer<JSAny?>();
  request.onsuccess = ((JSObject _) => done.complete(request.result)).toJS;
  request.onerror = ((JSObject _) {
    done.completeError(StateError('Couldn\'t read the image.'));
  }).toJS;
  final value = await done.future;
  return value == null ? null : (value as JSUint8Array).toDart;
}

Future<void> delete(String ref) async {
  if (!ref.startsWith(_prefix)) return;
  try {
    await _write((store) => store.delete(ref.toJS));
  } catch (_) {
    // Best-effort, see StoredImages.delete.
  }
}

ImageProvider provider(String ref) => _StoredImage(ref);

bool existsSync(String ref) => ref.startsWith(_prefix);

/// Loads through [read]; a missing image fails the way an unreadable file
/// does, so `errorBuilder`s and placeholders behave the same as on a phone.
@immutable
class _StoredImage extends ImageProvider<_StoredImage> {
  const _StoredImage(this.ref);

  final String ref;

  @override
  Future<_StoredImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _StoredImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _codec(decode),
    scale: 1,
    debugLabel: ref,
  );

  Future<ui.Codec> _codec(ImageDecoderCallback decode) async {
    final bytes = await read(ref);
    if (bytes == null) throw StateError('No stored image for $ref');
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is _StoredImage && other.ref == ref;

  @override
  int get hashCode => ref.hashCode;
}

@JS('indexedDB')
external _Factory get _indexedDB;

extension type _Factory._(JSObject _) implements JSObject {
  external _OpenRequest open(String name, int version);
}

extension type _Request._(JSObject _) implements JSObject {
  external JSAny? get result;
  external set onsuccess(JSFunction handler);
  external set onerror(JSFunction handler);
}

extension type _OpenRequest._(JSObject _) implements _Request {
  external set onupgradeneeded(JSFunction handler);
}

extension type _Database._(JSObject _) implements JSObject {
  external _Transaction transaction(JSAny storeNames, String mode);
  external JSObject createObjectStore(String name);
}

extension type _Transaction._(JSObject _) implements JSObject {
  external _Store objectStore(String name);
  external set oncomplete(JSFunction handler);
  external set onerror(JSFunction handler);
  external set onabort(JSFunction handler);
}

extension type _Store._(JSObject _) implements JSObject {
  external _Request put(JSAny value, JSAny key);
  external _Request get(JSAny key);
  external _Request delete(JSAny key);
}
