import 'dart:convert';

import 'package:flutter/services.dart';

import '../sync/connector_state.dart';
import 'connector_friend.dart';
import 'supabase_friends_api.dart';

/// Where XPENC reads Connector friends from — a read, never a write: linking
/// a person to a friend stays on this device (and in its backups).
abstract interface class ConnectorFriendsSource {
  Future<FriendsLookup> load();
}

/// Android: the Connector app shares its friends list with XPENC — and only
/// XPENC, checked by its signing certificate — through a ContentProvider
/// (`CONECTR/android/.../FriendsProvider.kt`); `ConnectorFriendsChannel.kt`
/// reads it. On the device, app to app: XPENC still has no internet access.
class AndroidFriendsSource implements ConnectorFriendsSource {
  const AndroidFriendsSource();

  static const _channel = MethodChannel('xpenc/connector_friends');

  @override
  Future<FriendsLookup> load() async {
    final reply = await _channel.invokeMapMethod<String, Object?>('load');
    return readAndroidReply(reply ?? const {});
  }

  /// Opens the Connector app — to sign in, add friends, or refresh the list
  /// it shares. False when it isn't installed.
  static Future<bool> openConnector() async =>
      await _channel.invokeMethod<bool>('open') ?? false;
}

/// [AndroidFriendsSource]'s reply, read. Public for tests. `json` is what
/// the Connector app last shared (`CONECTR/lib/features/friends/
/// friends_cache.dart`) — null if it never has.
FriendsLookup readAndroidReply(Map<String, Object?> reply) {
  if (reply['installed'] != true) return const FriendsHidden();
  if (reply['refused'] == true) {
    return const FriendsNotReady(
      "Connector didn't recognise this copy of XPENC. Install both apps "
      'from the same place (GitHub, Play or F-Droid) and try again.',
    );
  }
  if (reply['outdated'] == true) {
    return const FriendsNotReady(
      'Update the Connector app to see your friends here.',
    );
  }
  final raw = reply['json'];
  if (raw is! String) {
    return const FriendsNotReady(
      'Open the Connector app once so it can share your friends with XPENC.',
    );
  }
  final shared = jsonDecode(raw) as Map<String, dynamic>;
  if (shared['signedIn'] != true) {
    return const FriendsNotReady(
      'Sign in to the Connector app to see your friends here.',
    );
  }
  final username = shared['username'] as String?;
  if (username == null) {
    return const FriendsNotReady(
      'Pick a username in the Connector app first — friends find each '
      'other by it.',
    );
  }
  final friends = [
    for (final row in (shared['friends'] as List<dynamic>? ?? const []))
      ConnectorFriend.fromJson(row as Map<String, dynamic>),
  ]..sort((a, b) => a.username.compareTo(b.username));
  final updatedAt = shared['updatedAt'] as int?;
  return FriendsLoaded(
    myUsername: username,
    friends: friends,
    updatedAt: updatedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(updatedAt),
  );
}

/// XPENC web: friends read live from Connector's account, with the session
/// the Connector sign-in handed back (Settings → Connector).
class SessionFriendsSource implements ConnectorFriendsSource {
  SessionFriendsSource({
    required this.store,
    required this.api,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ConnectorStore store;
  final SupabaseFriendsApi api;
  final DateTime Function() _now;

  static const _reconnect = FriendsNotReady(
    'Connector needs you to sign in again: Settings → Connector → '
    'Disconnect, then Connect GitHub.',
  );

  @override
  Future<FriendsLookup> load() async {
    if (!store.load().connected) {
      return const FriendsNotReady(
        'Turn on Connector in Settings → Connector to see your friends here.',
      );
    }
    var session = store.loadSession();
    if (session == null) return _reconnect;
    try {
      if (session.expiredAt(_now())) session = await _refresh(session);
      ({String? myUsername, List<ConnectorFriend> friends}) found;
      try {
        found = await api.fetch(session.accessToken);
      } on ConnectorAuthExpired {
        // Refused before its time (signed out elsewhere, clock skew): one
        // fresh token, then give up.
        found = await api.fetch((await _refresh(session)).accessToken);
      }
      final me = found.myUsername;
      if (me == null) {
        return const FriendsNotReady(
          'Pick a username in the Connector app first — friends find each '
          'other by it.',
        );
      }
      return FriendsLoaded(myUsername: me, friends: found.friends);
    } on ConnectorAuthExpired {
      store.saveSession(null);
      return _reconnect;
    }
  }

  Future<ConnectorSession> _refresh(ConnectorSession session) async {
    final fresh = await api.refresh(session, now: _now());
    store.saveSession(fresh);
    return fresh;
  }
}
