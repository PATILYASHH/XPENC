import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';

/// ISO 8601 week numbering (Monday-start weeks; week 1 is the week
/// containing the year's first Thursday, equivalently the week containing
/// 4 January) — GitHub #121's "Filter Transaction by Grouping week".
///
/// No widget tree, so this is testable without pumping a screen.
///
/// The ISO week-numbering year and week number for [date]. Shifting to the
/// week's own Thursday before reading the ordinal day is what makes this
/// correct across year boundaries without special-casing "week 0" or
/// "week 53" — the Thursday always falls in the ISO year that week
/// genuinely belongs to.
({int isoYear, int isoWeek}) isoWeekOf(DateTime date) {
  final weekday = date.weekday; // 1=Monday .. 7=Sunday
  final thursday = DateTime(date.year, date.month, date.day + (4 - weekday));
  final ordinalDay =
      thursday.difference(DateTime(thursday.year, 1, 1)).inDays + 1;
  return (isoYear: thursday.year, isoWeek: ((ordinalDay - 1) ~/ 7) + 1);
}

/// The Monday-to-Sunday range containing [date]. `end` is a plain date
/// (midnight), not end-of-day — callers that need an inclusive end-of-day
/// instant should normalize it themselves, same as
/// `TransactionFiltersSheet`'s existing custom date-range picker already
/// does for [TransactionFilters.dateRange].
DateTimeRange weekRangeContaining(DateTime date) {
  final monday = DateTime(date.year, date.month, date.day - (date.weekday - 1));
  final sunday = DateTime(monday.year, monday.month, monday.day + 6);
  return DateTimeRange(start: monday, end: sunday);
}

/// "Week 37, 2026 · 8–14 Sep" — the picker's stepper label.
String weekLabel(DateTime anchor) {
  final iso = isoWeekOf(anchor);
  final range = weekRangeContaining(anchor);
  final sameMonth = range.start.month == range.end.month;
  final dateRange = sameMonth
      ? '${range.start.day}–${DateFormat('d MMM').format(range.end)}'
      : '${DateFormat('d MMM').format(range.start)} – '
            '${DateFormat('d MMM').format(range.end)}';
  return 'Week ${iso.isoWeek}, ${iso.isoYear} · $dateRange';
}
