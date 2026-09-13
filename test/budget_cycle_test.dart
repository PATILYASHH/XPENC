import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/budget_cycle.dart';

/// A paycheck-driven budget cycle — e.g. paid on the 15th, so the budgeting
/// "month" runs 15th-to-15th instead of 1st-to-1st. `startDay: 1` (the
/// default for every existing install) must behave exactly like an ordinary
/// calendar month.
void main() {
  group('budgetPeriodFor', () {
    test('startDay 1 is an ordinary calendar month', () {
      final period = budgetPeriodFor(DateTime(2026, 9), 1);
      expect(period.start, DateTime(2026, 9, 1));
      expect(period.end, DateTime(2026, 9, 30, 23, 59, 59, 999));
    });

    test('startDay 15 runs from the 15th to the 14th of the next month', () {
      final period = budgetPeriodFor(DateTime(2026, 9), 15);
      expect(period.start, DateTime(2026, 9, 15));
      expect(period.end, DateTime(2026, 10, 14, 23, 59, 59, 999));
    });

    test('carries correctly across a year boundary', () {
      final period = budgetPeriodFor(DateTime(2026, 12), 15);
      expect(period.start, DateTime(2026, 12, 15));
      expect(period.end, DateTime(2027, 1, 14, 23, 59, 59, 999));
    });
  });

  group('budgetPeriodAnchorFor', () {
    test('startDay 1: every date anchors to its own calendar month', () {
      expect(
        budgetPeriodAnchorFor(DateTime(2026, 9, 1), 1),
        DateTime(2026, 9),
      );
      expect(
        budgetPeriodAnchorFor(DateTime(2026, 9, 30), 1),
        DateTime(2026, 9),
      );
    });

    test(
      'startDay 15: a date on or after payday anchors to its own month',
      () {
        expect(
          budgetPeriodAnchorFor(DateTime(2026, 9, 15), 15),
          DateTime(2026, 9),
        );
        expect(
          budgetPeriodAnchorFor(DateTime(2026, 9, 20), 15),
          DateTime(2026, 9),
        );
      },
    );

    test(
      "startDay 15: a date before payday hasn't started this month's cycle "
      "yet — it belongs to last month's",
      () {
        expect(
          budgetPeriodAnchorFor(DateTime(2026, 9, 14), 15),
          DateTime(2026, 8),
        );
        expect(
          budgetPeriodAnchorFor(DateTime(2026, 9, 1), 15),
          DateTime(2026, 8),
        );
      },
    );

    test('carries correctly across a year boundary', () {
      expect(
        budgetPeriodAnchorFor(DateTime(2026, 1, 5), 15),
        DateTime(2025, 12),
      );
    });

    test('round-trips into budgetPeriodFor: the anchor\'s period always '
        'contains the original date', () {
      for (final startDay in [1, 5, 15, 28]) {
        for (final date in [
          DateTime(2026, 9, 1),
          DateTime(2026, 9, 14),
          DateTime(2026, 9, 15),
          DateTime(2026, 9, 30),
        ]) {
          final anchor = budgetPeriodAnchorFor(date, startDay);
          final period = budgetPeriodFor(anchor, startDay);
          expect(
            !date.isBefore(period.start) && !date.isAfter(period.end),
            isTrue,
            reason: 'date=$date startDay=$startDay anchor=$anchor '
                'period=${period.start}..${period.end}',
          );
        }
      }
    });
  });

  group('budgetPeriodRangeLabel', () {
    test('formats as "d MMM – d MMM"', () {
      expect(
        budgetPeriodRangeLabel(DateTime(2026, 9), 15),
        '15 Sep – 14 Oct',
      );
    });
  });

  group('ordinalDay', () {
    test('the usual suffixes', () {
      expect(ordinalDay(1), '1st');
      expect(ordinalDay(2), '2nd');
      expect(ordinalDay(3), '3rd');
      expect(ordinalDay(4), '4th');
      expect(ordinalDay(21), '21st');
    });

    test('11th, 12th, 13th are the "th" exception, not "st"/"nd"/"rd"', () {
      expect(ordinalDay(11), '11th');
      expect(ordinalDay(12), '12th');
      expect(ordinalDay(13), '13th');
    });
  });
}
