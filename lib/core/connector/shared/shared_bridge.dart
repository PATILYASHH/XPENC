import 'dart:convert';

import 'package:flutter/services.dart';

import 'shared_snapshot.dart';

/// Android: entries shared with Connector friends go through the Connector
/// app — on the phone, app to app, through its provider (which answers
/// XPENC alone). XPENC still has no internet access; Connector sends them.
/// Kotlin side: `ConnectorChannel.kt`; Connector's: `XpencProvider.kt`.
class SharedBridge {
  const SharedBridge();

  static const _channel = MethodChannel('xpenc/connector');
  static const _changes = EventChannel('xpenc/connector/changes');

  /// [SharedSnapshot.none] when there's no Connector that shares entries.
  Future<SharedSnapshot> load() async {
    final reply = await _channel.invokeMapMethod<String, Object?>('shared');
    if (reply == null || reply['installed'] != true) return SharedSnapshot.none;
    if (reply['outdated'] == true || reply['refused'] == true) {
      return SharedSnapshot.none;
    }
    return SharedSnapshot.parse(
      reply['json'] as String?,
      reply['outbox'] as String?,
    );
  }

  /// Hands [op] to Connector, which sends it as soon as it's online. False
  /// when Connector wouldn't take it.
  Future<bool> send(Map<String, Object?> op) async =>
      await _channel.invokeMethod<bool>('sharedOp', jsonEncode(op)) ?? false;

  /// Asks Connector to sync now — say, as XPENC opens.
  Future<void> sync() => _channel.invokeMethod<bool>('sharedSync');

  /// Fires whenever what [load] reads may have changed.
  Stream<void> get changes => _changes.receiveBroadcastStream().map((_) {});
}
