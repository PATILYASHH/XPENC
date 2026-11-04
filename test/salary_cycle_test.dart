import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/budget_cycle.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/settings/budget_start_day_sheet.dart';

/// #182: a month that runs from payday — any day up to the 31st, or the
/// last working day of the month.
void main() {
  group('last working day', () {
    test('steps back over a weekend at the end of the month', () {
      // 31 Oct 2026 is a Saturday, 28 Feb 2027 a Sunday.
      expect(
        budgetCycleStart(2026, 10, kLastWorkingDay),
        DateTime(2026, 10, 30),
      );
      expect(budgetCycleStart(2027, 2, kLastWorkingDay), DateTime(2027, 2, 26));
      // 30 Nov 2026 is a Monday: the month's own last day.
      expect(
        budgetCycleStart(2026, 11, kLastWorkingDay),
        DateTime(2026, 11, 30),
      );
    });

    test('the issue: paid on 30 Oct, the cycle runs to the next payday', () {
      final p = budgetPeriodFor(DateTime(2026, 10), kLastWorkingDay);
      expect(p.start, DateTime(2026, 10, 30));
      expect(
        p.end,
        DateTime(2026, 11, 30).subtract(const Duration(milliseconds: 1)),
      );
    });

    test('a date belongs to the cycle its payday started', () {
      expect(
        budgetPeriodAnchorFor(DateTime(2026, 10, 29, 23), kLastWorkingDay),
        DateTime(2026, 9),
      );
      expect(
        budgetPeriodAnchorFor(DateTime(2026, 10, 30, 9), kLastWorkingDay),
        DateTime(2026, 10),
      );
      expect(
        budgetPeriodAnchorFor(DateTime(2026, 11, 4), kLastWorkingDay),
        DateTime(2026, 10),
      );
    });

    test('cycles meet with no gap and no overlap, a year round', () {
      for (var m = 1; m <= 12; m++) {
        final p = budgetPeriodFor(DateTime(2026, m), kLastWorkingDay);
        final next = budgetPeriodFor(DateTime(2026, m + 1), kLastWorkingDay);
        expect(
          next.start.difference(p.end),
          const Duration(milliseconds: 1),
          reason: 'month $m',
        );
        expect(p.start.weekday, lessThanOrEqualTo(DateTime.friday));
      }
    });
  });

  group('the 29th to the 31st', () {
    test('a shorter month starts on its own last day', () {
      expect(budgetCycleStart(2026, 4, 31), DateTime(2026, 4, 30));
      expect(budgetCycleStart(2026, 2, 30), DateTime(2026, 2, 28));
      expect(budgetCycleStart(2028, 2, 29), DateTime(2028, 2, 29));
      expect(budgetCycleStart(2026, 5, 31), DateTime(2026, 5, 31));
    });

    test('and the cycle still ends the day before the next one', () {
      final p = budgetPeriodFor(DateTime(2026, 4), 31);
      expect(p.start, DateTime(2026, 4, 30));
      expect(
        p.end,
        DateTime(2026, 5, 31).subtract(const Duration(milliseconds: 1)),
      );
      expect(
        budgetPeriodAnchorFor(DateTime(2026, 5, 30), 31),
        DateTime(2026, 4),
      );
      expect(
        budgetPeriodAnchorFor(DateTime(2026, 5, 31), 31),
        DateTime(2026, 5),
      );
    });
  });

  testWidgets('the start-day sheet offers the 31st and the last working '
      'day', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => BudgetStartDaySheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    await tester.tap(find.text('open'));
    await settle();
    expect(find.text('31'), findsOneWidget);
    await tester.tap(find.text('Last working day'));
    await settle();

    final settings = await tester.runAsync(db.getSettings);
    expect(settings!.budgetStartDay, kLastWorkingDay);
    expect(find.text('Last working day'), findsNothing, reason: 'closed');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  test('says the start day in words', () {
    expect(budgetCycleStartPhrase(15), 'the 15th');
    expect(budgetCycleStartPhrase(kLastWorkingDay), 'the last working day');
  });
}
