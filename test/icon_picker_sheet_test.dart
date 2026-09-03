import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/accounts/add_account_sheet.dart';
import 'package:xpenc/features/categories/categories_screen.dart';

/// GitHub #102: Categories (and anywhere else an icon is chosen) should offer
/// every icon in `AppIcons`, filterable by search, with recently-picked icons
/// surfaced up top. Covers the shared `showIconPickerSheet` sheet through
/// both callers that wire it up.
///
/// Follows the three rules from test/smoke_test.dart: DB work inside
/// `runAsync`, never `pumpAndSettle`, unmount before the test ends.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
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

  Future<void> settleSheet(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets(
    'Add Account sheet: the icon field searches, picks, and remembers '
    'frequently used icons',
    (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showAddAccountSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);

      // Open the icon picker from the account sheet's own "Icon" field.
      await tester.tap(find.text('Tap to change'));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Search icons'), findsOneWidget);

      // No icon has ever been picked yet, so there's nothing to surface.
      expect(find.text('Frequently used'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('iconPickerSearch')),
        'coffee',
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Results'), findsOneWidget);
      expect(find.byIcon(Icons.coffee_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.coffee_outlined));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);

      // Back on the account sheet, the field now previews the chosen icon.
      expect(find.text('Search icons'), findsNothing);
      expect(find.byIcon(Icons.coffee_outlined), findsOneWidget);

      await tester.runAsync(() async {
        final settings = await db.getSettings();
        expect(settings.frequentIconKeys, 'coffee');
      });

      // Reopening the picker now surfaces coffee under "Frequently used".
      await tester.tap(find.text('Tap to change'));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Frequently used'), findsOneWidget);
      // 3, not 2: the "Frequently used" row, the "All icons" row, and the
      // account sheet's own field preview underneath — still mounted below
      // this stacked modal sheet.
      expect(find.byIcon(Icons.coffee_outlined), findsNWidgets(3));

      await unmount(tester);
    },
  );

  testWidgets(
    'Category editor: the icon field opens the same searchable picker',
    (tester) async {
      await pump(tester, const CategoriesScreen());
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('New category'));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('New category'), findsOneWidget);

      await tester.tap(find.text('Tap to change'));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Search icons'), findsOneWidget);
      expect(find.text('All icons'), findsOneWidget);

      await unmount(tester);
    },
  );
}
