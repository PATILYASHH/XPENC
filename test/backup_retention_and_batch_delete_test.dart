import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/data_export/backup_screen.dart';

/// GitHub #131 — "keep last x backup": the Backup & Restore screen should
/// offer a count-based retention mode (alongside the existing time-based
/// one) and a way to delete several backups at once.
void main() {
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
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'switching to Count mode and picking "Last 5" saves a count-based '
    'retention setting',
    (tester) async {
      await pump(tester, const BackupScreen());
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Automatic backups').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Turn the feature on first — the retention section only shows once
      // enabled, same as the existing "HOW OFTEN" section.
      await tester.tap(find.text('Back up automatically'));
      await tester.pump();

      await tester.tap(find.text('Count'));
      await tester.pump();

      expect(find.text('Last 5'), findsOneWidget);
      await tester.tap(find.text('Last 5'));
      await tester.pump();

      await tester.ensureVisible(find.text('Save'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final s = await db.getSettings();
      expect(s.autoBackupEnabled, isTrue);
      expect(s.backupRetentionMode, BackupRetentionMode.count);
      expect(s.backupRetentionCount, 5);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('Count mode blocks Save until a count of at least 1 is entered', (
    tester,
  ) async {
    await pump(tester, const BackupScreen());

    await tester.tap(find.text('Automatic backups').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Back up automatically'));
    await tester.pump();
    await tester.tap(find.text('Count'));
    await tester.pump();

    // No preset tapped, the count field is empty — Save must be disabled.
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(saveButton.onPressed, isNull);
    expect(
      find.text('Enter how many backups to keep (at least 1).'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'GitHub #132: switching to On change with count retention saves an '
    'event-triggered schedule with a cooldown',
    (tester) async {
      await pump(tester, const BackupScreen());

      await tester.tap(find.text('Automatic backups').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Back up automatically'));
      await tester.pump();

      await tester.tap(find.text('On change'));
      await tester.pump();
      expect(
        find.widgetWithText(TextField, 'Minutes between backups'),
        findsOneWidget,
      );

      await tester.tap(find.text('Count'));
      await tester.pump();
      await tester.tap(find.text('Last 3'));
      await tester.pump();

      await tester.ensureVisible(find.text('Save'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final s = await db.getSettings();
      expect(s.autoBackupEnabled, isTrue);
      expect(s.autoBackupFrequency, AutoBackupFrequency.onChange);
      expect(s.autoBackupCooldownMinutes, 10); // the sheet's default
      expect(s.backupRetentionMode, BackupRetentionMode.count);
      expect(s.backupRetentionCount, 3);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'long-pressing a backup enters batch-select mode; tapping more tiles '
    'grows the selection, and Cancel clears it',
    (tester) async {
      await tester.runAsync(() async {
        await db.upsertBackupRecord(
          fileName: '010826XPENCEBACKUP.json',
          uri: 'content://a',
          sizeBytes: 100,
          createdAt: DateTime(2026, 8, 1),
        );
        await db.upsertBackupRecord(
          fileName: '020826XPENCEBACKUP.json',
          uri: 'content://b',
          sizeBytes: 100,
          createdAt: DateTime(2026, 8, 2),
        );
      });

      await pump(tester, const BackupScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('Backups'), findsOneWidget);
      expect(find.text('Find existing'), findsOneWidget);

      await tester.longPress(find.text('010826XPENCEBACKUP.json'));
      await tester.pump();

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Find existing'), findsNothing);
      // find.byIcon rather than widgetWithText(TextButton, ...) — the header
      // Delete action is a TextButton.icon, whose internal widget type isn't
      // stable across Flutter versions; the icon is unique to this button.
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      // Entering selection mode hides the per-tile overflow menu — nothing
      // else should be able to trigger a restore/share/delete meanwhile.
      expect(find.byType(PopupMenuButton<String>), findsNothing);

      await tester.tap(find.text('020826XPENCEBACKUP.json'));
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.text('020826XPENCEBACKUP.json'));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.text('Backups'), findsOneWidget);
      expect(find.text('1 selected'), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'Delete opens a confirm dialog naming how many backups are about to go',
    (tester) async {
      await tester.runAsync(() async {
        await db.upsertBackupRecord(
          fileName: '010826XPENCEBACKUP.json',
          uri: 'content://a',
          sizeBytes: 100,
          createdAt: DateTime(2026, 8, 1),
        );
        await db.upsertBackupRecord(
          fileName: '020826XPENCEBACKUP.json',
          uri: 'content://b',
          sizeBytes: 100,
          createdAt: DateTime(2026, 8, 2),
        );
      });

      await pump(tester, const BackupScreen());
      await tester.longPress(find.text('010826XPENCEBACKUP.json'));
      await tester.pump();
      await tester.tap(find.text('020826XPENCEBACKUP.json'));
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      expect(find.text('Delete 2 backups?'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Cancel the dialog rather than confirm — confirming would exercise
      // the real MediaStore plugin, which isn't available in a widget test.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Cancel'),
        ),
      );
      await tester.pump();
      expect(
        find.text('2 selected'),
        findsOneWidget,
        reason: 'cancelling the dialog must leave the selection untouched',
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
