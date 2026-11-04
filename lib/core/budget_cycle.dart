import 'package:intl/intl.dart';

/// Some households get paid on a fixed day other than the 1st — e.g. the
/// 15th — and want their budgeting "month" to run payday-to-payday instead
/// of calendar-month. `startDay` is `Settings.budgetStartDay`; `1` is an
/// ordinary calendar month, which is the default for every existing install,
/// so nothing changes until someone opts in from Settings.
///
/// It's a day from 1 to 31 — a month too short for it (the 31st in April,
/// the 30th in February) starts on its own last day instead — or
/// [kLastWorkingDay] for a salary that lands on the last weekday of the
/// month (GitHub #182). [budgetCycleStart] is the one place either becomes
/// a date.
///
/// No widget tree, so this is testable without pumping a screen.
///
/// [anchor]'s day component is ignored — only its year/month select which
/// period, matching how `selectedMonthProvider` already stores "which
/// month" (day always 1) and steps by whole months via +/-.
({DateTime start, DateTime end}) budgetPeriodFor(
  DateTime anchor,
  int startDay,
) {
  final start = budgetCycleStart(anchor.year, anchor.month, startDay);
  final next = DateTime(anchor.year, anchor.month + 1);
  final end = budgetCycleStart(
    next.year,
    next.month,
    startDay,
  ).subtract(const Duration(milliseconds: 1));
  return (start: start, end: end);
}

/// `Settings.budgetStartDay` for "the last working day of the month": the
/// last Monday-to-Friday, wherever the month ends. Public holidays aren't
/// known, so a salary moved earlier for one starts the cycle a day late.
const kLastWorkingDay = 0;

/// The day [year]/[month]'s cycle starts — see [budgetPeriodFor].
DateTime budgetCycleStart(int year, int month, int startDay) {
  final lastDay = DateTime(year, month + 1, 0).day;
  if (startDay == kLastWorkingDay) {
    var day = DateTime(year, month, lastDay);
    while (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return day;
  }
  return DateTime(year, month, startDay.clamp(1, lastDay));
}

/// Which period [date] actually falls in, as an anchor `selectedMonthProvider`
/// can store. With a startDay of 15: Sep 10 is still in the period anchored
/// at August (Aug 15 – Sep 14, since this payday hasn't happened yet), while
/// Sep 20 is anchored at September (Sep 15 – Oct 14).
DateTime budgetPeriodAnchorFor(DateTime date, int startDay) {
  final day = DateTime(date.year, date.month, date.day);
  return day.isBefore(budgetCycleStart(date.year, date.month, startDay))
      ? DateTime(date.year, date.month - 1)
      : DateTime(date.year, date.month);
}

/// The start day as words: "the 15th", or "the last working day".
String budgetCycleStartPhrase(int startDay) => startDay == kLastWorkingDay
    ? 'the last working day'
    : 'the ${ordinalDay(startDay)}';

/// The exact date range for [anchor]'s period, e.g. "15 Sep – 14 Oct" — only
/// meaningful once [startDay] moves off the default 1st-of-the-month cycle;
/// callers should only show this alongside the plain "MMMM yyyy" label when
/// `startDay != 1`.
String budgetPeriodRangeLabel(DateTime anchor, int startDay) {
  final period = budgetPeriodFor(anchor, startDay);
  return '${DateFormat('d MMM').format(period.start)} – '
      '${DateFormat('d MMM').format(period.end)}';
}

/// "1st", "15th", "22nd" — the Settings picker's row/chip labels.
String ordinalDay(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  return switch (day % 10) {
    1 => '${day}st',
    2 => '${day}nd',
    3 => '${day}rd',
    _ => '${day}th',
  };
}
