import 'backup_meta.dart';

/// Everything XPENC web's Connector remembers, in one JSON blob (see
/// [ConnectorStore]). Off, with nothing in it, until the user connects.
class ConnectorState {
  ConnectorState();

  /// The GitHub token Connector's sign-in handed back — the same kind of
  /// token, from the same sign-in, as the Connector app's.
  String? token;
  String? login;

  /// Who this browser is in commit trailers — random, made once.
  String? deviceId;

  /// The commit this browser's data is built on: its own last upload, or
  /// the backup it last imported. Uploads only ever replace this one.
  String? baseCommitSha;

  /// The ledger's fingerprint as of that commit — an upload is due only
  /// once the ledger stops matching it.
  String? baselineDataSha;

  /// GitHub's newest backup, as last seen.
  RemoteBackup? remote;

  /// A backup from elsewhere the user said "Not now" to — asked about once,
  /// not on every check. Uploads stay held either way.
  String? dismissedCommitSha;

  DateTime? lastUploadAt;
  DateTime? lastCheckAt;

  /// Why sync is stuck, for the Connector page. Null when fine.
  String? problem;

  bool get connected => token != null;

  Map<String, dynamic> toJson() => {
    'token': token,
    'login': login,
    'deviceId': deviceId,
    'baseCommitSha': baseCommitSha,
    'baselineDataSha': baselineDataSha,
    'remote': remote?.toJson(),
    'dismissedCommitSha': dismissedCommitSha,
    'lastUploadAt': lastUploadAt?.toIso8601String(),
    'lastCheckAt': lastCheckAt?.toIso8601String(),
    'problem': problem,
  };

  factory ConnectorState.fromJson(Map<String, dynamic> json) {
    DateTime? time(String key) => DateTime.tryParse(json[key] as String? ?? '');
    final remote = json['remote'] as Map<String, dynamic>?;
    return ConnectorState()
      ..token = json['token'] as String?
      ..login = json['login'] as String?
      ..deviceId = json['deviceId'] as String?
      ..baseCommitSha = json['baseCommitSha'] as String?
      ..baselineDataSha = json['baselineDataSha'] as String?
      ..remote = remote == null ? null : RemoteBackup.fromJson(remote)
      ..dismissedCommitSha = json['dismissedCommitSha'] as String?
      ..lastUploadAt = time('lastUploadAt')
      ..lastCheckAt = time('lastCheckAt')
      ..problem = json['problem'] as String?;
  }
}

/// A Connector (Supabase Auth) session: what the friends list is read with.
/// Kept apart from [ConnectorState] (see [ConnectorStore.saveSession]):
/// Supabase replaces the refresh token on every refresh, and a sync saving
/// the state it loaded before a refresh mustn't put the spent one back.
class ConnectorSession {
  const ConnectorSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  /// With a minute to spare, so a call never starts on a dying token.
  bool expiredAt(DateTime now) =>
      !now.isBefore(expiresAt.subtract(const Duration(minutes: 1)));

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory ConnectorSession.fromJson(Map<String, dynamic> json) =>
      ConnectorSession(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}

/// Where [ConnectorState] lives — the browser's local storage on the web
/// (`web/local_storage_store.dart`), memory in tests.
abstract interface class ConnectorStore {
  ConnectorState load();
  void save(ConnectorState state);

  /// The Connector account's session — null for a browser connected before
  /// friends came along (reconnecting gets one).
  ConnectorSession? loadSession();
  void saveSession(ConnectorSession? session);

  /// Forgets both.
  void clear();
}
