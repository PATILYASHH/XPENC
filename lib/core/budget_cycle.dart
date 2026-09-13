import 'package:intl/intl.dart';

/// Some households get paid on a fixed day other than the 1st — e.g. the
/// 15th — and want their budgeting "month" to run payday-to-payday instead
/// of calendar-month. `startDay` is `Settings.budgetStartDay`; `1` is an
/// ordinary calendar month, which is the default for every existing install,
/// so nothing changes until someone opts in from Settings. Clamped to 1-28
/// wherever it's set, so every month can host every start day — no
/// "the 31st doesn't exist in February" edge case to handle here.
///
/// No widget tree, so this is testable without pumping a screen.
///
/// [anchor]'s day component is ignored — only its year/month select which
/// period, matching how `selectedMonthProvider` already stores "which
/// month" (day always 1) and steps by whole months via +/-.
({DateTime start, DateTime end}) budgetPeriodFor(DateTime anchor, int startDay) {
  final start = DateTime(anchor.year, anchor.month, startDay);
  final end = DateTime(
    anchor.year,
    anchor.month + 1,
    startDay,
  ).subtract(const Duration(milliseconds: 1));
  return (start: start, end: end);
}

/// Which period [date] actually falls in, as an anchor `selectedMonthProvider`
/// can store. With a startDay of 15: Sep 10 is still in the period anchored
/// at August (Aug 15 – Sep 14, since this payday hasn't happened yet), while
/// Sep 20 is anchored at September (Sep 15 – Oct 14).
DateTime budgetPeriodAnchorFor(DateTime date, int startDay) =>
    date.day >= startDay
    ? DateTime(date.year, date.month)
    : DateTime(date.year, date.month - 1);

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
