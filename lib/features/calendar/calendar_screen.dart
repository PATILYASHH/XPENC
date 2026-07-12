import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// A month calendar built by hand (no calendar package). Each day cell shows the
/// money in / out for that day and a dot when an open reminder falls on it.
/// Tapping a day reveals its reminders and transactions below the grid.
///
/// This screen keeps its own shown month in [State]; it deliberately never
/// touches [selectedMonthProvider] so it stays independent of the rest of the app.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

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
        content: Text("Marked done — add the transaction from + when you're ready."),
      ),
    );
  }

  Future<void> _deleteReminder(int id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(dbProvider).deleteReminder(id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Reminder deleted')),
      );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            tooltip: 'New reminder',
            icon: const Icon(Icons.add_rounded),
            onPressed: _openReminderSheet,
          ),
        ],
      ),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load calendar.\n$e',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ),
        data: (txns) =>
            _content(theme, txns, categoryMap, accountMap, openReminders),
      ),
    );
  }

  Widget _content(
    ThemeData theme,
    List<TransactionRow> txns,
    Map<int, CategoryRow> categoryMap,
    Map<int, AccountRow> accountMap,
    List<ReminderRow> openReminders,
  ) {
    // Per-day money in / out (transfers are neither income nor expense — ignore).
    final incomeByDay = <DateTime, Money>{};
    final expenseByDay = <DateTime, Money>{};
    for (final tx in txns) {
      if (tx.type == TxType.transfer) continue;
      final day = _dateOnly(tx.date);
      if (tx.type == TxType.income) {
        incomeByDay[day] = (incomeByDay[day] ?? const Money.zero()) + tx.amount;
      } else {
        expenseByDay[day] =
            (expenseByDay[day] ?? const Money.zero()) + tx.amount;
      }
    }

    final reminderDays = {
      for (final r in openReminders) _dateOnly(r.dueDate),
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
          _grid(theme, incomeByDay, expenseByDay, reminderDays),
          const SizedBox(height: 24),
          if (_selectedDay != null)
            ..._daySections(
              theme,
              txns,
              categoryMap,
              accountMap,
              openReminders,
            ),
          const SizedBox(height: 20),
          Text(
            'Reminders never post money on their own — you confirm each one.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
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
    Set<DateTime> reminderDays,
  ) {
    final daysInMonth =
        DateTime(_shownMonth.year, _shownMonth.month + 1, 0).day;
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
        return _dayCell(
          theme,
          date: date,
          income: incomeByDay[date],
          expense: expenseByDay[date],
          hasReminder: reminderDays.contains(date),
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
    required bool hasReminder,
    required bool isToday,
    required bool isSelected,
  }) {
    final cs = theme.colorScheme;
    final inMoney = (income != null && !income.isZero) ? income : null;
    final outMoney = (expense != null && !expense.isZero) ? expense : null;

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
                    fontWeight:
                        isToday ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isToday ? cs.secondary : cs.onSurface),
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ),
              if (hasReminder && !isSelected)
                Positioned(
                  right: 1,
                  top: 1,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: cs.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          // A grid cell is only ~42x53dp at 360dp wide. The day circle plus two
          // 9pt lines barely fits, so a long compact amount or a larger system
          // font overflows. Flexible + scale-down makes that impossible rather
          // than merely unlikely.
          if (inMoney != null) _cellAmount(inMoney, AppColors.income),
          if (outMoney != null) _cellAmount(outMoney, AppColors.expense),
        ],
      ),
    );
  }

  Widget _cellAmount(Money amount, Color color) => Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            MoneyFormat.compact(amount),
            maxLines: 1,
            style: TextStyle(
              fontSize: 9,
              height: 1.1,
              color: color,
              fontFeatures: kTabularFigures,
            ),
          ),
        ),
      );

  // ── Selected-day sections ───────────────────────────────────────────────────

  List<Widget> _daySections(
    ThemeData theme,
    List<TransactionRow> txns,
    Map<int, CategoryRow> categoryMap,
    Map<int, AccountRow> accountMap,
    List<ReminderRow> openReminders,
  ) {
    final day = _selectedDay!;
    final dayReminders = openReminders
        .where((r) => _dateOnly(r.dueDate) == day)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final dayTx = txns.where((t) => _dateOnly(t.date) == day).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final widgets = <Widget>[
      Text(
        DateFormat('EEE, d MMM yyyy').format(day),
        style:
            theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
    ];

    if (dayReminders.isEmpty && dayTx.isEmpty) {
      widgets.add(_emptyCard(theme, 'Nothing on this day.'));
      return widgets;
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
        ..addAll(
          dayTx.map((t) => _txTile(theme, t, categoryMap, accountMap)),
        );
    }

    return widgets;
  }

  Widget _sectionLabel(ThemeData theme, String text) => Text(
        text,
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );

  Widget _emptyCard(ThemeData theme, String text) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          child: Center(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete reminder',
                  icon: Icon(Icons.delete_outline_rounded,
                      color: cs.onSurfaceVariant),
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
    final toAccount =
        tx.toAccountId == null ? null : accountMap[tx.toAccountId];

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
    final subtitle =
        (note != null && note.isNotEmpty) ? '$base · $note' : base;

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
          style:
              theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
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
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a title')),
      );
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
      await ref.read(dbProvider).addReminder(
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
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
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: kTabularFigures,
            ),
            decoration: const InputDecoration(
              labelText: 'Amount (optional)',
              prefixText: '₹ ',
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
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
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
