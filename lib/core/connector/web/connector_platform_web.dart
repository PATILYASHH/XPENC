import 'dart:js_interop';

import '../auth/supabase_auth_api.dart';
import '../connector_platform.dart';
import '../friends/supabase_friends_api.dart';
import '../sync/connector_state.dart';
import '../sync/github_backup_api.dart';
import 'fetch_transport.dart';
import 'local_storage_store.dart';

/// XPENC web's built-in Connector — only in a build given both its sign-in
/// address and anon key.
ConnectorPlatform? createConnectorPlatform(String authUrl, String anonKey) =>
    authUrl.isEmpty || anonKey.isEmpty
    ? null
    : _WebConnectorPlatform(authUrl, anonKey);

class _WebConnectorPlatform implements ConnectorPlatform {
  _WebConnectorPlatform(this._authUrl, this._anonKey);

  final String _authUrl;
  final String _anonKey;

  /// The PKCE verifier between leaving for GitHub and coming back — in this
  /// tab's session storage, so it never leaves the browser.
  static const _verifierKey = 'xpenc.connector.pkce';

  /// Where the page lands back, connected.
  static const _connectorRoute = '#/more/settings/connector';

  SupabaseAuthApi get _auth => SupabaseAuthApi(
    const FetchTransport(),
    authUrl: _authUrl,
    anonKey: _anonKey,
  );

  @override
  ConnectorStore get store => const LocalStorageStore();

  @override
  GithubBackupApi get api => GithubBackupApi(const FetchTransport());

  @override
  SupabaseFriendsApi get friends => SupabaseFriendsApi(
    const FetchTransport(),
    authUrl: _authUrl,
    anonKey: _anonKey,
  );

  @override
  String get deviceName => 'XPENC web · ${_browserName(_navigator.userAgent)}';

  /// Off to GitHub, through Connector's own sign-in (Supabase Auth): it asks
  /// for the same `repo` access the Connector app does. PKCE: the address it
  /// comes back to carries only a one-time code (see [takeLoginReturn]).
  @override
  void startLogin() {
    final pkce = Pkce.generate();
    try {
      _sessionStorage.setItem(_verifierKey, pkce.verifier);
    } catch (_) {
      // Storage blocked: the return will say to try again.
    }
    final here = '${_location.origin}${_location.pathname}';
    _location.assign(
      _auth
          .authorizeUrl(redirectTo: here, challenge: pkce.challenge)
          .toString(),
    );
  }

  @override
  LoginReturn? takeLoginReturn() {
    final query = Uri.splitQueryString(_location.search.replaceFirst('?', ''));
    final hash = _location.hash;
    // The app's own routes live in the hash (`#/dashboard`); only a sign-in
    // return puts parameters there.
    final hashParams =
        hash.contains('access_token=') ||
            hash.contains('provider_token=') ||
            hash.startsWith('#error')
        ? Uri.splitQueryString(hash.substring(1))
        : const <String, String>{};
    final code = query['code'];
    final error =
        query['error_description'] ??
        query['error'] ??
        hashParams['error_description'] ??
        hashParams['error'];
    if (code == null && error == null && hashParams.isEmpty) return null;

    // Out of the address bar and its history entry at once, landing on the
    // Connector page.
    _history.replaceState(null, '', '${_location.pathname}$_connectorRoute');
    String? verifier;
    try {
      verifier = _sessionStorage.getItem(_verifierKey);
      _sessionStorage.removeItem(_verifierKey);
    } catch (_) {}

    if (code != null) {
      if (verifier == null) {
        return const LoginFailed(
          'the sign-in started in another tab or was interrupted. Try '
          'Connect GitHub again.',
        );
      }
      return LoginCode(code, verifier);
    }
    if (error != null) return LoginFailed(error);
    // Tokens in the address — an old-style return. Wiped above and not
    // used: an address isn't a safe place for them to have been.
    return const LoginFailed('please press Connect GitHub again.');
  }

  @override
  Future<LoginResult> finishLogin(LoginCode code) async {
    final signedIn = await _auth.exchange(
      code: code.code,
      verifier: code.verifier,
      now: DateTime.now(),
    );
    return LoginResult(signedIn.githubToken, session: signedIn.session);
  }

  static String _browserName(String ua) {
    if (ua.contains('Edg/')) return 'Edge';
    if (ua.contains('OPR/')) return 'Opera';
    if (ua.contains('Firefox/')) return 'Firefox';
    if (ua.contains('Chrome/')) return 'Chrome';
    if (ua.contains('Safari/')) return 'Safari';
    return 'browser';
  }
}

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator._(JSObject _) implements JSObject {
  external String get userAgent;
}

@JS('location')
external _Location get _location;

extension type _Location._(JSObject _) implements JSObject {
  external String get origin;
  external String get hash;
  external String get search;
  external String get pathname;
  external void assign(String url);
}

@JS('history')
external _History get _history;

extension type _History._(JSObject _) implements JSObject {
  external void replaceState(JSAny? data, String title, String url);
}

@JS('sessionStorage')
external _Storage get _sessionStorage;

extension type _Storage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}
