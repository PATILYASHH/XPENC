import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/persons/add_group_expense_screen.dart';
import 'package:xpenc/features/persons/group_detail_screen.dart';
import 'package:xpenc/features/persons/persons_screen.dart';

/// Same three rules as `smoke_test.dart`: DB work inside `runAsync`, never
/// `pumpAndSettle`, unmount before the test ends.
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
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  testWidgets('Persons: Group tab renders empty, then shows a created group', (
    tester,
  ) async {
    await pump(tester, const PersonsScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Individual'), findsOneWidget);
    expect(find.text('Group'), findsOneWidget);

    // find.widgetWithText(Tab, ...), not find.text(...) — the Tab's own
    // hit-testable region, not just wherever its label's RenderParagraph
    // sits, is what actually needs tapping to switch pages.
    await tester.tap(find.widgetWithText(Tab, 'Group'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000)); // tab-switch animation
    // The Group tab's groupsProvider is watched for the first time only
    // now — its first real Drift stream emission needs a real-time delay
    // via runAsync, same as the initial pump() does for the first tab
    // (see this file's/`smoke_test.dart`'s shared doc comment on why).
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('No groups yet'), findsOneWidget);

    await tester.runAsync(() => db.addGroup('Trip'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Trip'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('GroupDetailScreen renders a group with members and history', (
    tester,
  ) async {
    final groupId = await tester.runAsync(() async {
      final ram = await db.addPerson('Ram');
      final shyam = await db.addPerson('Shyam');
      final id = await db.addGroup('Trip');
      await db.setGroupMembers(id, {ram, shyam});
      final food = (await db.watchCategories(CategoryKind.expense).first)
          .firstWhere((c) => c.name == 'Food')
          .id;
      await db.addGroupExpense(
        groupId: id,
        amount: Money.fromRupees(900),
        splitMethod: GroupSplitMethod.equal,
        date: DateTime(2026, 7, 5),
        accountId: await cashId(),
        categoryId: food,
        participantIds: {null, ram, shyam},
      );
      return id;
    });

    await pump(tester, GroupDetailScreen(groupId: groupId!));
    expect(tester.takeException(), isNull);
    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('Ram'), findsOneWidget);
    expect(find.text('Shyam'), findsOneWidget);
    expect(find.text('Add expense'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'GroupDetailScreen: a missing group shows an error, not a crash',
    (tester) async {
      await pump(tester, const GroupDetailScreen(groupId: 999));
      expect(tester.takeException(), isNull);
      expect(find.text('Group not found'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets('AddGroupExpenseScreen renders with members as participants', (
    tester,
  ) async {
    final groupId = await tester.runAsync(() async {
      final ram = await db.addPerson('Ram');
      final id = await db.addGroup('Trip');
      await db.setGroupMembers(id, {ram});
      return id;
    });

    await pump(tester, AddGroupExpenseScreen(groupId: groupId!));
    expect(tester.takeException(), isNull);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Paid by'), findsOneWidget);
    expect(find.text('You'), findsWidgets);
    expect(find.text('Ram'), findsWidgets);
    expect(find.text('Equal'), findsOneWidget);
    expect(find.text('Save expense'), findsOneWidget);
    await unmount(tester);
  });
}
