// Builds the interface translations from the sources in tool/l10n/tx/
// (GitHub #191): assets/l10n/<code>.json for the languages XPENC ships, and
// website/languages/packs/xpenc-language-<code>.json — an importable
// language pack — for every other one, plus website/languages/index.json,
// which xpenc.in/languages lists them from.
//
//   dart run tool/l10n/assemble.dart
//
// A source file holds numbered lines per language, numbers indexing
// tool/l10n/catalog.frozen.json (the English list the translation was made
// from):
//
//   @hi
//   0<TAB>{0} समाप्त हो गया
//
// `\n` in a line is a line break. A line left out means "same as the
// English". Keys are written as the English text itself, so the tables keep
// working when the catalogue later grows or reorders. A translation that
// brings in a placeholder its English doesn't have is refused.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Shipped inside the app — keep in step with `appLanguages` in
/// lib/core/l10n/l10n.dart. English name, native name.
const builtInNames = {
  'en': ('English', 'English'),
  'hi': ('Hindi', 'हिन्दी'),
  'de': ('German', 'Deutsch'),
  'ja': ('Japanese', '日本語'),
  'ru': ('Russian', 'Русский'),
};
final builtIn = builtInNames.keys.where((c) => c != 'en').toSet();

/// The oldest XPENC that reads packs — shown on xpenc.in/languages.
const minAppVersion = '1.6.6';

const website = 'website/languages';

/// Everything else becomes a pack: English name, native name.
const packNames = {
  'mr': ('Marathi', 'मराठी'),
  'bn': ('Bengali', 'বাংলা'),
  'ta': ('Tamil', 'தமிழ்'),
  'te': ('Telugu', 'తెలుగు'),
  'es': ('Spanish', 'Español'),
  'fr': ('French', 'Français'),
  'it': ('Italian', 'Italiano'),
  'pt': ('Portuguese', 'Português'),
  'ar': ('Arabic', 'العربية'),
};

void main() {
  final frozen = (jsonDecode(
    File('tool/l10n/catalog.frozen.json').readAsStringSync(),
  ) as List)
      .cast<String>();
  final live = File('tool/l10n/catalog.json').existsSync()
      ? (jsonDecode(File('tool/l10n/catalog.json').readAsStringSync()) as List)
          .cast<String>()
          .toSet()
      : frozen.toSet();

  final tables = <String, Map<String, String>>{};
  // Every English string a language has a line for — a line the same as the
  // English included — for its coverage on the website.
  final seen = <String, Set<String>>{};
  final placeholder = RegExp(r'\{\d+\}');
  var problems = 0;

  final sources = Directory('tool/l10n/tx')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.txt'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in sources) {
    String? lang;
    var lineNo = 0;
    for (final line in f.readAsLinesSync()) {
      lineNo++;
      if (line.trim().isEmpty) continue;
      if (line.startsWith('@')) {
        lang = line.substring(1).trim();
        continue;
      }
      final tab = line.indexOf('\t');
      final index = tab < 0 ? null : int.tryParse(line.substring(0, tab));
      if (lang == null || index == null || index >= frozen.length) {
        print('${f.path}:$lineNo: bad line');
        problems++;
        continue;
      }
      final english = frozen[index];
      final text = line.substring(tab + 1).replaceAll(r'\n', '\n');
      final allowed = placeholder.allMatches(english).map((m) => m[0]).toSet();
      final extra = placeholder
          .allMatches(text)
          .map((m) => m[0])
          .where((p) => !allowed.contains(p));
      if (extra.isNotEmpty) {
        print('${f.path}:$lineNo [$lang] adds ${extra.join(' ')}: $text');
        problems++;
        continue;
      }
      seen.putIfAbsent(lang, () => {}).add(english);
      if (text == english) continue;
      tables.putIfAbsent(lang, () => {})[english] = text;
    }
  }

  Directory('assets/l10n').createSync(recursive: true);
  Directory('$website/packs').createSync(recursive: true);
  int coverage(String code) =>
      ((seen[code] ?? const {}).where(live.contains).length * 100 / live.length)
          .floor();
  final index = <Map<String, Object>>[
    for (final e in builtInNames.entries)
      {
        'code': e.key,
        'englishName': e.value.$1,
        'nativeName': e.value.$2,
        'builtIn': true,
        'coverage': e.key == 'en' ? 100 : coverage(e.key),
      },
  ];
  for (final e in tables.entries) {
    final sorted = Map.fromEntries(
      e.value.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    if (builtIn.contains(e.key)) {
      File('assets/l10n/${e.key}.json').writeAsStringSync(
        const JsonEncoder.withIndent(' ').convert(sorted),
      );
    } else {
      final names = packNames[e.key];
      if (names == null) {
        print('${e.key}: not built in and no pack name — skipped');
        problems++;
        continue;
      }
      // Only what the app still shows — a pack is downloaded, keep it lean.
      final strings = {
        for (final s in sorted.entries)
          if (live.contains(s.key)) s.key: s.value,
      };
      final file = 'packs/xpenc-language-${e.key}.json';
      final text = const JsonEncoder.withIndent(' ').convert({
        'xpencLanguagePack': 1,
        'code': e.key,
        'englishName': names.$1,
        'nativeName': names.$2,
        // Lets the app say a partial pack leaves the rest in English.
        'coverage': coverage(e.key),
        'strings': strings,
      });
      File('$website/$file').writeAsStringSync(text);
      index.add({
        'code': e.key,
        'englishName': names.$1,
        'nativeName': names.$2,
        'builtIn': false,
        'coverage': coverage(e.key),
        'strings': strings.length,
        'file': file,
        'bytes': utf8.encode(text).length,
      });
    }
    final covered = e.value.keys.where(live.contains).length;
    print('${e.key}${builtIn.contains(e.key) ? '' : ' (pack)'}: '
        '${e.value.length} strings '
        '($covered of ${live.length} in the live catalogue)');
  }

  // Built in first, as the app lists them; then the packs, most complete
  // first. No date in it, so an unchanged catalogue writes the same file.
  final packs = index.where((l) => l['builtIn'] == false).toList()
    ..sort((a, b) {
      final c = (b['coverage'] as int).compareTo(a['coverage'] as int);
      return c != 0
          ? c
          : (a['englishName'] as String).compareTo(b['englishName'] as String);
    });
  File('$website/index.json').writeAsStringSync(
    const JsonEncoder.withIndent(' ').convert({
      'format': 'xpenc-language-index',
      'version': 1,
      'minAppVersion': minAppVersion,
      'strings': live.length,
      'languages': [...index.where((l) => l['builtIn'] == true), ...packs],
    }),
  );
  print('$website/index.json: ${index.length} languages');

  if (problems > 0) {
    print('$problems problem(s)');
    exit(1);
  }
}
