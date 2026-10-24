import 'dart:convert';
import 'dart:typed_data';

/// One HTTP exchange. XPENC web's is the browser's `fetch`
/// (`web/fetch_transport.dart`) — the only network code XPENC has, and only
/// ever reached once Connector is switched on. Tests use a fake.
abstract interface class HttpTransport {
  Future<HttpReply> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    List<int>? body,
  });
}

class HttpReply {
  const HttpReply(this.status, this.body);

  final int status;
  final Uint8List body;

  String get text => utf8.decode(body, allowMalformed: true);
}

class GithubApiException implements Exception {
  GithubApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'GitHub error $statusCode: $message';
}

/// A write refused because the file changed since it was looked at — another
/// device uploaded in between. Nothing was overwritten.
class GithubConflict extends GithubApiException {
  GithubConflict(super.statusCode, super.message);
}

class RemoteCommit {
  const RemoteCommit({
    required this.sha,
    required this.message,
    required this.date,
  });

  final String sha;
  final String message;
  final DateTime date;
}

/// The handful of GitHub REST calls Connector needs — the same calls, on
/// the same repo and file, the Connector app makes
/// (`CONECTR/lib/core/github/github_api.dart`).
class GithubBackupApi {
  GithubBackupApi(this._http);

  final HttpTransport _http;

  static final _base = Uri.parse('https://api.github.com');

  Map<String, String> _headers(String token, {String? accept}) => {
    'Authorization': 'Bearer $token',
    'Accept': accept ?? 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };

  Uri _url(String path, [Map<String, String>? query]) =>
      _base.replace(path: path, queryParameters: query);

  Future<HttpReply> _ok(Future<HttpReply> request) async {
    final reply = await request;
    if (reply.status >= 200 && reply.status < 300) return reply;
    throw GithubApiException(reply.status, _message(reply));
  }

  static String _message(HttpReply reply) {
    try {
      final json = jsonDecode(reply.text) as Map<String, dynamic>;
      return json['message'] as String? ?? reply.text;
    } catch (_) {
      return reply.text;
    }
  }

  Future<String> login(String token) async {
    final reply = await _ok(
      _http.send('GET', _url('/user'), headers: _headers(token)),
    );
    return (jsonDecode(reply.text) as Map<String, dynamic>)['login'] as String;
  }

  Future<bool> repoExists(String token, String owner, String repo) async {
    final reply = await _http.send(
      'GET',
      _url('/repos/$owner/$repo'),
      headers: _headers(token),
    );
    if (reply.status == 404) return false;
    if (reply.status >= 300) {
      throw GithubApiException(reply.status, _message(reply));
    }
    return true;
  }

  Future<void> createPrivateRepo(String token, String repo) => _ok(
    _http.send(
      'POST',
      _url('/user/repos'),
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: utf8.encode(
        jsonEncode({
          'name': repo,
          'private': true,
          'description': 'XPENC backup data. Managed by the Connector app.',
          'auto_init': false,
        }),
      ),
    ),
  );

  /// The newest commit touching [path]; null when there's none yet — no
  /// file, an empty repo (409) or no repo (404).
  Future<RemoteCommit?> latestCommit(
    String token,
    String owner,
    String repo,
    String path,
  ) async {
    final reply = await _http.send(
      'GET',
      _url('/repos/$owner/$repo/commits', {'path': path, 'per_page': '1'}),
      headers: _headers(token),
    );
    if (reply.status == 404 || reply.status == 409) return null;
    if (reply.status >= 300) {
      throw GithubApiException(reply.status, _message(reply));
    }
    final commits = jsonDecode(reply.text) as List<dynamic>;
    if (commits.isEmpty) return null;
    final latest = commits.first as Map<String, dynamic>;
    final commit = latest['commit'] as Map<String, dynamic>;
    final committer = commit['committer'] as Map<String, dynamic>;
    return RemoteCommit(
      sha: latest['sha'] as String,
      message: commit['message'] as String,
      date: DateTime.parse(committer['date'] as String).toUtc(),
    );
  }

  /// The blob sha of [path] as of commit [ref]; null if it didn't exist.
  Future<String?> fileSha(
    String token,
    String owner,
    String repo,
    String path, {
    required String ref,
  }) async {
    final reply = await _http.send(
      'GET',
      _url('/repos/$owner/$repo/contents/$path', {'ref': ref}),
      headers: _headers(token, accept: 'application/vnd.github.object+json'),
    );
    if (reply.status == 404) return null;
    if (reply.status >= 300) {
      throw GithubApiException(reply.status, _message(reply));
    }
    return (jsonDecode(reply.text) as Map<String, dynamic>)['sha'] as String;
  }

  /// [path]'s bytes as of commit [ref] — the raw media type, so a backup
  /// past the Contents API's 1 MB inline limit still arrives whole.
  Future<Uint8List?> fileBytes(
    String token,
    String owner,
    String repo,
    String path, {
    required String ref,
  }) async {
    final reply = await _http.send(
      'GET',
      _url('/repos/$owner/$repo/contents/$path', {'ref': ref}),
      headers: _headers(token, accept: 'application/vnd.github.raw+json'),
    );
    if (reply.status == 404) return null;
    if (reply.status >= 300) {
      throw GithubApiException(reply.status, _message(reply));
    }
    return reply.body;
  }

  /// Writes [bytes] to [path] and returns the new commit's sha. GitHub only
  /// writes while the file is still [existingSha] (null: doesn't exist yet);
  /// otherwise this throws [GithubConflict].
  Future<String> putFile(
    String token,
    String owner,
    String repo,
    String path, {
    required List<int> bytes,
    required String message,
    String? existingSha,
  }) async {
    final reply = await _http.send(
      'PUT',
      _url('/repos/$owner/$repo/contents/$path'),
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: utf8.encode(
        jsonEncode({
          'message': message,
          'content': base64Encode(bytes),
          'sha': ?existingSha,
        }),
      ),
    );
    final conflict =
        reply.status == 409 ||
        (reply.status == 422 && _message(reply).contains('sha'));
    if (conflict) throw GithubConflict(reply.status, _message(reply));
    if (reply.status >= 300) {
      throw GithubApiException(reply.status, _message(reply));
    }
    final json = jsonDecode(reply.text) as Map<String, dynamic>;
    return (json['commit'] as Map<String, dynamic>)['sha'] as String;
  }
}
