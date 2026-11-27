import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/add_transaction/add_transaction_screen.dart';

/// GitHub #212: a category, subcategory or tag can be made straight from
/// the add page's pickers, and is picked on the spot — no trip to More.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AddTransactionScreen(initialType: TxType.expense),
        ),
      ),
    );
    await settle(tester);
    // The amount keypad opens over the fields; close it to reach them.
    await tester.tap(find.text('Done'));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  /// Fills the open editor sheet's name and saves it.
  Future<void> saveEditor(WidgetTester tester, String name) async {
    await tester.enterText(find.widgetWithText(TextField, 'Name'), name);
    await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
    await settle(tester);
    await settle(tester);
  }

  Future<CategoryRow?> categoryNamed(String name) async => (await db
          .select(db.categories)
          .get())
      .where((c) => c.name == name)
      .firstOrNull;

  testWidgets('＋ New in the category picker makes a category and picks it', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Select category').first);
    await settle(tester);
    await tester.tap(find.byKey(const Key('category-picker-new')));
    await settle(tester);
    expect(find.text('New category'), findsOneWidget);

    await saveEditor(tester, 'Coffee beans');

    // Both sheets are gone and the entry carries the new category.
    expect(find.byKey(const Key('category-picker-new')), findsNothing);
    expect(find.text('Coffee beans'), findsOneWidget);
    final made = await tester.runAsync(() => categoryNamed('Coffee beans'));
    expect(made, isNotNull);
    expect(made!.kind, CategoryKind.expense);
    expect(made.parentId, isNull);

    await unmount(tester);
  });

  testWidgets('＋ New inside a parent makes a subcategory of it', (
    tester,
  ) async {
    final foodId = await db.addCategory(
      name: 'Eating out',
      kind: CategoryKind.expense,
      colorValue: 0xFF16A34A,
      iconKey: 'food',
    );
    await db.addCategory(
      name: 'Lunch',
      kind: CategoryKind.expense,
      colorValue: 0xFF16A34A,
      iconKey: 'food',
      parentId: foodId,
    );
    await pump(tester);

    await tester.tap(find.text('Select category').first);
    await settle(tester);
    await tester.tap(find.text('Eating out'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('category-picker-new')));
    await settle(tester);

    await saveEditor(tester, 'Snacks');

    expect(find.text('Eating out › Snacks'), findsOneWidget);
    final made = await tester.runAsync(() => categoryNamed('Snacks'));
    expect(made?.parentId, foodId);

    await unmount(tester);
  });

  testWidgets('New tag in the tag picker makes a tag and selects it', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Tags'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('tag-picker-new')));
    await settle(tester);
    expect(find.text('New tag'), findsWidgets);

    await saveEditor(tester, 'Goa trip');

    // Back in the picker, already ticked.
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Goa trip'),
    );
    expect(chip.selected, isTrue);

    await tester.tap(find.text('Done'));
    await settle(tester);
    final tags = await tester.runAsync(() => db.select(db.tags).get());
    final trip = tags!.singleWhere((t) => t.name == 'Goa trip');
    // The add page shows it under the amount.
    expect(find.text('Goa trip'), findsOneWidget);
    expect(trip.modeId, isNull);

    await unmount(tester);
  });

  testWidgets('holding a category edits it and leaves the picker open', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Select category').first);
    await settle(tester);
    await tester.longPress(find.text('Rent'));
    await settle(tester);
    expect(find.text('Edit category'), findsOneWidget);

    await saveEditor(tester, 'House rent');

    // Still choosing: the picker shows the new name, nothing was picked.
    expect(find.byKey(const Key('category-picker-new')), findsOneWidget);
    expect(find.text('House rent'), findsOneWidget);
    expect(find.text('Select category'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('holding a tag edits it and keeps what was ticked', (
    tester,
  ) async {
    await db.addTag(name: 'Work', colorValue: 0xFF2563EB);
    await pump(tester);

    await tester.tap(find.byTooltip('Tags'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Work'));
    await tester.pump();
    await tester.longPress(find.widgetWithText(FilterChip, 'Work'));
    await settle(tester);
    expect(find.text('Edit tag'), findsOneWidget);

    await saveEditor(tester, 'Office');

    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Office'),
    );
    expect(chip.selected, isTrue);

    await unmount(tester);
  });
}
