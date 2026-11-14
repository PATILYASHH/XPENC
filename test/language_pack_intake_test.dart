import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/l10n/language_pack.dart';
import 'package:xpenc/data/category_template_file.dart';
import 'package:xpenc/features/settings/language_pack_intake.dart';

/// "Open with XPENC" on a downloaded file (GitHub #191): a language pack is
/// recognised; XPENC's other JSON files get pointed to their own screens.
void main() {
  const pack = {
    'xpencLanguagePack': 1,
    'code': 'mr',
    'englishName': 'Marathi',
    'nativeName': 'मराठी',
    'strings': {'Save': 'जतन करा', '{0} left': '{0} शिल्लक'},
  };

  group('classifyOpenedFile', () {
    test('a language pack', () {
      final opened = classifyOpenedFile(jsonEncode(pack));
      expect(opened, isA<OpenedLanguagePack>());
      final p = (opened as OpenedLanguagePack).pack;
      expect(p.code, 'mr');
      expect(p.nativeName, 'मराठी');
      expect(p.strings['Save'], 'जतन करा');
    });

    test('a backup points to Backup & Restore', () {
      final backup = jsonEncode({
        'formatVersion': 3,
        'schemaVersion': 95,
        'exportedAt': '2026-11-14T10:00:00.000',
        'accounts': [],
      });
      final opened = classifyOpenedFile(backup);
      expect(opened, isA<OpenedOtherFile>());
      expect((opened as OpenedOtherFile).message, contains('Backup & Restore'));
    });

    test('a category template points to Categories → Templates', () {
      final template = jsonEncode({
        'format': CategoryTemplateFile.format,
        'name': 'Student',
      });
      final opened = classifyOpenedFile(template);
      expect(opened, isA<OpenedOtherFile>());
      expect((opened as OpenedOtherFile).message, contains('Categories'));
    });

    test("any other JSON — or not JSON at all — isn't a pack", () {
      for (final text in ['{"hello": 1}', 'not json', '']) {
        final opened = classifyOpenedFile(text);
        expect(opened, isA<OpenedOtherFile>(), reason: text);
        expect(
          (opened as OpenedOtherFile).message,
          "That isn't an XPENC language pack.",
        );
      }
    });

    test('a damaged pack says why', () {
      final damaged = jsonEncode({...pack, 'code': 'Marathi!'});
      final opened = classifyOpenedFile(damaged);
      expect((opened as OpenedOtherFile).message, contains('damaged'));
    });
  });

  group('readOpenedFile', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('xpenc_open_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('reads a pack and deletes the cached copy', () async {
      final f = File('${dir.path}/xpenc-language-mr.json')
        ..writeAsStringSync(jsonEncode(pack));
      final opened = await readOpenedFile(f.path);
      expect(opened, isA<OpenedLanguagePack>());
      expect(f.existsSync(), isFalse);
    });

    test('a file too big to be a pack still names a backup', () async {
      final f = File('${dir.path}/XPENCEBACKUP.json');
      final sink = f.openWrite()
        ..write(
          '{"formatVersion":3,"schemaVersion":95,'
          '"exportedAt":"2026-11-14T10:00:00.000","transactions":[',
        );
      // Past maxOpenedFileBytes, so only its start is read.
      final row = '{"note":"${'x' * 1000}"},';
      for (var i = 0; i < maxOpenedFileBytes ~/ row.length + 10; i++) {
        sink.write(row);
      }
      sink.write('{}]}');
      await sink.close();
      final opened = await readOpenedFile(f.path);
      expect((opened as OpenedOtherFile).message, contains('Backup & Restore'));
    });

    test('a missing file never throws', () async {
      final opened = await readOpenedFile('${dir.path}/gone.json');
      expect(opened, isA<OpenedOtherFile>());
    });
  });

  // The files xpenc.in/languages serves, written by tool/l10n/assemble.dart:
  // every pack must import, and the index must point at each one.
  test('every published pack decodes, and the index lists it', () {
    final index =
        jsonDecode(File('website/languages/index.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(index['format'], 'xpenc-language-index');
    final listed = <String>{};
    for (final l in (index['languages'] as List).cast<Map<String, dynamic>>()) {
      if (l['builtIn'] == true) continue;
      final file = File('website/languages/${l['file']}');
      expect(file.existsSync(), isTrue, reason: '${l['file']}');
      final p = LanguagePack.decode(file.readAsStringSync());
      expect(p.code, l['code']);
      expect(p.dropped, 0, reason: '${p.code} has strings that would break');
      // Not the exact size: a Windows checkout may turn its LFs into CRLFs.
      expect(l['bytes'], greaterThan(0));
      listed.add(file.uri.pathSegments.last);
    }
    final onDisk = Directory(
      'website/languages/packs',
    ).listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toSet();
    expect(onDisk, listed);
  });
}
