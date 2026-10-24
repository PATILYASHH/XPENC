import 'browser_storage_io.dart'
    if (dart.library.js_interop) 'browser_storage_web.dart'
    as impl;

/// XPENC web keeps the whole ledger in the browser's storage, which the
/// browser may clear on its own under storage pressure unless the site is
/// marked persistent. Asks for that — Chrome decides silently, Firefox asks
/// the user once. A no-op anywhere but the web.
Future<void> requestPersistentStorage() => impl.requestPersistentStorage();
