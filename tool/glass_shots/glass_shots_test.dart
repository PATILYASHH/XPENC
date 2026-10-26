// Renders Glass screens to PNGs for a visual check, with the real fonts and
// the demo ledger:
//
//   SHOTS_OUT=<dir> flutter test tool/glass_shots/glass_shots_test.dart --update-goldens
//
// Lives outside test/ so CI's `flutter test` never runs it. No lens shader
// under flutter_test, so controls show their blur-only fallback.

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/core/widgets/app_surfaces.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';

import '../demo_seed/demo_ledger.dart';

Future<void> _loadFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

class _Device {
  const _Device(this.name, this.size, this.dpr, this.top, this.bottom);
  final String name;
  final Size size;
  final double dpr;
  final double top;
  final double bottom;
}

const _phone = _Device('phone', Size(390, 844), 3, 47, 34);
const _tablet = _Device('tablet', Size(834, 1194), 2, 24, 20);

void main() {
  final out = Platform.environment['SHOTS_OUT'];
  final only = Platform.environment['SHOTS_ONLY'];
  final scale = double.tryParse(Platform.environment['SHOTS_SCALE'] ?? '');

  setUpAll(_loadFonts);

  final glass = AppTheme.of(
    GlassBackdrop.black.palette,
    ThemeStyle.glass.shape,
    backdrop: GlassBackdrop.black,
  );

  Future<void> settle(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(Uri.file('$out/$name.png')),
    );
  }

  void shots(
    _Device device,
    String name,
    String location,
    Future<void> Function(WidgetTester tester)? act,
  ) {
    final id = '${device.name}_$name${scale == null ? '' : '_x$scale'}';
    testWidgets(id, (tester) async {
      if (out == null || (only != null && !id.contains(only))) {
        markTestSkipped('Set SHOTS_OUT to render.');
        return;
      }
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() async {
        await seedDemoLedger(db, theme: 'glass', now: DateTime.now());
        await db.setShowBottomNavLabels(false);
      });
      tester.view.physicalSize = device.size * device.dpr;
      tester.view.devicePixelRatio = device.dpr;
      tester.view.padding = FakeViewPadding(
        top: device.top * device.dpr,
        bottom: device.bottom * device.dpr,
      );
      if (scale != null) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
      }
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: glass,
            routerConfig: appRouter,
          ),
        ),
      );
      appRouter.go(location);
      await settle(tester);
      if (act != null) {
        await act(tester);
        await settle(tester);
      }
      await shot(tester, id);
      // The month picker's open state outlives the widget tree; fold it
      // (a tap on its scrim) so the next shot starts with the bar.
      if (name == 'month') {
        await tester.tapAt(const Offset(20, 300));
        await settle(tester);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  Future<void> scrollDown(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -320));
  }

  Future<void> openSheet(WidgetTester tester) async {
    final context = tester.element(find.byType(Scaffold).first);
    showAppSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (icon, label) in [
            (Icons.edit_outlined, 'Edit'),
            (Icons.content_copy_outlined, 'Duplicate'),
            (Icons.share_rounded, 'Share'),
            (Icons.delete_outline, 'Delete'),
          ])
            AppListTile(
              leading: AppIcon(icon),
              title: Text(label),
              onTap: () {},
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    final context = tester.element(find.byType(Scaffold).first);
    showAppDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This removes it from every report.'),
        actions: [
          TextButton(onPressed: () {}, child: const Text('Cancel')),
          FilledButton(onPressed: () {}, child: const Text('Delete')),
        ],
      ),
    );
  }

  Future<void> openMonthPicker(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Change month').first);
  }

  for (final device in [_phone, _tablet]) {
    shots(device, 'dashboard', '/dashboard', null);
    shots(device, 'dashboard_scrolled', '/dashboard', scrollDown);
    shots(device, 'transactions', '/transactions', null);
    shots(device, 'persons', '/persons', null);
    shots(device, 'more', '/more', null);
    shots(device, 'accounts', '/more/accounts', null);
    shots(device, 'accounts_scrolled', '/more/accounts', scrollDown);
    shots(device, 'settings', '/more/settings', null);
    shots(device, 'settings_scrolled', '/more/settings', scrollDown);
    shots(device, 'sheet', '/dashboard', openSheet);
    shots(device, 'dialog', '/more/accounts', openDialog);
    shots(device, 'month', '/dashboard', openMonthPicker);
  }
}
