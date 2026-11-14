import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../platform/platform_features.dart';
import 'l10n.dart';
import 'language_pack.dart';

/// Where imported language packs live: one `<code>.json` each in the app's
/// own support folder — not in backups, since a pack is the phone's
/// interface, not the person's money. Not on XPENC web, which has no folder
/// of its own to keep them in.
abstract final class LanguagePackStore {
  static bool get supported => !PlatformFeatures.isWeb;

  static Future<Directory?> _dir() async {
    if (!supported) return null;
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}${Platform.pathSeparator}languages');
  }

  /// Reads every installed pack into [L10n]. A damaged file is skipped, not
  /// fatal — the language just isn't offered.
  static Future<void> loadAll() async {
    try {
      final dir = await _dir();
      if (dir == null || !await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          L10n.addPack(LanguagePack.decode(await entity.readAsString()));
        } catch (e) {
          debugPrint('Language pack ${entity.path} skipped: $e');
        }
      }
    } catch (e) {
      debugPrint('Language packs not read: $e');
    }
  }

  /// Saves [pack] (replacing one for the same language) and makes it
  /// available at once.
  static Future<void> install(LanguagePack pack) async {
    final dir = await _dir();
    if (dir == null) throw UnsupportedError('No language packs here');
    await dir.create(recursive: true);
    await File(
      '${dir.path}${Platform.pathSeparator}${pack.code}.json',
    ).writeAsString(pack.encode(), flush: true);
    L10n.addPack(pack);
  }

  static Future<void> remove(String code) async {
    final dir = await _dir();
    if (dir != null) {
      final file = File('${dir.path}${Platform.pathSeparator}$code.json');
      if (await file.exists()) await file.delete();
    }
    L10n.removePack(code);
  }
}
