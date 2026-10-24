import 'dart:js_interop';

import 'outgoing_file.dart';

/// A browser download: the bytes as a Blob, clicked through a throwaway
/// `<a download>`. Nothing leaves the machine — the file goes to the
/// browser's own downloads.
Future<void> deliver(OutgoingFile file, {required String subject}) async {
  final blob = _Blob(
    <JSAny>[file.bytes.toJS].toJS,
    _BlobOptions(type: file.mimeType),
  );
  final url = _createObjectUrl(blob);
  final anchor = _createElement('a')
    ..href = url
    ..download = file.name;
  // In the document, not detached: some browsers ignore a detached click.
  _body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  // The click only queues the download; revoking at once can cancel it.
  await Future<void>.delayed(const Duration(seconds: 2));
  _revokeObjectUrl(url);
}

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny> parts, _BlobOptions options);
}

extension type _BlobOptions._(JSObject _) implements JSObject {
  external factory _BlobOptions({String type});
}

extension type _Element._(JSObject _) implements JSObject {
  external set href(String value);
  external set download(String value);
  external void click();
  external void remove();
  external void appendChild(_Element child);
}

@JS('document.createElement')
external _Element _createElement(String tag);

@JS('document.body')
external _Element get _body;

@JS('URL.createObjectURL')
external String _createObjectUrl(_Blob blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(String url);
