import 'dart:convert';

import '../sync/connector_state.dart';
import '../sync/github_backup_api.dart' show HttpReply, HttpTransport;
import 'connector_friend.dart';

/// The session was refused — expired, or signed out elsewhere.
class ConnectorAuthExpired implements Exception {}

class ConnectorFriendsException implements Exception {
  ConnectorFriendsException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'Connector error $statusCode: $message';
}

/// XPENC web's read of Connector friends: the same `profiles` and
/// `friendships` tables the Connector app reads
/// (`CONECTR/lib/core/friends/friends_repository.dart`), through Supabase's
/// REST API, as the signed-in account. Row-level security limits every read
/// to that account's own rows; nothing here writes.
class SupabaseFriendsApi {
  SupabaseFriendsApi(
    this._http, {
    required this.authUrl,
    required this.anonKey,
  });

  final HttpTransport _http;
  final String authUrl;

  /// Supabase's public "anon" key — in every Connector build too. It names
  /// the project; it grants nothing without a signed-in session.
  final String anonKey;

  static const _friendshipSelect =
      'requester:profiles!friendships_requester_id_fkey(id,username,display_name),'
      'addressee:profiles!friendships_addressee_id_fkey(id,username,display_name)';

  Map<String, String> _headers(String? accessToken) => {
    'apikey': anonKey,
    'Authorization': 'Bearer ${accessToken ?? anonKey}',
    'Accept': 'application/json',
  };

  /// A new session for [session]'s refresh token. Throws
  /// [ConnectorAuthExpired] when that token is no longer good.
  Future<ConnectorSession> refresh(
    ConnectorSession session, {
    required DateTime now,
  }) async {
    final reply = await _http.send(
      'POST',
      Uri.parse('$authUrl/auth/v1/token?grant_type=refresh_token'),
      headers: {..._headers(null), 'Content-Type': 'application/json'},
      body: utf8.encode(jsonEncode({'refresh_token': session.refreshToken})),
    );
    if (reply.status == 400 || reply.status == 401) {
      throw ConnectorAuthExpired();
    }
    final json = _json(reply) as Map<String, dynamic>;
    return ConnectorSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: now.add(
        Duration(seconds: (json['expires_in'] as num).toInt()),
      ),
    );
  }

  /// The account's username — null if it hasn't picked one — and its
  /// accepted friends, sorted by username.
  Future<({String? myUsername, List<ConnectorFriend> friends})> fetch(
    String accessToken,
  ) async {
    final myId = userIdOf(accessToken);
    final mine =
        _json(
              await _get(accessToken, 'profiles', {
                'select': 'username',
                'id': 'eq.$myId',
              }),
            )
            as List<dynamic>;
    if (mine.isEmpty) return (myUsername: null, friends: <ConnectorFriend>[]);
    final rows =
        _json(
              await _get(accessToken, 'friendships', {
                'select': _friendshipSelect,
                'status': 'eq.accepted',
              }),
            )
            as List<dynamic>;
    final friends = <ConnectorFriend>[];
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final requester = row['requester'] as Map<String, dynamic>?;
      final addressee = row['addressee'] as Map<String, dynamic>?;
      final other = requester?['id'] == myId ? addressee : requester;
      if (other != null) friends.add(ConnectorFriend.fromJson(other));
    }
    friends.sort((a, b) => a.username.compareTo(b.username));
    return (
      myUsername: (mine.first as Map<String, dynamic>)['username'] as String,
      friends: friends,
    );
  }

  Future<HttpReply> _get(
    String accessToken,
    String table,
    Map<String, String> query,
  ) async {
    final reply = await _http.send(
      'GET',
      Uri.parse('$authUrl/rest/v1/$table').replace(queryParameters: query),
      headers: _headers(accessToken),
    );
    if (reply.status == 401) throw ConnectorAuthExpired();
    return reply;
  }

  static Object? _json(HttpReply reply) {
    if (reply.status < 200 || reply.status >= 300) {
      var message = reply.text;
      try {
        final json = jsonDecode(reply.text) as Map<String, dynamic>;
        message =
            (json['message'] ??
                    json['msg'] ??
                    json['error_description'] ??
                    json['error'] ??
                    message)
                .toString();
      } catch (_) {}
      throw ConnectorFriendsException(reply.status, message);
    }
    return jsonDecode(reply.text);
  }

  /// The account id inside a Supabase access token (its `sub` claim).
  static String userIdOf(String accessToken) {
    final parts = accessToken.split('.');
    if (parts.length != 3) throw ConnectorAuthExpired();
    final payload =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
            as Map<String, dynamic>;
    final sub = payload['sub'];
    if (sub is! String || sub.isEmpty) throw ConnectorAuthExpired();
    return sub;
  }
}
