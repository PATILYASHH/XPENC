import 'connector_platform_stub.dart'
    if (dart.library.js_interop) 'web/connector_platform_web.dart'
    as impl;
import 'friends/supabase_friends_api.dart';
import 'sync/connector_state.dart';
import 'sync/github_backup_api.dart';

/// Connector's sign-in (Supabase Auth, the same project the Connector app
/// signs in with) and its public anon key. Given at build time —
/// `tool/build_web.sh` reads them from `tool/web/connector.local.json` — and
/// empty in every phone build.
const _authUrl = String.fromEnvironment('CONNECTOR_AUTH_URL');
const _anonKey = String.fromEnvironment('CONNECTOR_ANON_KEY');

/// Built-in Connector, where there is one — XPENC web, built with
/// [_authUrl]. Null on phones: there, the separate Connector app syncs, and
/// XPENC itself stays offline.
final ConnectorPlatform? connectorPlatform = impl.createConnectorPlatform(
  _authUrl,
  _anonKey,
);

/// What the platform gives Connector: somewhere to keep its state, a way to
/// reach GitHub and Connector's own account, and the sign-in.
abstract interface class ConnectorPlatform {
  ConnectorStore get store;
  GithubBackupApi get api;

  /// Connector friends, read with the account's session. Null when the
  /// build has no anon key to read them with.
  SupabaseFriendsApi? get friends;

  /// How this browser names itself in commits — "XPENC web · Chrome".
  String get deviceName;

  /// Leaves for GitHub's sign-in; the app reloads on return.
  void startLogin();

  /// The sign-in's result, if this page load is its return — taken once.
  LoginResult? takeLoginResult();
}

class LoginResult {
  const LoginResult.token(String this.token, {this.session}) : error = null;
  const LoginResult.failed(String this.error) : token = null, session = null;

  /// The GitHub token, for backups.
  final String? token;

  /// The Connector account's session, for friends.
  final ConnectorSession? session;
  final String? error;
}
