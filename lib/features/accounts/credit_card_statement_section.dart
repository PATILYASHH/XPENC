import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Opt-in statement/due-date tracking for a credit card (GitHub #91) — off
/// unless the user turns it on, same shape as [EnvelopeSection]'s own
/// per-account toggle. "Amount due" is just the account's current
/// (negative) balance — XPENC doesn't snapshot a frozen balance at each
/// statement close, so this reads as "what you owe right now", not "what
/// last month's statement said", which stays true even after a fresh
/// purchase moves the number.
class CreditCardStatementSection extends ConsumerWidget {
  const CreditCardStatementSection({required this.account, super.key});

  final AccountRow account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final detail = ref.watch(creditCardDetailsProvider(account.id)).valueOrNull;

    return Card(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            title: const Text('Track statement & due date'),
            subtitle: Text(
              detail != null
                  ? "Know when this month's bill is due, with a reminder "
                        'before it.'
                  : 'Optional — set your statement close day and payment '
                        'due day.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            value: detail != null,
            onChanged: (v) => v
                ? _showCycleDialog(context, ref, existing: null)
                : _turnOff(context, ref),
          ),
          if (detail != null) ...[
            const Divider(height: 1, indent: 16),
            _StatementSummary(account: account, detail: detail),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      _showCycleDialog(context, ref, existing: detail),
                  child: const Text('Edit'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showCycleDialog(
    BuildContext context,
    WidgetRef ref, {
    required CreditCardDetailRow? existing,
  }) async {
    final result = await showDialog<_CycleResult>(
      context: context,
      builder: (_) => _CreditCardCycleDialog(existing: existing),
    );
    if (result == null) return;

    await ref
        .read(dbProvider)
        .upsertCreditCardDetails(
          accountId: account.id,
          statementDay: result.statementDay,
          dueDay: result.dueDay,
          notifyDaysBefore: result.notifyDaysBefore,
        );
  }

  Future<void> _turnOff(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop tracking this card\'s cycle?'),
        content: const Text(
          'The statement close day, due day and reminder are forgotten. '
          "Nothing about the card itself changes.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Turn off'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(dbProvider).deleteCreditCardDetails(account.id);
  }
}

class _StatementSummary extends ConsumerWidget {
  const _StatementSummary({required this.account, required this.detail});

  final AccountRow account;
  final CreditCardDetailRow detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final period = ref.watch(creditCardStatementPeriodProvider(account.id))!;
    final dueDate = ref.watch(creditCardNextDueDateProvider(account.id))!;
    final daysLeft = dueDate
        .difference(DateTime.now())
        .inDays; // floor, "today" reads as 0
    final owed = account.currentBalance.abs;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(
            theme,
            'Current statement period',
            '${DateFormat('d MMM').format(period.start)} – '
                '${DateFormat('d MMM').format(period.end)}',
          ),
          const SizedBox(height: 12),
          _row(
            theme,
            'Payment due',
            '${DateFormat('d MMM yyyy').format(dueDate)}'
                ' (${_dueInLabel(daysLeft)})',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'You currently owe',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              MoneyText(
                owed,
                color: AppColors.expense,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Label above, value below — never a side-by-side [Row], since the due
  /// date's value ("18 Sep 2026 (in 12 days)") is easily long enough to
  /// collide with its own label on a narrow phone.
  Widget _row(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  String _dueInLabel(int daysLeft) {
    if (daysLeft < 0) return 'overdue';
    if (daysLeft == 0) return 'today';
    if (daysLeft == 1) return 'tomorrow';
    return 'in $daysLeft days';
  }
}

typedef _CycleResult = ({int statementDay, int dueDay, int notifyDaysBefore});

/// A `StatefulWidget`, not bare controllers/state disposed right after
/// `showDialog` resolves — see `_RenameAccountDialog` in `accounts_screen.dart`
/// for why that races the dialog's own closing animation.
class _CreditCardCycleDialog extends StatefulWidget {
  const _CreditCardCycleDialog({required this.existing});

  final CreditCardDetailRow? existing;

  @override
  State<_CreditCardCycleDialog> createState() =>
      _CreditCardCycleDialogState();
}

class _CreditCardCycleDialogState extends State<_CreditCardCycleDialog> {
  late int _statementDay = widget.existing?.statementDay ?? 1;
  late int _dueDay = widget.existing?.dueDay ?? 15;
  late double _notifyDays =
      (widget.existing?.notifyDaysBefore ?? 3).toDouble();

  Future<void> _pickDay({required bool forStatement}) async {
    final initialDay = forStatement ? _statementDay : _dueDay;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      // Only the day-of-month picked matters; the month/year shown is just
      // whatever makes that day valid to select.
      initialDate: DateTime(now.year, now.month, initialDay.clamp(1, 28)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (forStatement) {
        _statementDay = picked.day;
      } else {
        _dueDay = picked.day;
      }
    });
  }

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Track statement & due date'
            : 'Edit statement & due date',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Statement closes'),
              subtitle: Text('The ${_ordinal(_statementDay)} of each month'),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: () => _pickDay(forStatement: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Payment due'),
              subtitle: Text('The ${_ordinal(_dueDay)} of each month'),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: () => _pickDay(forStatement: false),
            ),
            const SizedBox(height: 8),
            Text(
              'Notify me ${_notifyDays.round()} '
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
            Text(
              'A shorter month snaps the close/due day to its last day, '
              'then returns once that day exists again.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((
            statementDay: _statementDay,
            dueDay: _dueDay,
            notifyDaysBefore: _notifyDays.round(),
          )),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
