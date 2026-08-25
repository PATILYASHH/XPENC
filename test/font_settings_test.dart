import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_colors.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/font_options.dart';
import 'package:xpenc/core/theme/theme_shape.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/settings/font_settings_screen.dart';

void main() {
  group('AppFontFamily', () {
    test('round-trips through its name', () {
      for (final option in AppFontFamily.values) {
        expect(AppFontFamily.fromName(option.name), option);
      }
    });

    test('an unknown or missing name falls back to system', () {
      expect(AppFontFamily.fromName(null), AppFontFamily.system);
      expect(AppFontFamily.fromName(''), AppFontFamily.system);
      expect(AppFontFamily.fromName('comic_sans'), AppFontFamily.system);
    });

    test('system carries no family override', () {
      expect(AppFontFamily.system.family, isNull);
    });
  });

  group('font persistence', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test(
      'defaults to normal size, default weight, no family override',
      () async {
        final row = await db.getSettings();
        expect(row.fontScalePercent, 100);
        expect(row.fontWeightDelta, 0);
        expect(row.fontFamily, isNull);
      },
    );

    test('writes survive a read-back', () async {
      await db.setFontScalePercent(120);
      await db.setFontWeightDelta(2);
      await db.setFontFamily(AppFontFamily.sora.name);

      final row = await db.getSettings();
      expect(row.fontScalePercent, 120);
      expect(row.fontWeightDelta, 2);
      expect(row.fontFamily, AppFontFamily.sora.name);
    });

    test('setFontScalePercent clamps to the picker range', () async {
      await db.setFontScalePercent(9999);
      expect((await db.getSettings()).fontScalePercent, 150);

      await db.setFontScalePercent(-50);
      expect((await db.getSettings()).fontScalePercent, 80);
    });

    test('setFontWeightDelta clamps to the picker range', () async {
      await db.setFontWeightDelta(99);
      expect((await db.getSettings()).fontWeightDelta, 2);

      await db.setFontWeightDelta(-99);
      expect((await db.getSettings()).fontWeightDelta, -2);
    });

    test('setFontFamily(null) clears the override back to system', () async {
      await db.setFontFamily(AppFontFamily.manrope.name);
      await db.setFontFamily(null);
      expect((await db.getSettings()).fontFamily, isNull);
    });

    test('providers reflect the stored row', () async {
      await db.setFontScalePercent(130);
      await db.setFontWeightDelta(-1);
      await db.setFontFamily(AppFontFamily.serif.name);

      final container = ProviderContainer(
        overrides: [dbProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      // Before the stream emits, defaults must still be usable.
      expect(container.read(fontScalePercentProvider), 100);
      expect(container.read(fontWeightDeltaProvider), 0);
      expect(container.read(fontFamilyProvider), AppFontFamily.system);

      await container.read(settingsProvider.future);
      expect(container.read(fontScalePercentProvider), 130);
      expect(container.read(fontWeightDeltaProvider), -1);
      expect(container.read(fontFamilyProvider), AppFontFamily.serif);
    });
  });

  group('AppTheme font handling', () {
    test('weight delta shifts every role without erasing hierarchy', () {
      final plain = AppTheme.of(AppPalettes.monoLight, ThemeShape.classic);
      final bolder = AppTheme.of(
        AppPalettes.monoLight,
        ThemeShape.classic,
        fontWeightDelta: 2,
      );

      final plainBody = plain.textTheme.bodyMedium!.fontWeight!;
      final bolderBody = bolder.textTheme.bodyMedium!.fontWeight!;
      expect(bolderBody.value, greaterThan(plainBody.value));

      // Headline still reads heavier than body after the shift, same as
      // before it — a delta must not flatten the type scale.
      expect(
        bolder.textTheme.headlineSmall!.fontWeight!.value,
        greaterThanOrEqualTo(bolderBody.value),
      );
    });

    test('an explicit font family overrides the theme shape entirely', () {
      final theme = AppTheme.of(
        AppPalettes.monoLight,
        ThemeShape.bold,
        fontFamily: AppFontFamily.serif,
      );

      expect(theme.textTheme.headlineSmall!.fontFamily, 'serif');
      expect(theme.textTheme.bodyMedium!.fontFamily, 'serif');
    });

    test('AppFontFamily.system leaves the theme shape untouched', () {
      final withShapeOnly = AppTheme.of(AppPalettes.monoLight, ThemeShape.bold);
      final explicitSystem = AppTheme.of(
        AppPalettes.monoLight,
        ThemeShape.bold,
        fontFamily: AppFontFamily.system,
      );

      expect(
        explicitSystem.textTheme.headlineSmall!.fontFamily,
        withShapeOnly.textTheme.headlineSmall!.fontFamily,
      );
      expect(
        explicitSystem.textTheme.bodyMedium!.fontFamily,
        withShapeOnly.textTheme.bodyMedium!.fontFamily,
      );
    });
  });

  group('FontSettingsScreen', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: const MaterialApp(theme: null, home: FontSettingsScreen()),
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

    testWidgets('renders every font family option without overflow', (
      tester,
    ) async {
      await pump(tester);
      expect(tester.takeException(), isNull);

      for (final option in AppFontFamily.values) {
        expect(find.text(option.label), findsOneWidget);
      }
      await unmount(tester);
    });

    testWidgets('picking a family writes it to the database', (tester) async {
      await pump(tester);

      final tile = find.text(AppFontFamily.monospace.label);
      await tester.ensureVisible(tile);
      await tester.pump();
      await tester.tap(tile);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );

      late String? stored;
      await tester.runAsync(() async {
        stored = (await db.getSettings()).fontFamily;
      });
      expect(stored, AppFontFamily.monospace.name);

      await tester.pump();
      await unmount(tester);
    });
  });
}
