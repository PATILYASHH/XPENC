import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/glass.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/core/widgets/app_surfaces.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/settings/general_settings_screen.dart';
import 'package:xpenc/features/settings/theme_picker_sheet.dart';
import 'package:xpenc/features/transactions/transactions_screen.dart';

void main() {
  group('ThemeChoice', () {
    test('round-trips through its storage name, every style, mode and '
        'background', () {
      for (final style in ThemeStyle.values) {
        for (final mode in ThemeMode.values) {
          for (final backdrop in GlassBackdrop.values) {
            final choice = ThemeChoice(style, mode, backdrop);
            expect(ThemeChoice.parse(choice.storageName), choice);
          }
        }
      }
      // The default background adds nothing, so older values still read.
      expect(const ThemeChoice(ThemeStyle.glass).storageName, 'glass');
      expect(
        const ThemeChoice(
          ThemeStyle.glass,
          ThemeMode.system,
          GlassBackdrop.ocean,
        ).storageName,
        'glass/ocean',
      );
    });

    test('an unknown background keeps the style and falls back to Aurora', () {
      expect(
        ThemeChoice.parse('glass/lava'),
        const ThemeChoice(ThemeStyle.glass),
      );
      expect(ThemeChoice.parse('glass/a/b'), ThemeChoice.fallback);
    });

    test('an unknown or missing name falls back instead of throwing', () {
      for (final raw in [null, '', 'neon_disco', 'classic:dark:x', ':dark']) {
        expect(ThemeChoice.parse(raw), ThemeChoice.fallback, reason: '$raw');
      }
      // An unknown mode keeps the style rather than discarding both.
      expect(
        ThemeChoice.parse('noir:sepia'),
        const ThemeChoice(ThemeStyle.noir),
      );
    });

    test('the default is Classic following the device', () {
      expect(ThemeChoice.fallback.style, ThemeStyle.classic);
      expect(ThemeChoice.fallback.mode, ThemeMode.system);
    });

    test('presets from before styles map onto Classic, keeping a forced '
        'brightness, and Bold becomes Noir', () {
      const expected = {
        'system': ThemeChoice(ThemeStyle.classic),
        'mono': ThemeChoice(ThemeStyle.classic),
        'light': ThemeChoice(ThemeStyle.classic, ThemeMode.light),
        'dark': ThemeChoice(ThemeStyle.classic, ThemeMode.dark),
        'colourful': ThemeChoice(ThemeStyle.classic),
        'cove': ThemeChoice(ThemeStyle.classic),
        'midnight': ThemeChoice(ThemeStyle.classic, ThemeMode.dark),
        'bold': ThemeChoice(ThemeStyle.noir, ThemeMode.dark),
      };
      expected.forEach((raw, choice) {
        expect(ThemeChoice.parse(raw), choice, reason: raw);
      });
    });

    test('Glass is black-only: always dark whatever background or mode is '
        'stored', () {
      const glass = ThemeChoice(ThemeStyle.glass, ThemeMode.light);
      expect(ThemeStyle.glass.supportsModes, isFalse);
      expect(ThemeChoice.glassBackdrop, GlassBackdrop.black);
      for (final b in GlassBackdrop.values) {
        final c = glass.withBackdrop(b);
        expect(c.effectiveMode, ThemeMode.dark, reason: b.name);
        expect(c.resolve(Brightness.light).brightness, Brightness.dark);
      }
      // …but the mode survives a trip through Glass.
      expect(
        glass.withStyle(ThemeStyle.classic).effectiveMode,
        ThemeMode.light,
      );
    });

    test('a dark background builds a dark Glass theme that paints that '
        'background', () {
      final t = AppTheme.of(
        GlassBackdrop.ocean.palette,
        ThemeStyle.glass.shape,
        backdrop: GlassBackdrop.ocean,
      );
      expect(t.brightness, Brightness.dark);
      expect(t.extension<AppSurface>()!.backdrop, GlassBackdrop.ocean);
      expect(t.extension<AppSurface>()!.tone.isDark, isTrue);
      expect(t.colorScheme.onSurface.computeLuminance(), greaterThan(0.8));
    });

    test('Classic and Noir offer both brightnesses', () {
      for (final style in [ThemeStyle.classic, ThemeStyle.noir]) {
        final c = ThemeChoice(style);
        expect(c.resolve(Brightness.light).brightness, Brightness.light);
        expect(c.resolve(Brightness.dark).brightness, Brightness.dark);
        expect(
          ThemeChoice(style, ThemeMode.dark).resolve(Brightness.light),
          style.darkPalette,
        );
      }
    });

    test('every palette keeps cards distinct from the page and the track '
        'distinct from cards', () {
      for (final style in ThemeStyle.values) {
        for (final p in [style.lightPalette, style.darkPalette]) {
          expect(
            p.surfaceHigh,
            isNot(p.bg),
            reason: '${style.name}: card == page',
          );
          expect(
            p.track,
            isNot(p.surfaceHigh),
            reason: '${style.name}: track == card',
          );
        }
      }
    });

    test('money colours are identical in every theme', () {
      final schemes = [
        for (final s in ThemeStyle.values) ...[
          AppTheme.of(s.lightPalette, s.shape).colorScheme,
          AppTheme.of(s.darkPalette, s.shape).colorScheme,
        ],
      ];
      // `error` is the one money colour the ColorScheme carries. If a palette
      // ever repainted it, red would stop meaning "expense".
      expect(schemes.map((s) => s.error).toSet(), hasLength(1));
    });

    test('Glass pages are transparent over a gradient backdrop; solid '
        'styles keep an opaque page and no backdrop', () {
      final glass = AppTheme.of(
        ThemeStyle.glass.lightPalette,
        ThemeStyle.glass.shape,
      );
      expect(glass.scaffoldBackgroundColor, Colors.transparent);
      expect(glass.extension<AppSurface>()!.backdrop, isNotNull);
      expect(glass.cardTheme.color!.a, lessThan(1));
      // Sheets and dialogs open over a blurred page, so they stay translucent…
      expect(glass.bottomSheetTheme.backgroundColor!.a, lessThan(1));
      // …but menus and pickers float over content with no blur behind them,
      // so they must stay near-opaque or text lands on text.
      expect(glass.canvasColor.a, greaterThan(0.9));
      expect(glass.colorScheme.surfaceContainerHigh.a, greaterThan(0.9));
      expect(glass.datePickerTheme.backgroundColor!.a, greaterThan(0.9));

      for (final s in [ThemeStyle.classic, ThemeStyle.noir]) {
        final t = AppTheme.of(s.lightPalette, s.shape);
        expect(t.scaffoldBackgroundColor.a, 1, reason: s.name);
        expect(t.extension<AppSurface>()!.backdrop, isNull, reason: s.name);
      }
    });

    test('Noir draws heavier outlines and heavier text than Classic', () {
      final classic = AppTheme.of(
        ThemeStyle.classic.lightPalette,
        ThemeStyle.classic.shape,
      );
      final noir = AppTheme.of(
        ThemeStyle.noir.lightPalette,
        ThemeStyle.noir.shape,
      );
      final classicSide =
          (classic.cardTheme.shape as RoundedRectangleBorder).side;
      final noirSide = (noir.cardTheme.shape as RoundedRectangleBorder).side;
      expect(noirSide.width, greaterThan(classicSide.width));
      expect(
        noir.textTheme.bodyMedium!.fontWeight!.value,
        greaterThan(classic.textTheme.bodyMedium!.fontWeight!.value),
      );
    });
  });

  group('theme persistence', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('defaults to Classic, and survives a write', () async {
      expect(
        ThemeChoice.parse((await db.getSettings()).themeName),
        ThemeChoice.fallback,
      );

      const noirDark = ThemeChoice(ThemeStyle.noir, ThemeMode.dark);
      await db.setThemeName(noirDark.storageName);
      expect((await db.getSettings()).themeName, 'noir:dark');
      expect(ThemeChoice.parse((await db.getSettings()).themeName), noirDark);
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
      // The backup is taken on a Glass phone…
      await db.setThemeName(ThemeStyle.glass.name);
      final dump = await db.exportAll();

      // …and restored onto a light Classic one. The ledger crosses over; the
      // look does not.
      await db.setThemeName('classic:light');
      await db.importAll(dump);

      expect((await db.getSettings()).themeName, 'classic:light');
    });

    test(
      'restore still repairs a settings row that has no theme at all',
      () async {
        final dump = await db.exportAll();
        (dump['settings'] as List).cast<Map>().first.remove('themeName');

        await db.importAll(dump);
        expect((await db.getSettings()).themeName, 'system');
      },
    );

    test('themeChoiceProvider reflects the stored row', () async {
      await db.setThemeName('noir:light');

      final container = ProviderContainer(
        overrides: [dbProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      // Before the stream emits, the provider must still hand back a usable
      // theme rather than null.
      expect(container.read(themeChoiceProvider), ThemeChoice.fallback);

      await container.read(settingsProvider.future);
      expect(
        container.read(themeChoiceProvider),
        const ThemeChoice(ThemeStyle.noir, ThemeMode.light),
      );
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

    Future<String> stored(WidgetTester tester) async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      late String name;
      await tester.runAsync(() async {
        name = (await db.getSettings()).themeName;
      });
      await tester.pump();
      return name;
    }

    testWidgets('the picker lists every style and the mode choice, and does '
        'not overflow', (tester) async {
      await pump(tester, const Scaffold(body: ThemePickerSheet()));
      expect(tester.takeException(), isNull);

      for (final style in ThemeStyle.values) {
        expect(find.text(style.label), findsOneWidget);
      }
      expect(find.text('Dark'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('picking a style writes it to the database', (tester) async {
      await pump(tester, const Scaffold(body: ThemePickerSheet()));

      await tester.tap(find.text(ThemeStyle.glass.label));
      expect(await stored(tester), 'glass');
      await unmount(tester);
    });

    testWidgets('picking a mode keeps the style', (tester) async {
      await tester.runAsync(() => db.setThemeName('noir'));
      await pump(tester, const Scaffold(body: ThemePickerSheet()));

      await tester.tap(find.text('Dark'));
      expect(await stored(tester), 'noir:dark');
      await unmount(tester);
    });

    testWidgets('Glass has no mode or background choice, and picking it turns '
        'tab-bar labels off', (tester) async {
      await tester.runAsync(() => db.setShowBottomNavLabels(true));
      await pump(tester, const Scaffold(body: ThemePickerSheet()));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(ThemeStyle.glass.label));
      expect(await stored(tester), 'glass');
      late bool labels;
      await tester.runAsync(() async {
        labels = (await db.getSettings()).showBottomNavLabels;
      });
      expect(labels, isFalse);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Dark'), findsNothing);
      expect(find.text('Ocean'), findsNothing);
      expect(find.textContaining('Glass sits on black'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('settings shows the stored theme, not a hardcoded label', (
      tester,
    ) async {
      await tester.runAsync(() => db.setThemeName('noir:dark'));

      await pump(tester, const GeneralSettingsScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('Noir'), findsOneWidget);
      expect(find.text('Classic'), findsNothing);
      await unmount(tester);
    });

    testWidgets('a transaction card survives a long name, note and amount', (
      tester,
    ) async {
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

    testWidgets('AppCard is a plain Card outside Glass and a squircle glass '
        'pane inside it', (tester) async {
      Future<void> render(ThemeStyle style) => tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.of(style.lightPalette, style.shape),
          home: const Scaffold(body: AppCard(child: Text('pane'))),
        ),
      );

      await render(ThemeStyle.classic);
      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);

      await render(ThemeStyle.glass);
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsNothing);
      expect(find.byType(GlassPane), findsOneWidget);
      expect(find.byType(ClipRSuperellipse), findsOneWidget);
      // Cards frost the wallpaper without a blur pass — the wallpaper is
      // already soft, and a blur per card would cost frames on scroll.
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('under Glass a leading row icon sits on a glossy tile, in '
        'its own colour or a palette colour for a muted one', (tester) async {
      Future<void> render(ThemeStyle style) => tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.of(style.lightPalette, style.shape),
          home: const Scaffold(
            body: Column(
              children: [
                AppListTile(
                  leading: AppIcon(Icons.delete_outline, color: Colors.red),
                  title: Text('Delete'),
                ),
                AppListTile(
                  leading: AppIcon(Icons.tune_rounded, color: Colors.grey),
                  title: Text('General'),
                ),
              ],
            ),
          ),
        ),
      );

      await render(ThemeStyle.classic);
      expect(find.byType(GlassIconTile), findsNothing);
      expect(find.byType(ListTile), findsNWidgets(2));

      await render(ThemeStyle.glass);
      await tester.pumpAndSettle();
      final tiles = tester
          .widgetList<GlassIconTile>(find.byType(GlassIconTile))
          .toList();
      expect(tiles, hasLength(2));
      expect(tiles.first.color, Colors.red);
      expect(tiles.last.color, isNot(Colors.grey));
      expect(GlassIconTile.palette, contains(tiles.last.color));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a Glass sheet floats as Liquid Glass and a dialog opens over a '
        'blurred page', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.of(
            ThemeStyle.glass.lightPalette,
            ThemeStyle.glass.shape,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => showAppSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => const Text('sheet body'),
                    ),
                    child: const Text('open sheet'),
                  ),
                  TextButton(
                    onPressed: () => showAppDialog<void>(
                      context: context,
                      builder: (_) => const AlertDialog(content: Text('hi')),
                    ),
                    child: const Text('open dialog'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
      expect(find.text('sheet body'), findsOneWidget);
      // The sheet is a floating pane of Liquid Glass, drawing its own grabber.
      expect(find.byType(LiquidGlass), findsOneWidget);
      Navigator.of(tester.element(find.text('sheet body'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('open dialog'));
      await tester.pumpAndSettle();
      expect(find.text('hi'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a Glass page renders its gradient backdrop', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.of(
            ThemeStyle.glass.lightPalette,
            ThemeStyle.glass.shape,
          ),
          home: const Scaffold(body: Card(child: Text('pane'))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PageBackdrop), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
