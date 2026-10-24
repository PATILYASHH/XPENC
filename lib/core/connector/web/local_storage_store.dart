import 'dart:convert';
import 'dart:js_interop';

import '../sync/connector_state.dart';

/// [ConnectorState] in the browser's local storage, under XPENC's own key.
/// The same origin storage as the ledger: clearing the site's data forgets
/// both together.
class LocalStorageStore implements ConnectorStore {
  const LocalStorageStore();

  static const _key = 'xpenc.connector';
  static const _sessionKey = 'xpenc.connector.session';

  @override
  ConnectorState load() {
    try {
      final raw = _storage.getItem(_key);
      if (raw == null) return ConnectorState();
      return ConnectorState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Unreadable (or storage blocked): start over rather than wedge.
      return ConnectorState();
    }
  }

  @override
  void save(ConnectorState state) {
    try {
      _storage.setItem(_key, jsonEncode(state.toJson()));
    } catch (_) {
      // Storage blocked (a private window, say): sync simply won't remember.
    }
  }

  @override
  ConnectorSession? loadSession() {
    try {
      final raw = _storage.getItem(_sessionKey);
      if (raw == null) return null;
      return ConnectorSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  void saveSession(ConnectorSession? session) {
    try {
      session == null
          ? _storage.removeItem(_sessionKey)
          : _storage.setItem(_sessionKey, jsonEncode(session.toJson()));
    } catch (_) {}
  }

  @override
  void clear() {
    try {
      _storage
        ..removeItem(_key)
        ..removeItem(_sessionKey);
    } catch (_) {}
  }
}

@JS('localStorage')
external _Storage get _storage;

extension type _Storage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}
