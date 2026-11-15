import 'dart:convert';

import 'l10n.dart';

/// A language shared as a file (GitHub #191): a translation XPENC doesn't
/// ship, or a newer one of a language it does — fixed wording without an
/// app update. Imported from Settings → Language; packs are published on
/// xpenc.in. Plain JSON, so anyone can make or fix one in a text editor:
///
/// ```json
/// {
///   "xpencLanguagePack": 1,
///   "code": "gu",
///   "englishName": "Gujarati",
///   "nativeName": "ગુજરાતી",
///   "strings": { "Save": "સાચવો", "{0} of {1}": "{1} માંથી {0}" }
/// }
/// ```
///
/// Each key is the app's English text; a string a pack leaves out shows the
/// built-in translation (if any), else the English.
class LanguagePack {
  LanguagePack({
    required this.code,
    required this.englishName,
    required this.nativeName,
    required this.strings,
    this.dropped = 0,
    this.coverage,
  });

  static const formatVersion = 1;

  /// The most strings a pack may carry — far above the app's own count, low
  /// enough that a wrong file can't eat memory.
  static const maxStrings = 20000;

  final String code;
  final String englishName;
  final String nativeName;
  final Map<String, String> strings;

  /// Entries [decode] left out because they'd break the text they replace
  /// (a placeholder the English doesn't have).
  final int dropped;

  /// How much of the app the pack translates, 0–100, when its maker said
  /// (xpenc.in packs do) — so a partial pack can say the rest stays English.
  final int? coverage;

  AppLanguage get language => AppLanguage(code, englishName, nativeName);

  static final _code = RegExp(r'^[a-z]{2,3}$');
  static final _placeholder = RegExp(r'\{\d+\}');

  /// Reads a pack, or throws a [FormatException] whose message can be shown
  /// as is.
  static LanguagePack decode(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw FormatException(tr("That isn't an XPENC language pack."));
    }
    if (json is! Map || json['xpencLanguagePack'] is! int) {
      throw FormatException(tr("That isn't an XPENC language pack."));
    }
    if ((json['xpencLanguagePack'] as int) > formatVersion) {
      throw FormatException(
        tr('This pack needs a newer XPENC. Update the app, then try again.'),
      );
    }
    final code = json['code'];
    final englishName = json['englishName'];
    final nativeName = json['nativeName'];
    final strings = json['strings'];
    if (code is! String ||
        !_code.hasMatch(code) ||
        code == 'en' ||
        englishName is! String ||
        nativeName is! String ||
        englishName.trim().isEmpty ||
        nativeName.trim().isEmpty ||
        englishName.length > 40 ||
        nativeName.length > 40 ||
        strings is! Map) {
      throw FormatException(tr('That language pack is damaged.'));
    }
    if (strings.length > maxStrings) {
      throw FormatException(tr('That language pack is too large.'));
    }
    final out = <String, String>{};
    var dropped = 0;
    strings.forEach((k, v) {
      if (k is! String || v is! String || v.isEmpty) {
        dropped++;
        return;
      }
      final allowed = _placeholder.allMatches(k).map((m) => m[0]).toSet();
      final adds = _placeholder
          .allMatches(v)
          .any((m) => !allowed.contains(m[0]));
      if (adds) {
        dropped++;
        return;
      }
      out[k] = v;
    });
    if (out.isEmpty) {
      throw FormatException(tr('That language pack has no translations.'));
    }
    final coverage = json['coverage'];
    return LanguagePack(
      code: code,
      englishName: englishName.trim(),
      nativeName: nativeName.trim(),
      strings: out,
      dropped: dropped,
      coverage: coverage is int && coverage >= 0 && coverage <= 100
          ? coverage
          : null,
    );
  }

  String encode() => jsonEncode({
    'xpencLanguagePack': formatVersion,
    'code': code,
    'englishName': englishName,
    'nativeName': nativeName,
    if (coverage != null) 'coverage': coverage,
    'strings': strings,
  });
}
