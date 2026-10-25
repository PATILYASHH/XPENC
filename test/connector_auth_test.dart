import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/connector/auth/supabase_auth_api.dart';
import 'package:xpenc/core/connector/sync/github_backup_api.dart';

void main() {
  test('PKCE challenge matches RFC 7636 appendix B', () {
    expect(
      Pkce.challengeFor('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );
  });

  test('a verifier is 64 unreserved characters, different every time', () {
    final a = Pkce.generate(Random(1)).verifier;
    final b = Pkce.generate(Random(2)).verifier;
    expect(a, hasLength(64));
    expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(a), isTrue);
    expect(a, isNot(b));
  });

  final api = SupabaseAuthApi(
    _FakeAuth(),
    authUrl: 'https://proj.supabase.co',
    anonKey: 'anon',
  );

  test('the sign-in address carries a challenge and nothing secret', () {
    final url = api.authorizeUrl(
      redirectTo: 'https://www.xpenc.in/web',
      challenge: 'chal',
    );
    expect(url.path, '/auth/v1/authorize');
    expect(url.queryParameters, {
      'provider': 'github',
      'scopes': 'repo',
      'redirect_to': 'https://www.xpenc.in/web',
      'code_challenge': 'chal',
      'code_challenge_method': 's256',
    });
  });

  test('the code is traded for the tokens in a request body', () async {
    final fake = _FakeAuth();
    final signedIn = await SupabaseAuthApi(
      fake,
      authUrl: 'https://proj.supabase.co',
      anonKey: 'anon',
    ).exchange(code: 'c1', verifier: 'v1', now: DateTime.utc(2026, 10, 25));

    expect(fake.lastUrl!.queryParameters['grant_type'], 'pkce');
    expect(fake.lastUrl!.query, isNot(contains('c1')));
    expect(fake.lastBody, {'auth_code': 'c1', 'code_verifier': 'v1'});
    expect(signedIn.githubToken, 'gho_x');
    expect(signedIn.session.refreshToken, 'r1');
    expect(signedIn.session.expiresAt, DateTime.utc(2026, 10, 25, 1));
  });

  test('a used or stale code says to sign in again', () async {
    final fake = _FakeAuth()..refuse = true;
    await expectLater(
      SupabaseAuthApi(
        fake,
        authUrl: 'https://proj.supabase.co',
        anonKey: 'anon',
      ).exchange(code: 'old', verifier: 'v', now: DateTime.utc(2026)),
      throwsA(
        isA<ConnectorAuthException>().having(
          (e) => e.message,
          'message',
          contains('expired'),
        ),
      ),
    );
  });
}

class _FakeAuth implements HttpTransport {
  bool refuse = false;
  Uri? lastUrl;
  Map<String, dynamic>? lastBody;

  @override
  Future<HttpReply> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    expect(method, 'POST');
    expect(headers['apikey'], 'anon');
    lastUrl = url;
    lastBody = jsonDecode(utf8.decode(body!)) as Map<String, dynamic>;
    final reply = refuse
        ? (
            400,
            {
              'error_code': 'flow_state_not_found',
              'msg': 'invalid flow state, no valid flow state found',
            },
          )
        : (
            200,
            {
              'access_token': 'a1',
              'refresh_token': 'r1',
              'expires_in': 3600,
              'provider_token': 'gho_x',
            },
          );
    return HttpReply(
      reply.$1,
      Uint8List.fromList(utf8.encode(jsonEncode(reply.$2))),
    );
  }
}
