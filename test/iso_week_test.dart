import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/iso_week.dart';

/// GitHub #121: "Filter Transaction by Grouping week". Reference dates below
/// are the canonical ISO 8601 examples (Wikipedia's "ISO week date" article)
/// — the standard's own worked cases for the tricky year-boundary weeks.
void main() {
  group('isoWeekOf', () {
    test('an ordinary midweek date', () {
      // Wednesday 14 May 2008 is week 20, 2008.
      expect(isoWeekOf(DateTime(2008, 5, 14)), (isoYear: 2008, isoWeek: 20));
    });

    test('2005-01-01 (Saturday) belongs to week 53 of 2004', () {
      expect(isoWeekOf(DateTime(2005, 1, 1)), (isoYear: 2004, isoWeek: 53));
    });

    test('2007-01-01 (Monday) is week 1 of 2007 itself', () {
      expect(isoWeekOf(DateTime(2007, 1, 1)), (isoYear: 2007, isoWeek: 1));
    });

    test('2008-12-29 (Monday) already belongs to week 1 of 2009', () {
      expect(isoWeekOf(DateTime(2008, 12, 29)), (isoYear: 2009, isoWeek: 1));
    });

    test('2010-01-03 (Sunday) still belongs to week 53 of 2009', () {
      expect(isoWeekOf(DateTime(2010, 1, 3)), (isoYear: 2009, isoWeek: 53));
    });

    test('every day of one Monday-Sunday week reports the same week number', () {
      final monday = DateTime(2026, 8, 24);
      final expected = isoWeekOf(monday);
      for (var i = 0; i < 7; i++) {
        expect(isoWeekOf(monday.add(Duration(days: i))), expected);
      }
    });
  });

  group('weekRangeContaining', () {
    test('a Wednesday resolves to that week\'s Monday-Sunday', () {
      final range = weekRangeContaining(DateTime(2026, 8, 26));
      expect(range.start, DateTime(2026, 8, 24));
      expect(range.end, DateTime(2026, 8, 30));
    });

    test('a Monday is its own week\'s start', () {
      final range = weekRangeContaining(DateTime(2026, 8, 24));
      expect(range.start, DateTime(2026, 8, 24));
    });

    test('a Sunday is its own week\'s end', () {
      final range = weekRangeContaining(DateTime(2026, 8, 30));
      expect(range.end, DateTime(2026, 8, 30));
    });

    test('carries correctly across a month boundary', () {
      // Sunday 6 Sep 2026 is in the week starting Monday 31 Aug 2026.
      final range = weekRangeContaining(DateTime(2026, 9, 6));
      expect(range.start, DateTime(2026, 8, 31));
      expect(range.end, DateTime(2026, 9, 6));
    });
  });

  group('weekLabel', () {
    test('same-month week: "d–d MMM" for the range', () {
      expect(weekLabel(DateTime(2026, 8, 26)), 'Week 35, 2026 · 24–30 Aug');
    });

    test('a week spanning two months spells out both', () {
      expect(
        weekLabel(DateTime(2026, 9, 6)),
        'Week 36, 2026 · 31 Aug – 6 Sep',
      );
    });
  });
}
