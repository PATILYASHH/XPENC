import 'dart:js_interop';

import '../connector_platform.dart';
import '../friends/supabase_friends_api.dart';
import '../sync/connector_state.dart';
import '../sync/github_backup_api.dart';
import 'fetch_transport.dart';
import 'local_storage_store.dart';

/// XPENC web's built-in Connector.
ConnectorPlatform? createConnectorPlatform(String authUrl, String anonKey) =>
    authUrl.isEmpty ? null : _WebConnectorPlatform(authUrl, anonKey);

class _WebConnectorPlatform implements ConnectorPlatform {
  _WebConnectorPlatform(this._authUrl, this._anonKey);

  final String _authUrl;
  final String _anonKey;

  @override
  ConnectorStore get store => const LocalStorageStore();

  @override
  GithubBackupApi get api => GithubBackupApi(const FetchTransport());

  @override
  SupabaseFriendsApi? get friends => _anonKey.isEmpty
      ? null
      : SupabaseFriendsApi(
          const FetchTransport(),
          authUrl: _authUrl,
          anonKey: _anonKey,
        );

  @override
  String get deviceName => 'XPENC web · ${_browserName(_navigator.userAgent)}';

  /// Off to GitHub, through Connector's own sign-in (Supabase Auth): it asks
  /// for the same `repo` access the Connector app does, then comes back to
  /// this page with the token in the address (see [takeLoginResult]).
  @override
  void startLogin() {
    final here = Uri.parse(_location.href).replace(fragment: '');
    final authorize = Uri.parse('$_authUrl/auth/v1/authorize').replace(
      queryParameters: {
        'provider': 'github',
        'scopes': 'repo',
        'redirect_to': here.toString().replaceAll(RegExp(r'#$'), ''),
      },
    );
    _location.assign(authorize.toString());
  }

  @override
  LoginResult? takeLoginResult() {
    final hash = _location.hash;
    if (!hash.contains('provider_token=') && !hash.contains('error=')) {
      return null;
    }
    final params = Uri.splitQueryString(hash.replaceFirst('#', ''));
    // Out of the address bar (and history) at once: the token is a secret,
    // and the app's own routes live in the hash.
    _history.replaceState(null, '', _location.pathname);
    final token = params['provider_token'];
    if (token != null && token.isNotEmpty) {
      return LoginResult.token(token, session: _session(params));
    }
    return LoginResult.failed(
      params['error_description'] ?? params['error'] ?? 'Sign-in failed.',
    );
  }

  /// The Connector account's own session, from the same return.
  static ConnectorSession? _session(Map<String, String> params) {
    final access = params['access_token'];
    final refresh = params['refresh_token'];
    final expiresIn = int.tryParse(params['expires_in'] ?? '');
    if (access == null || refresh == null || expiresIn == null) return null;
    return ConnectorSession(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
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
  external String get href;
  external String get hash;
  external String get pathname;
  external void assign(String url);
}

@JS('history')
external _History get _history;

extension type _History._(JSObject _) implements JSObject {
  external void replaceState(JSAny? data, String title, String url);
}
