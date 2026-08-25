import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../auto/recurring_rule_sheet.dart';

/// A month calendar built by hand (no calendar package). Each day cell shows the
/// money in / out for that day and a dot when an open reminder falls on it.
/// Tapping a day reveals its reminders and transactions below the grid.
///
/// This screen keeps its own shown month in [State]; it deliberately never
/// touches [selectedMonthProvider] so it stays independent of the rest of the app.
///
/// [embedded] is true when this screen is a bottom-nav tab (GitHub #70) —
/// `AppShell`'s shared top bar owns the title/actions then, reached via
/// [calendarGoToTodaySignalProvider]/[calendarNewReminderSignalProvider]
/// rather than this widget's own `AppBar`. Default `false` keeps every
/// existing `/more/calendar` push exactly as it was.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  /// First day of the month currently on screen.
  late DateTime _shownMonth;

  /// The tapped day, or `null` when nothing is selected.
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _shownMonth = DateTime(now.year, now.month, 1);
    _selectedDay = _dateOnly(now);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _onCurrentMonth {
    final now = DateTime.now();
    return _shownMonth.year == now.year && _shownMonth.month == now.month;
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _shownMonth = DateTime(now.year, now.month, 1);
      _selectedDay = _dateOnly(now);
    });
  }

  void _stepMonth(int delta) {
    setState(() {
      _shownMonth = DateTime(_shownMonth.year, _shownMonth.month + delta, 1);
      // Selection belongs to whatever month it was made in; drop it on navigation.
      _selectedDay = null;
    });
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _confirmMarkPaid(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as paid'),
        content: const Text(
          'This will not post anything by itself. '
          'Confirm to record the transaction.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(dbProvider).setReminderStatus(id, ReminderStatus.done);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update reminder')),
      );
      return;
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          "Marked done — add the transaction from + when you're ready.",
        ),
      ),
    );
  }

  Future<void> _deleteReminder(int id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(dbProvider).deleteReminder(id);
      messenger.showSnackBar(const SnackBar(content: Text('Reminder deleted')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete reminder')),
      );
    }
  }

  void _openReminderSheet() {
    final initial = _selectedDay ?? _dateOnly(DateTime.now());
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReminderSheet(initialDate: initial),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txAsync = ref.watch(allTransactionsProvider);
    final categoryMap = ref.watch(categoryMapProvider);
    final accountMap = ref.watch(accountMapProvider);
    final openReminders = ref.watch(openRemindersProvider);
    final recurringRules =
        ref.watch(recurringRulesProvider).valueOrNull ?? const [];
    final showDayTotals = ref.watch(showCalendarDayTotalsProvider);

    if (widget.embedded) {
      ref.listen<int>(calendarGoToTodaySignalProvider, (_, _) => _goToToday());
      ref.listen<int>(
        calendarNewReminderSignalProvider,
        (_, _) => _openReminderSheet(),
      );
    }

    final body = txAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load calendar.\n$e',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ),
      data: (txns) => _content(
        theme,
        txns,
        categoryMap,
        accountMap,
        openReminders,
        recurringRules,
        showDayTotals,
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          if (!_onCurrentMonth)
            IconButton(
              tooltip: 'Today',
              icon: const Icon(Icons.today_rounded),
              onPressed: _goToToday,
            ),
          IconButton(
            tooltip: 'New reminder',
            icon: const Icon(Icons.add_rounded),
            onPressed: _openReminderSheet,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _content(
    ThemeData theme,
    List<TransactionRow> txns,
    Map<int, CategoryRow> categoryMap,
    Map<int, AccountRow> accountMap,
    List<ReminderRow> openReminders,
    List<RecurringRuleRow> recurringRules,
    bool showDayTotals,
  ) {
    // Per-day money in / out, plus which days carry a transfer (neither
    // income nor expense — a lateral move between the user's own accounts).
    final incomeByDay = <DateTime, Money>{};
    final expenseByDay = <DateTime, Money>{};
    final transferDays = <DateTime>{};
    for (final tx in txns) {
      final day = _dateOnly(tx.date);
      if (tx.type == TxType.transfer) {
        transferDays.add(day);
        continue;
      }
      if (tx.type == TxType.income) {
        incomeByDay[day] = (incomeByDay[day] ?? const Money.zero()) + tx.amount;
      } else {
        expenseByDay[day] =
            (expenseByDay[day] ?? const Money.zero()) + tx.amount;
      }
    }

    // Every open reminder and active Auto rule's next run — a probable event
    // ahead of today, or the day it lands and becomes an actual one (#67).
    final dueDays = <DateTime>{
      for (final r in openReminders) _dateOnly(r.dueDate),
      for (final r in recurringRules)
        if (r.isActive) _dateOnly(r.nextDueDate),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _monthHeader(theme),
          const SizedBox(height: 16),
          _weekdayHeader(theme),
          const SizedBox(height: 8),
          _grid(theme, incomeByDay, expenseByDay, transferDays, dueDays),
          const SizedBox(height: 24),
          if (_selectedDay != null)
            ..._daySections(
              theme,
              txns,
              categoryMap,
              accountMap,
              openReminders,
              recurringRules,
              showDayTotals,
              incomeByDay[_selectedDay!],
              expenseByDay[_selectedDay!],
            ),
          const SizedBox(height: 20),
          Text(
            'Reminders never post money on their own — you confirm each one.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ── Month + weekday headers ─────────────────────────────────────────────────

  Widget _monthHeader(ThemeData theme) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => _stepMonth(-1),
        ),
        Expanded(
          child: Center(
            child: Text(
              DateFormat('MMMM yyyy').format(_shownMonth),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () => _stepMonth(1),
        ),
      ],
    );
  }

  Widget _weekdayHeader(ThemeData theme) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Grid ────────────────────────────────────────────────────────────────────

  Widget _grid(
    ThemeData theme,
    Map<DateTime, Money> incomeByDay,
    Map<DateTime, Money> expenseByDay,
    Set<DateTime> transferDays,
    Set<DateTime> dueDays,
  ) {
    final daysInMonth = DateTime(
      _shownMonth.year,
      _shownMonth.month + 1,
      0,
    ).day;
    // Monday-based offset: weekday is 1 (Mon) … 7 (Sun).
    final leadingBlanks = _shownMonth.weekday - 1;
    final cellCount = leadingBlanks + daysInMonth;
    final today = _dateOnly(DateTime.now());

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cellCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.8,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        if (index < leadingBlanks) return const SizedBox.shrink();
        final dayNum = index - leadingBlanks + 1;
        final date = DateTime(_shownMonth.year, _shownMonth.month, dayNum);
        // Yellow while the reminder/Auto rule is still ahead of today; once
        // today catches up to it, it's no longer probable but actual (#67).
        final dueColor = !dueDays.contains(date)
            ? null
            : (date.isAfter(today) ? Colors.amber : AppColors.expense);
        return _dayCell(
          theme,
          date: date,
          income: incomeByDay[date],
          expense: expenseByDay[date],
          hasTransfer: transferDays.contains(date),
          dueColor: dueColor,
          isToday: date == today,
          isSelected: _selectedDay == date,
        );
      },
    );
  }

  Widget _dayCell(
    ThemeData theme, {
    required DateTime date,
    required Money? income,
    required Money? expense,
    required bool hasTransfer,
    required Color? dueColor,
    required bool isToday,
    required bool isSelected,
  }) {
    final cs = theme.colorScheme;
    final inMoney = (income != null && !income.isZero) ? income : null;
    final outMoney = (expense != null && !expense.isZero) ? expense : null;
    final dots = [
      if (inMoney != null) AppColors.income,
      if (outMoney != null) AppColors.expense,
      if (hasTransfer) AppColors.transfer,
    ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedDay = date),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? cs.secondary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${date.day}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isToday ? cs.secondary : cs.onSurface),
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ),
              if (dueColor != null && !isSelected)
                Positioned(
                  right: 1,
                  top: 1,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dueColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // A plain dot per direction, not the amount itself — keeps the grid
          // readable at a glance and, unlike a printed figure, gives away
          // nothing if the screen is glimpsed by someone else (GitHub #28).
          if (dots.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < dots.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  _cellDot(dots[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _cellDot(Color color) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  // ── Selected-day sections ───────────────────────────────────────────────────

  List<Widget> _daySections(
    ThemeData theme,
    List<TransactionRow> txns,
    Map<int, CategoryRow> categoryMap,
    Map<int, AccountRow> accountMap,
    List<ReminderRow> openReminders,
    List<RecurringRuleRow> recurringRules,
    bool showDayTotals,
    Money? dayIncome,
    Money? dayExpense,
  ) {
    final day = _selectedDay!;
    final dayReminders =
        openReminders.where((r) => _dateOnly(r.dueDate) == day).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    // The yellow/red dot on this day may come from an Auto rule rather than
    // a Reminder — without this, tapping that day showed nothing at all for
    // it (GitHub #69), even though the dot promised something was there.
    final dueRules =
        recurringRules
            .where((r) => r.isActive && _dateOnly(r.nextDueDate) == day)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final dayTx = txns.where((t) => _dateOnly(t.date) == day).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final widgets = <Widget>[
      Text(
        DateFormat('EEE, d MMM yyyy').format(day),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
      if (showDayTotals &&
          ((dayIncome != null && !dayIncome.isZero) ||
              (dayExpense != null && !dayExpense.isZero))) ...[
        _dayTotalsStrip(theme, dayIncome, dayExpense),
        const SizedBox(height: 16),
      ],
    ];

    if (dayReminders.isEmpty && dueRules.isEmpty && dayTx.isEmpty) {
      widgets.add(_emptyCard(theme, 'Nothing on this day.'));
      return widgets;
    }

    if (dueRules.isNotEmpty) {
      widgets
        ..add(_sectionLabel(theme, 'Auto rules due'))
        ..add(const SizedBox(height: 8))
        ..addAll(dueRules.map((r) => _dueRuleTile(theme, r)))
        ..add(const SizedBox(height: 16));
    }

    if (dayReminders.isNotEmpty) {
      widgets
        ..add(_sectionLabel(theme, 'Reminders'))
        ..add(const SizedBox(height: 8))
        ..addAll(dayReminders.map((r) => _reminderTile(theme, r)))
        ..add(const SizedBox(height: 16));
    }

    if (dayTx.isNotEmpty) {
      widgets
        ..add(_sectionLabel(theme, 'Transactions'))
        ..add(const SizedBox(height: 8))
        ..addAll(dayTx.map((t) => _txTile(theme, t, categoryMap, accountMap)));
    }

    return widgets;
  }

  /// The selected day's money in/out — only the sides that actually have
  /// something, per GitHub #75 (a day with only expenses shows just the
  /// outflow total, and vice versa). Toggled off entirely from Settings.
  Widget _dayTotalsStrip(ThemeData theme, Money? income, Money? expense) {
    final showIncome = income != null && !income.isZero;
    final showExpense = expense != null && !expense.isZero;

    Widget totalTile(String label, Money amount, Color color, IconData icon) {
      return Expanded(
        child: Card(
          color: color.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      MoneyText(
                        amount,
                        color: color,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        if (showIncome)
          totalTile(
            'In',
            income,
            AppColors.income,
            Icons.arrow_downward_rounded,
          ),
        if (showIncome && showExpense) const SizedBox(width: 12),
        if (showExpense)
          totalTile(
            'Out',
            expense,
            AppColors.expense,
            Icons.arrow_upward_rounded,
          ),
      ],
    );
  }

  Widget _sectionLabel(ThemeData theme, String text) => Text(
    text,
    style: theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );

  Widget _emptyCard(ThemeData theme, String text) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Center(
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );

  Widget _reminderTile(ThemeData theme, ReminderRow r) {
    final cs = theme.colorScheme;
    final isPay = r.direction == ReminderDirection.pay;
    final accent = isPay ? AppColors.expense : AppColors.income;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPay
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _directionChip(isPay),
                          if (r.amount != null) ...[
                            const SizedBox(width: 8),
                            MoneyText(
                              r.amount!,
                              color: accent,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete reminder',
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                  onPressed: () => _deleteReminder(r.id),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _confirmMarkPaid(r.id),
                child: const Text('Mark as paid'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// An Auto rule whose `nextDueDate` lands on the selected day — it posts
  /// itself on schedule with no confirmation step, so unlike [_reminderTile]
  /// there's no "mark as paid" here, just a way to see what the dot means
  /// and jump to the rule if it needs adjusting.
  Widget _dueRuleTile(ThemeData theme, RecurringRuleRow r) {
    final cs = theme.colorScheme;
    final isExpense = r.kind == CategoryKind.expense;
    final accent = isExpense ? AppColors.expense : AppColors.income;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.15),
          foregroundColor: accent,
          child: Icon(
            isExpense ? Icons.north_east_rounded : Icons.south_west_rounded,
          ),
        ),
        title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          r.isEstimate ? 'Auto rule · estimate' : 'Auto rule',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        trailing: MoneyText(
          r.amount,
          color: accent,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () => showRecurringRuleSheet(context, existing: r),
      ),
    );
  }

  Widget _directionChip(bool isPay) {
    final color = isPay ? AppColors.expense : AppColors.income;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isPay ? 'Pay' : 'Receive',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _txTile(
    ThemeData theme,
    TransactionRow tx,
    Map<int, CategoryRow> categoryMap,
    Map<int, AccountRow> accountMap,
  ) {
    final isTransfer = tx.type == TxType.transfer;
    final category = tx.categoryId == null ? null : categoryMap[tx.categoryId];
    final account = accountMap[tx.accountId];
    final toAccount = tx.toAccountId == null
        ? null
        : accountMap[tx.toAccountId];

    final accent = isTransfer
        ? AppColors.transfer
        : (category != null
              ? Color(category.colorValue)
              : theme.colorScheme.onSurfaceVariant);
    final icon = isTransfer
        ? Icons.swap_horiz_rounded
        : AppIcons.resolve(category?.iconKey ?? 'other');

    final title = isTransfer ? 'Transfer' : (category?.name ?? 'Uncategorised');
    final base = isTransfer
        ? '${account?.name ?? '—'} → ${toAccount?.name ?? '—'}'
        : (account?.name ?? '—');
    final note = tx.note?.trim();
    final subtitle = (note != null && note.isNotEmpty) ? '$base · $note' : base;

    final displayAmount = tx.type == TxType.expense ? -tx.amount : tx.amount;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.15),
          child: Icon(icon, color: accent, size: 22),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: MoneyText(
          displayAmount,
          signed: !isTransfer,
          color: colorForTxType(tx.type),
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        // Same destination a tap in the Transactions tab opens (GitHub #56)
        // — the calendar's day list gave no way in before this.
        onTap: () => context.push('/transaction/${tx.id}'),
      ),
    );
  }
}

// ── Add-reminder sheet ────────────────────────────────────────────────────────

class _ReminderSheet extends ConsumerStatefulWidget {
  const _ReminderSheet({required this.initialDate});

  final DateTime initialDate;

  @override
  ConsumerState<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends ConsumerState<_ReminderSheet> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();

  ReminderDirection _direction = ReminderDirection.pay;
  late DateTime _dueDate;
  double _notifyDays = 0;

  @override
  void initState() {
    super.initState();
    _dueDate = widget.initialDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter a title')));
      return;
    }

    Money? amount;
    final amtText = _amountCtrl.text.trim();
    if (amtText.isNotEmpty) {
      amount = Money.tryParse(amtText);
      if (amount == null || !amount.isPositive) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Enter a valid amount')),
        );
        return;
      }
    }

    final navigator = Navigator.of(context);
    try {
      await ref
          .read(dbProvider)
          .addReminder(
            title: title,
            amount: amount,
            direction: _direction,
            dueDate: _dueDate,
            notifyDaysBefore: _notifyDays.round(),
          );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save reminder')),
      );
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom:
            MediaQuery.of(context).padding.bottom +
            MediaQuery.of(context).viewInsets.bottom +
            20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'New reminder',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. Electricity bill',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: kTabularFigures,
            ),
            decoration: InputDecoration(
              labelText: 'Amount (optional)',
              prefixText: MoneyFormat.inputPrefix,
            ),
          ),
          const SizedBox(height: 20),
          SegmentedButton<ReminderDirection>(
            segments: const [
              ButtonSegment(
                value: ReminderDirection.pay,
                label: Text('Pay'),
                icon: Icon(Icons.arrow_upward_rounded),
              ),
              ButtonSegment(
                value: ReminderDirection.receive,
                label: Text('Receive'),
                icon: Icon(Icons.arrow_downward_rounded),
              ),
            ],
            selected: {_direction},
            onSelectionChanged: (s) => setState(() => _direction = s.first),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.event_rounded, color: cs.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Due date',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('EEE, d MMM yyyy').format(_dueDate),
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _notifyDays.round() == 0
                ? 'Notify me on the day'
                : 'Notify me ${_notifyDays.round()} '
                      'day${_notifyDays.round() == 1 ? '' : 's'} before',
            style: theme.textTheme.bodyMedium,
          ),
          Slider(
            value: _notifyDays,
            min: 0,
            max: 7,
            divisions: 7,
            label: '${_notifyDays.round()}',
            onChanged: (v) => setState(() => _notifyDays = v),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Save reminder'),
            ),
          ),
        ],
      ),
    );
  }
}
