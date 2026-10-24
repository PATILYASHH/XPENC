import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards "XPENC never touches the network" — on Android, where release
/// builds don't even declare the INTERNET permission (see
/// `tool/verify_apk.sh`), and on XPENC web, where the browser would let any
/// code fetch anything and only this test notices.
///
/// Opening a link the user tapped (`url_launcher`) hands it to the browser
/// or another app, and isn't XPENC reaching out — that's allowed.
void main() {
  test('no code in lib/ can open a network connection', () {
    final networkApis = <String, RegExp>{
      'an HTTP client package': RegExp(
        r'''import\s+['"]package:(http|dio|chopper|retrofit|graphql)/''',
      ),
      'a socket package': RegExp(
        r'''import\s+['"]package:(web_socket_channel|socket_io_client)/''',
      ),
      "dart:io's HttpClient": RegExp(r'\bHttpClient\s*\('),
      "dart:io's sockets": RegExp(r'\b(Socket|RawSocket|WebSocket)\.connect\b'),
      'the browser\'s fetch / XHR / WebSocket': RegExp(
        r'''@JS\(\s*['"](fetch|XMLHttpRequest|WebSocket|EventSource|navigator\.sendBeacon)['"]''',
      ),
    };

    // XPENC web's built-in Connector — the one reviewed place, reached
    // only once the user turns Connector on (and absent from phone builds:
    // it's behind a `dart.library.js_interop` conditional import).
    final allowed = {'lib/core/connector/web/fetch_transport.dart'};

    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (allowed.contains(file.path.replaceAll(r'\', '/'))) continue;
      final source = file.readAsStringSync();
      for (final MapEntry(key: what, value: pattern) in networkApis.entries) {
        if (pattern.hasMatch(source)) offenders.add('${file.path}: $what');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'XPENC is offline by design. Network access, when it comes (the '
          'web build\'s Connector), goes through one reviewed place that '
          'this test names explicitly — never quietly from anywhere else.',
    );
  });

  test('the one place allowed is still the only one using fetch', () {
    final fetchUsers = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            file.readAsStringSync().contains('FetchTransport('))
          file.path.replaceAll(r'\', '/'),
    ];
    expect(
      fetchUsers,
      unorderedEquals([
        'lib/core/connector/web/fetch_transport.dart', // its declaration
        'lib/core/connector/web/connector_platform_web.dart',
      ]),
    );
  });
}
