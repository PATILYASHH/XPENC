import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../sync/connector_state.dart';
import '../sync/github_backup_api.dart' show HttpReply, HttpTransport;

/// PKCE (RFC 7636) for Connector's sign-in: the page keeps a random
/// [verifier] and sends only its hash. The address the sign-in returns to
/// carries a one-time code, worthless without the verifier — never a token.
class Pkce {
  const Pkce(this.verifier);

  /// 64 characters from RFC 7636's unreserved set.
  factory Pkce.generate([Random? random]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final r = random ?? Random.secure();
    return Pkce(
      String.fromCharCodes(
        List.generate(64, (_) => chars.codeUnitAt(r.nextInt(chars.length))),
      ),
    );
  }

  final String verifier;

  String get challenge => challengeFor(verifier);

  /// `BASE64URL(SHA256(verifier))`, unpadded — the S256 method.
  static String challengeFor(String verifier) => base64Url
      .encode(sha256.convert(ascii.encode(verifier)).bytes)
      .replaceAll('=', '');
}

class ConnectorAuthException implements Exception {
  ConnectorAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Connector's sign-in, as XPENC web does it: Supabase Auth with GitHub,
/// the same project and the same `repo` access the Connector app asks for.
class SupabaseAuthApi {
  SupabaseAuthApi(this._http, {required this.authUrl, required this.anonKey});

  final HttpTransport _http;
  final String authUrl;

  /// Supabase's public anon key; it names the project and grants nothing.
  final String anonKey;

  /// Where the page sends the browser to sign in. Supabase sends it back to
  /// [redirectTo] with `?code=…`.
  Uri authorizeUrl({required String redirectTo, required String challenge}) =>
      Uri.parse('$authUrl/auth/v1/authorize').replace(
        queryParameters: {
          'provider': 'github',
          'scopes': 'repo',
          'redirect_to': redirectTo,
          'code_challenge': challenge,
          'code_challenge_method': 's256',
        },
      );

  /// Trades the returned [code] for the GitHub token and the Connector
  /// session — in a request body, over HTTPS, never in an address.
  Future<({String githubToken, ConnectorSession session})> exchange({
    required String code,
    required String verifier,
    required DateTime now,
  }) async {
    final reply = await _http.send(
      'POST',
      Uri.parse('$authUrl/auth/v1/token?grant_type=pkce'),
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: utf8.encode(
        jsonEncode({'auth_code': code, 'code_verifier': verifier}),
      ),
    );
    final json = _json(reply);
    final githubToken = json['provider_token'];
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    final expiresIn = json['expires_in'];
    if (githubToken is! String || githubToken.isEmpty) {
      throw ConnectorAuthException(
        "GitHub didn't hand over access. Try Connect GitHub again.",
      );
    }
    if (access is! String || refresh is! String || expiresIn is! num) {
      throw ConnectorAuthException('The sign-in came back incomplete.');
    }
    return (
      githubToken: githubToken,
      session: ConnectorSession(
        accessToken: access,
        refreshToken: refresh,
        expiresAt: now.add(Duration(seconds: expiresIn.toInt())),
      ),
    );
  }

  static Map<String, dynamic> _json(HttpReply reply) {
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(reply.text) as Map<String, dynamic>;
    } catch (_) {}
    if (reply.status >= 200 && reply.status < 300 && json != null) return json;
    // A code already used, or left too long — the sign-in itself is done.
    if ('${json?['error_code']}'.startsWith('flow_state_')) {
      throw ConnectorAuthException(
        'that sign-in expired. Try Connect GitHub again.',
      );
    }
    final message =
        json?['error_description'] ??
        json?['msg'] ??
        json?['message'] ??
        'sign-in failed (${reply.status})';
    throw ConnectorAuthException('$message');
  }
}
