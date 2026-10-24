import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/connector/connector_handoff.dart';
import 'package:xpenc/core/platform/platform_features.dart';

/// XPENC tells the Connector app which backup it just imported by that
/// file's git blob sha — the same fingerprint Connector keeps of the file it
/// pulled (`CONECTR/lib/core/backup/git_blob_sha.dart`). If the two ever
/// computed it differently, every handoff would be quietly refused.
void main() {
  test('the fingerprint is git\'s blob sha, as Connector computes it', () {
    // What `git hash-object` prints — the vectors Connector's own test uses.
    expect(gitBlobSha(const []), 'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391');
    expect(
      gitBlobSha(utf8.encode('hello\n')),
      'ce013625030ba8dba906f756967f9e9ca394464a',
    );
  });

  test('the link Connector listens for', () {
    final link = connectorImportedLink(utf8.encode('hello\n'));
    expect(link.scheme, 'conectr');
    expect(link.host, 'imported');
    expect(link.queryParameters, {
      'sha': 'ce013625030ba8dba906f756967f9e9ca394464a',
    });
  });

  test('the file name is the one Connector writes its pull under', () {
    expect(connectorPulledFileName, 'xpenc_backup.json');
  });

  test('only offered where Connector exists — Android', () {
    PlatformFeatures.debugIsWeb = true;
    addTearDown(() => PlatformFeatures.debugIsWeb = null);
    expect(PlatformFeatures.connectorHandoff, isFalse);

    PlatformFeatures.debugIsWeb = false;
    PlatformFeatures.debugIsIOS = true;
    addTearDown(() => PlatformFeatures.debugIsIOS = null);
    expect(PlatformFeatures.connectorHandoff, isFalse);

    PlatformFeatures.debugIsIOS = false;
    expect(PlatformFeatures.connectorHandoff, isTrue);
  });
}
