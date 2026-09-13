import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/data_export/backup_screen.dart';

/// GitHub #123: the "Automatic backups" sheet forced the Days field to show
/// at least 1 even when 0 was the real, saved value — so a pure hours-only
/// interval (e.g. every 12 hours) silently turned into "1 day 12 hours"
/// every time the sheet was reopened and saved again. Days and Hours are
/// independent now; the only real rule is that the combined interval can't
/// be zero.
void main() {
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
        child: MaterialApp(theme: AppTheme.light, home: const BackupScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<void> openSheet(WidgetTester tester) async {
    // "Automatic backups" also appears as the section's own label above the
    // card — only the ListTile inside the card is the tappable row.
    await tester.tap(
      find.widgetWithText(ListTile, 'Automatic backups'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'reopening with a saved 0-day custom interval shows 0, not 1',
    (tester) async {
      await tester.runAsync(
        () => db.setAutoBackupSettings(
          enabled: true,
          frequency: AutoBackupFrequency.custom,
          customDays: 0,
          customHours: 12,
          retentionDays: 8,
        ),
      );

      await pump(tester);
      expect(tester.takeException(), isNull);
      await openSheet(tester);

      expect(
        find.widgetWithText(TextField, '0'),
        findsOneWidget,
        reason: 'the Days field must show the real stored 0, not a '
            'forced-to-1 placeholder',
      );
      await unmount(tester);
    },
  );

  testWidgets(
    'Days and Hours both at 0 disables Save with an explanatory message',
    (tester) async {
      await pump(tester);
      expect(tester.takeException(), isNull);
      await openSheet(tester);

      await tester.tap(find.text('Back up automatically'));
      await tester.pump();
      await tester.tap(find.text('Custom'));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Days'), '0');
      await tester.enterText(find.widgetWithText(TextField, 'Hours'), '0');
      await tester.pump();

      expect(
        find.text('Set at least one of Days or Hours above zero.'),
        findsOneWidget,
      );
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNull);
      await unmount(tester);
    },
  );
}
