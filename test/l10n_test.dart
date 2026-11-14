import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/l10n/l10n.dart';
import 'package:xpenc/core/l10n/language_pack.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/week_start.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/settings/general_settings_screen.dart';
import 'package:xpenc/features/settings/language_settings_screen.dart';

/// GitHub #191 / #202: the interface in the person's own language.
void main() {
  tearDown(() {
    L10n.debugUse('en', const {});
    L10n.removePack('gu');
    L10n.removePack('hi');
  });

  group('tr', () {
    test('English needs no table and fills placeholders', () {
      expect(tr('Save'), 'Save');
      expect(tr('{0} of {1}', ['3', '5']), '3 of 5');
    });

    test('looks the English up, falling back to it when missing', () {
      L10n.debugUse('hi', const {'Save': 'सहेजें'});
      expect(tr('Save'), 'सहेजें');
      expect(tr('Never translated'), 'Never translated');
    });

    test('a translation may reorder or drop placeholders', () {
      L10n.debugUse('hi', const {
        'You have spent {0} of {1}.': 'आपने {1} में से {0} ख़र्च किए हैं।',
        'Notify me {0} day{1} before': '{0} दिन पहले बताएँ',
      });
      expect(
        tr('You have spent {0} of {1}.', ['₹10', '₹50']),
        'आपने ₹50 में से ₹10 ख़र्च किए हैं।',
      );
      expect(tr('Notify me {0} day{1} before', [3, 's']), '3 दिन पहले बताएँ');
    });

    test('an argument that looks like a placeholder is left alone', () {
      expect(tr('{0} and {1}', ['{1}', 'x']), '{1} and x');
    });
  });

  group('resolve', () {
    test('a picked language wins; an unknown one follows the phone', () {
      expect(L10n.resolve('hi'), 'hi');
      expect(L10n.resolve('xx'), L10n.systemCode);
      expect(L10n.resolve(null), L10n.systemCode);
    });
  });

  group('language packs', () {
    Map<String, Object?> pack({
      Object? version = 1,
      Object? code = 'gu',
      Map<String, Object?>? strings,
    }) => {
      'xpencLanguagePack': version,
      'code': code,
      'englishName': 'Gujarati',
      'nativeName': 'ગુજરાતી',
      'strings': strings ?? {'Save': 'સાચવો'},
    };

    test('a good pack reads', () {
      final p = LanguagePack.decode(jsonEncode(pack()));
      expect(p.code, 'gu');
      expect(p.strings, {'Save': 'સાચવો'});
      expect(LanguagePack.decode(p.encode()).strings, p.strings);
    });

    test('anything else is refused with a readable reason', () {
      expect(() => LanguagePack.decode('not json'), throwsFormatException);
      expect(() => LanguagePack.decode('{"a":1}'), throwsFormatException);
      expect(
        () => LanguagePack.decode(jsonEncode(pack(version: 99))),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('newer XPENC'),
        )),
      );
      expect(
        () => LanguagePack.decode(jsonEncode(pack(code: 'en'))),
        throwsFormatException,
      );
      expect(
        () => LanguagePack.decode(jsonEncode(pack(code: '../x'))),
        throwsFormatException,
      );
      expect(
        () => LanguagePack.decode(jsonEncode(pack(strings: {}))),
        throwsFormatException,
      );
    });

    test('an entry that would add a placeholder is dropped, not trusted', () {
      final p = LanguagePack.decode(jsonEncode(pack(strings: {
        'Save': 'સાચવો',
        'Pay {0}': '{0} {1} ચૂકવો',
        'Delete': 7,
      })));
      expect(p.strings.keys, ['Save']);
      expect(p.dropped, 2);
    });

    test('an imported language is offered and loads over English', () async {
      L10n.addPack(LanguagePack.decode(jsonEncode(pack())));
      expect(appLanguageFor('gu')?.nativeName, 'ગુજરાતી');
      expect(L10n.languages.map((l) => l.code), contains('gu'));
      await L10n.load('gu');
      expect(L10n.code, 'gu');
      expect(tr('Save'), 'સાચવો');
      expect(tr('Delete'), 'Delete');
    });

    test('a pack for a built-in language overrides just its own words', () async {
      L10n.addPack(
        LanguagePack.decode(jsonEncode({
          ...pack(code: 'hi'),
          'strings': {'Save': 'सेव करें'},
        })),
      );
      await L10n.load('hi');
      expect(tr('Save'), 'सेव करें');
      // Everything else still comes from the built-in Hindi table.
      expect(tr('Cancel'), isNot('Cancel'));
      expect(L10n.languages.where((l) => l.code == 'hi'), hasLength(1));
    });
  });

  group('built-in tables', () {
    final catalog = (jsonDecode(
      File('tool/l10n/catalog.json').readAsStringSync(),
    ) as List).cast<String>().toSet();
    final placeholder = RegExp(r'\{\d+\}');

    for (final language in appLanguages.where((l) => l.code != 'en')) {
      test('${language.code}: loads, and never adds a placeholder', () async {
        final file = File('assets/l10n/${language.code}.json');
        expect(file.existsSync(), isTrue, reason: 'no table shipped');
        final table = (jsonDecode(file.readAsStringSync()) as Map)
            .cast<String, String>();
        for (final e in table.entries) {
          final allowed = placeholder.allMatches(e.key).map((m) => m[0]);
          for (final m in placeholder.allMatches(e.value)) {
            expect(allowed, contains(m[0]), reason: '"${e.key}" -> "${e.value}"');
          }
        }
        expect(table.keys.where(catalog.contains), isNotEmpty);
        await L10n.load(language.code);
        expect(L10n.code, language.code);
      });
    }
  });

  group('widgets', () {
    testWidgets('Tr redraws when the language changes', (tester) async {
      Widget app(String code) => MaterialApp(
        home: L10nScope(code: code, child: const Scaffold(body: Tr('Save'))),
      );
      await tester.pumpWidget(app('en'));
      expect(find.text('Save'), findsOneWidget);

      L10n.debugUse('hi', const {'Save': 'सहेजें'});
      await tester.pumpWidget(app('hi'));
      expect(find.text('सहेजें'), findsOneWidget);
    });

    testWidgets('a key on Tr lands on the Text itself', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Tr('Save', key: Key('k'))),
      );
      expect(tester.widget<Text>(find.byKey(const Key('k'))).data, 'Save');
    });

    test('date picker strings and month names follow the language', () async {
      await L10n.load('hi');
      const loc = WeekStartMaterialLocalizations(1, language: 'hi');
      expect(loc.okButtonLabel, isNot('OK'));
      expect(loc.formatMonthYear(DateTime(2026, 11)), contains('2026'));
      expect(loc.formatMonthYear(DateTime(2026, 11)), isNot(contains('November')));
      expect(loc.narrowWeekdays, hasLength(7));
    });

    testWidgets('Settings → Language saves the pick, or follows the phone', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const LanguageSettingsScreen(),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();

      // Every language, named in its own script.
      for (final l in appLanguages) {
        expect(find.byKey(Key('language-${l.code}')), findsOneWidget);
      }
      expect(find.text('日本語'), findsOneWidget);
      // More languages → xpenc.in/languages, and importing a file by hand.
      expect(find.byKey(const Key('language-more')), findsOneWidget);
      expect(find.byKey(const Key('language-import')), findsOneWidget);

      Future<SettingRow> settings() async {
        late SettingRow row;
        await tester.runAsync(() async => row = await db.watchSettings().first);
        return row;
      }

      await tester.tap(find.byKey(const Key('language-ja')));
      await tester.pump();
      expect((await settings()).languageCode, 'ja');

      await tester.tap(find.byKey(const Key('language-system')));
      await tester.pump();
      expect((await settings()).languageCode, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('Settings → General lists Language first', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const GeneralSettingsScreen(),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      final row = find.byKey(const Key('general-language'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('English')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(row).dy,
        lessThan(tester.getTopLeft(find.text('Currency')).dy),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
