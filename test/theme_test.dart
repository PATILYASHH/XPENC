import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/settings/settings_screen.dart';
import 'package:xpenc/features/settings/theme_picker_sheet.dart';
import 'package:xpenc/features/transactions/transactions_screen.dart';

void main() {
  group('ThemePreset', () {
    test('round-trips through its name', () {
      for (final preset in ThemePreset.values) {
        expect(ThemePreset.fromName(preset.name), preset);
      }
    });

    test('an unknown or missing name falls back instead of throwing', () {
      expect(ThemePreset.fromName(null), ThemePreset.fallback);
      expect(ThemePreset.fromName(''), ThemePreset.fallback);
      expect(ThemePreset.fromName('neon_disco'), ThemePreset.fallback);
    });

    test('a preset that forces a brightness ignores the platform', () {
      expect(
        ThemePreset.dark.resolve(Brightness.light),
        ThemePreset.dark.resolve(Brightness.dark),
      );
      expect(
        ThemePreset.midnight.resolve(Brightness.light).brightness,
        Brightness.dark,
      );
    });

    test('system and colourful follow the platform', () {
      for (final preset in [ThemePreset.system, ThemePreset.colourful]) {
        expect(preset.resolve(Brightness.light).brightness, Brightness.light);
        expect(preset.resolve(Brightness.dark).brightness, Brightness.dark);
      }
    });

    test('every palette keeps cards distinct from the page and the track '
        'distinct from cards', () {
      for (final preset in ThemePreset.values) {
        for (final p in [preset.lightPalette, preset.darkPalette]) {
          expect(p.surfaceHigh, isNot(p.bg), reason: '${preset.name}: card == page');
          expect(p.track, isNot(p.surfaceHigh), reason: '${preset.name}: track == card');
        }
      }
    });

    test('money colours are identical in every theme', () {
      final schemes =
          ThemePreset.values.map((p) => AppTheme.of(p.lightPalette).colorScheme);
      // `error` is the one money colour the ColorScheme carries. If a palette
      // ever repainted it, red would stop meaning "expense".
      expect(schemes.map((s) => s.error).toSet(), hasLength(1));
    });
  });

  group('theme persistence', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('defaults to system, and survives a write', () async {
      expect((await db.getSettings()).themeName, 'system');

      await db.setThemeName(ThemePreset.colourful.name);
      expect((await db.getSettings()).themeName, 'colourful');
      expect(
        ThemePreset.fromName((await db.getSettings()).themeName),
        ThemePreset.colourful,
      );
    });

    test('a pre-v4 backup, whose settings row predates the column, restores '
        'to the default theme instead of failing', () async {
      final dump = await db.exportAll();
      final settingsRows = (dump['settings'] as List).cast<Map>();
      expect(settingsRows, hasLength(1));

      // Exactly what a v3 export looks like: no `themeName` key at all.
      settingsRows.first.remove('themeName');
      expect(settingsRows.first.containsKey('themeName'), isFalse);

      await db.importAll(dump);
      expect((await db.getSettings()).themeName, 'system');
    });

    test('restoring a backup keeps this device\'s theme, not the one baked '
        'into the file', () async {
      // The backup is taken on a "Midnight" phone…
      await db.setThemeName(ThemePreset.midnight.name);
      final dump = await db.exportAll();

      // …and restored onto a "Light" one. The ledger crosses over; the look
      // does not.
      await db.setThemeName(ThemePreset.light.name);
      await db.importAll(dump);

      expect((await db.getSettings()).themeName, ThemePreset.light.name);
    });

    test('restore still repairs a settings row that has no theme at all',
        () async {
      final dump = await db.exportAll();
      (dump['settings'] as List).cast<Map>().first.remove('themeName');

      await db.importAll(dump);
      expect((await db.getSettings()).themeName, 'system');
    });

    test('themePresetProvider reflects the stored row', () async {
      await db.setThemeName(ThemePreset.midnight.name);

      final container = ProviderContainer(
        overrides: [dbProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      // Before the stream emits, the provider must still hand back a usable
      // theme rather than null.
      expect(container.read(themePresetProvider), ThemePreset.fallback);

      await container.read(settingsProvider.future);
      expect(container.read(themePresetProvider), ThemePreset.midnight);
    });
  });

  group('theme UI', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> pump(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(1080, 2400); // 360 x 800 dp
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(theme: AppTheme.light, home: screen),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    testWidgets('the picker lists every preset and does not overflow',
        (tester) async {
      await pump(tester, const Scaffold(body: ThemePickerSheet()));
      expect(tester.takeException(), isNull);

      for (final preset in ThemePreset.values) {
        expect(find.text(preset.label), findsOneWidget);
      }
      await unmount(tester);
    });

    testWidgets('picking a theme writes it to the database', (tester) async {
      await pump(tester, const Scaffold(body: ThemePickerSheet()));

      await tester.tap(find.text(ThemePreset.colourful.label));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );

      late String stored;
      await tester.runAsync(() async {
        stored = (await db.getSettings()).themeName;
      });
      expect(stored, ThemePreset.colourful.name);

      await tester.pump();
      await unmount(tester);
    });

    testWidgets('settings shows the stored theme, not a hardcoded label',
        (tester) async {
      await tester.runAsync(() => db.setThemeName(ThemePreset.midnight.name));

      await pump(tester, const SettingsScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('Midnight'), findsOneWidget);
      expect(find.text('System'), findsNothing);
      await unmount(tester);
    });

    testWidgets('a transaction card survives a long name, note and amount',
        (tester) async {
      await tester.runAsync(() async {
        final cash = (await db.watchAccounts().first)
            .firstWhere((a) => a.type == AccountType.cash)
            .id;
        final cat = (await db.watchCategories(CategoryKind.expense).first)
            .firstWhere((c) => c.name == 'Entertainment')
            .id;
        await db.addTransaction(
          type: TxType.expense,
          // A crore, to push the trailing column as wide as it can go.
          amount: Money.fromRupees(12345678),
          accountId: cash,
          categoryId: cat,
          date: DateTime.now(),
          note: 'A deliberately long note about a very long evening out',
        );
      });

      await pump(tester, const TransactionsScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('Entertainment'), findsWidgets);
      await unmount(tester);
    });
  });
}
