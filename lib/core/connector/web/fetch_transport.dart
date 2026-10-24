import 'dart:js_interop';
import 'dart:typed_data';

import '../sync/github_backup_api.dart';

/// XPENC web's only network code: the browser's `fetch`, for Connector —
/// reached only once the user has switched Connector on, and only ever to
/// api.github.com (backups, `GithubBackupApi`) and Connector's own Supabase
/// project (friends, `SupabaseFriendsApi`). `no_network_test` allows this
/// file and nothing else.
class FetchTransport implements HttpTransport {
  const FetchTransport();

  @override
  Future<HttpReply> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    final init = _RequestInit(
      method: method,
      headers: headers.jsify()!,
      body: body == null ? null : Uint8List.fromList(body).toJS,
      // A stale cached answer would make sync act on an old commit.
      cache: 'no-store',
    );
    final response = await _fetch(url.toString(), init).toDart;
    final buffer = await response.arrayBuffer().toDart;
    return HttpReply(response.status, buffer.toDart.asUint8List());
  }
}

@JS('fetch')
external JSPromise<_Response> _fetch(String url, _RequestInit init);

extension type _RequestInit._(JSObject _) implements JSObject {
  external factory _RequestInit({
    String method,
    JSAny headers,
    JSAny? body,
    String cache,
  });
}

extension type _Response._(JSObject _) implements JSObject {
  external int get status;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}
