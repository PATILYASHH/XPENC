import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'language_pack.dart';

// ─────────────────────────────────────────────────────────────────────────────
// XPENC's interface languages (GitHub #191, #202).
//
// The English text *is* the key: `tr('Add funds')` looks the sentence up in
// the current language's table (`assets/l10n/<code>.json`, English → that
// language) and falls back to the English itself when there's no entry — so
// an untranslated string still reads fine, and English needs no table at
// all. Text that changes at run time keeps its English shape with numbered
// placeholders: `tr('Notify me {0} days before', [days])`.
//
// Translations ship inside the app — nothing is fetched, nothing leaves the
// phone. `tool/l10n/` holds the catalogue and the scripts that keep the
// tables in step with the code.
// ─────────────────────────────────────────────────────────────────────────────

/// One language XPENC's interface can be shown in.
@immutable
class AppLanguage {
  const AppLanguage(this.code, this.englishName, this.nativeName);

  /// ISO 639-1, e.g. `hi`. Also the asset file's name.
  final String code;

  /// "Hindi" — how an English reader finds it in the list.
  final String englishName;

  /// "हिन्दी" — how a native reader finds it.
  final String nativeName;
}

/// The interface languages XPENC ships, English first. Any other language
/// comes as an imported pack (see `LanguagePack`) — a right-to-left one
/// (Arabic, Urdu, …) mirrors the layout, see [L10n.textDirection].
const appLanguages = <AppLanguage>[
  AppLanguage('en', 'English', 'English'),
  AppLanguage('hi', 'Hindi', 'हिन्दी'),
  AppLanguage('de', 'German', 'Deutsch'),
  AppLanguage('ja', 'Japanese', '日本語'),
  AppLanguage('ru', 'Russian', 'Русский'),
];

/// The [AppLanguage] for [code] — built in or imported as a pack — or null
/// when XPENC doesn't have it.
AppLanguage? appLanguageFor(String? code) {
  for (final l in L10n.languages) {
    if (l.code == code) return l;
  }
  return null;
}

/// The loaded interface language. A plain static, like `MoneyFormat`, so
/// `tr` works anywhere — a widget, a notification, an error message —
/// without a `BuildContext`.
abstract final class L10n {
  static String _code = 'en';
  static Map<String, String> _table = const {};
  static final _packs = <String, LanguagePack>{};

  /// Every language that can be picked: the built-in ones, then any
  /// imported as a pack that XPENC doesn't ship.
  static List<AppLanguage> get languages => [
    ...appLanguages,
    for (final p in _packs.values)
      if (!appLanguages.any((l) => l.code == p.code)) p.language,
  ];

  /// The imported pack for [code], if there is one.
  static LanguagePack? packFor(String code) => _packs[code];

  /// Whether XPENC ships [code] itself (so removing its pack keeps it).
  static bool isBuiltIn(String code) => appLanguages.any((l) => l.code == code);

  /// Makes an imported pack available — see `LanguagePackStore`.
  static void addPack(LanguagePack pack) => _packs[pack.code] = pack;

  static void removePack(String code) => _packs.remove(code);

  /// The language currently shown, e.g. `hi`.
  static String get code => _code;

  /// Languages written right to left — the whole layout mirrors for them.
  static const _rtl = {'ar', 'fa', 'he', 'ur', 'ps', 'sd', 'ckb', 'yi'};

  /// Which way [code] (default: the current language) reads.
  static TextDirection textDirection([String? code]) =>
      _rtl.contains(code ?? _code) ? TextDirection.rtl : TextDirection.ltr;

  /// The phone's own language when XPENC has it, else English — what
  /// "Phone's language" in Settings resolves to.
  static String get systemCode {
    for (final locale in PlatformDispatcher.instance.locales) {
      final match = appLanguageFor(locale.languageCode);
      if (match != null) return match.code;
    }
    return 'en';
  }

  /// [saved] is `Settings.languageCode`: a language picked by hand, or null
  /// to follow the phone.
  static String resolve(String? saved) =>
      appLanguageFor(saved)?.code ?? systemCode;

  /// Switches to [code], reading its table from the app's assets. Falls back
  /// to English if the table can't be read, so the interface never ends up
  /// blank. Dates follow too: month and weekday names come out in [code],
  /// written with the usual 0-9 digits so they sit right beside amounts.
  /// An imported pack's strings sit over the built-in table, so a pack can
  /// fix a few words without repeating the rest.
  static Future<void> load(String code) async {
    final language = appLanguageFor(code) ?? appLanguages.first;
    var table = <String, String>{};
    if (language.code != 'en' && isBuiltIn(language.code)) {
      try {
        final raw = await rootBundle.loadString(
          'assets/l10n/${language.code}.json',
        );
        table = (jsonDecode(raw) as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, v as String),
        );
      } catch (e) {
        debugPrint('L10n: no table for ${language.code} ($e)');
      }
    }
    final pack = _packs[language.code];
    if (pack != null) table.addAll(pack.strings);
    // Month and weekday names, where intl knows the language; an imported
    // one it doesn't know keeps them in English.
    await initializeDateFormatting();
    final dates = DateFormat.localeExists(language.code) ? language.code : 'en';
    DateFormat.useNativeDigitsByDefaultFor(dates, false);
    Intl.defaultLocale = dates;
    _table = table;
    _code = language.code;
  }

  /// Installs [table] directly — for tests.
  @visibleForTesting
  static void debugUse(String code, Map<String, String> table) {
    _code = code;
    _table = table;
  }

  static String _lookup(String english) => _table[english] ?? english;
}

final _placeholder = RegExp(r'\{(\d+)\}');

/// [english] in the current interface language, with `{0}`, `{1}`, …
/// replaced by [args] in order. A translation may reorder the placeholders
/// or leave one out (an English plural "s", say) — it never adds one.
String tr(String english, [List<Object?> args = const []]) {
  final text = L10n._lookup(english);
  if (args.isEmpty) return text;
  return text.replaceAllMapped(_placeholder, (m) {
    final i = int.parse(m[1]!);
    return i < args.length ? '${args[i]}' : m[0]!;
  });
}

/// "1 entry" or "3 entries" in the interface language. [one] and [many]
/// are English keys like any other; [many] holds the count as `{0}`. A
/// language whose plurals don't follow one/many still gets a whole phrase
/// to translate, never a bare English noun.
String plural(int count, String one, String many) =>
    count == 1 ? tr(one) : tr(many, [count]);

/// Tells [Tr] widgets — and anything else that asks — that the interface
/// language changed, so they redraw in the new one.
class L10nScope extends InheritedWidget {
  const L10nScope({required this.code, required super.child, super.key});

  final String code;

  /// Rebuilds the caller whenever the language changes.
  static void watch(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<L10nScope>();

  @override
  bool updateShouldNotify(L10nScope oldWidget) => oldWidget.code != code;
}

/// A [Text] whose English [data] is shown in the interface language. Takes
/// the same options as [Text], and stays `const`-friendly, so a fixed label
/// can be written `const Tr('Save')`. A [key] lands on the inner [Text], so
/// `find.byKey` still finds the [Text] itself.
class Tr extends StatelessWidget {
  // The key goes to the inner Text (see above), not to this wrapper.
  // ignore: use_key_in_widget_constructors
  const Tr(
    this.data, {
    Key? key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : _textKey = key;

  final String data;
  final Key? _textKey;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    L10nScope.watch(context);
    return Text(
      tr(data),
      key: _textKey,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null ? null : tr(semanticsLabel!),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
