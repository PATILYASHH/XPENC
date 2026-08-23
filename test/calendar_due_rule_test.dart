import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/calendar/calendar_screen.dart';

/// GitHub #69: the calendar's yellow "due" dot can come from an Auto rule's
/// `nextDueDate` rather than a manual Reminder — tapping that day used to
/// show "Nothing on this day." with no explanation for the dot at all.
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
    'a day whose dot comes from an Auto rule shows an info card for it',
    (tester) async {
      final cash = (await tester.runAsync(
        () => db.watchAccounts().first,
      ))!.firstWhere((a) => a.type == AccountType.cash);
      final billsCategory = (await tester.runAsync(
        () => db.watchCategories(CategoryKind.expense).first,
      ))!.firstWhere((c) => c.name == 'Bills');

      final today = DateTime.now();
      await tester.runAsync(
        () => db.addRecurringRule(
          name: 'Electricity bill',
          kind: CategoryKind.expense,
          amount: Money.fromRupees(1200),
          accountId: cash.id,
          categoryId: billsCategory.id,
          frequency: RecurringFrequency.monthly,
          startsOn: today,
        ),
      );

      await pump(tester, const CalendarScreen());
      expect(tester.takeException(), isNull);

      // CalendarScreen defaults its selected day to today.
      expect(find.text('Nothing on this day.'), findsNothing);
      expect(find.text('Auto rules due'), findsOneWidget);
      expect(find.text('Electricity bill'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
