import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';

/// Connector is a separate, online Android app that carries XPENC's backups
/// between phones through the user's GitHub; XPENC itself never touches the
/// network. The two meet only in `Download/BACKUP XPENC` — Connector reads
/// the backups XPENC writes there, and drops the one it pulls from another
/// phone beside them under this name, for "Import from file".
const connectorPulledFileName = 'xpenc_backup.json';

/// git's blob sha of [bytes] — the fingerprint Connector keeps of the
/// backup it pulled (GitHub's own name for that exact file content).
String gitBlobSha(List<int> bytes) {
  final header = utf8.encode('blob ${bytes.length}\u0000');
  return sha1.convert([...header, ...bytes]).toString();
}

/// The link that tells Connector which backup XPENC just imported. Connector
/// checks [bytes]' fingerprint against the file it pulled and only then
/// carries on syncing from it — a different file changes nothing there.
Uri connectorImportedLink(List<int> bytes) => Uri(
  scheme: 'conectr',
  host: 'imported',
  queryParameters: {'sha': gitBlobSha(bytes)},
);

/// Opens Connector on [connectorImportedLink] — an ordinary app-to-app
/// link, not a network call. False if no installed app takes the link
/// (Connector missing, or too old to know it).
Future<bool> tellConnectorImported(List<int> bytes) async {
  try {
    return await launchUrl(
      connectorImportedLink(bytes),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
