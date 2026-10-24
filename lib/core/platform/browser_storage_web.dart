import 'dart:js_interop';

Future<void> requestPersistentStorage() async {
  final storage = _storage;
  if (storage == null) return;
  try {
    if ((await storage.persisted().toDart).toDart) return;
    await storage.persist().toDart;
  } catch (_) {
    // Best-effort: refused or unsupported leaves things as they were.
  }
}

@JS('navigator.storage')
external _StorageManager? get _storage;

extension type _StorageManager._(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> persisted();
  external JSPromise<JSBoolean> persist();
}
