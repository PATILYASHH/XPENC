import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/money_text.dart';
import '../../data/card_statement.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Opt-in statement/due-date tracking for a credit card (GitHub #91) — off
/// unless the user turns it on, same shape as [EnvelopeSection]'s own
/// per-account toggle. What's due is the last statement — the balance as
/// it closed, less what's come in since — and purchases after the close
/// show as the next statement building up (GitHub #183; see
/// [CardStatement]), beside what you owe in all right now.
class CreditCardStatementSection extends ConsumerWidget {
  const CreditCardStatementSection({required this.account, super.key});

  final AccountRow account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final detail = ref.watch(creditCardDetailsProvider(account.id)).valueOrNull;

    return AppCard(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSwitchListTile(
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
    final result = await showAppDialog<_CycleResult>(
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
    final confirmed = await showAppDialog<bool>(
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
    final statement = ref.watch(creditCardStatementProvider(account.id));
    final owed = account.currentBalance.abs;
    final day = DateFormat('d MMM');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (statement != null) ...[
            _amountRow(
              theme,
              'Statement, closed ${day.format(statement.closedOn)}',
              statement.statement,
            ),
            if (statement.paidSince.isPositive) ...[
              const SizedBox(height: 8),
              _amountRow(
                theme,
                'Paid since',
                statement.paidSince,
                color: AppColors.income,
              ),
            ],
            const SizedBox(height: 8),
            _leftToPay(theme, statement),
            const Divider(height: 28),
            _amountRow(
              theme,
              'Next statement so far · '
              '${day.format(period.start)} – ${day.format(period.end)}',
              statement.spentSince,
            ),
            const SizedBox(height: 8),
          ],
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

  /// The line that matters: what's left of the statement and by when — or
  /// that it's paid.
  Widget _leftToPay(ThemeData theme, CardStatement statement) {
    final cs = theme.colorScheme;
    if (statement.statement.isZero) {
      return Text(
        'Nothing was due on it',
        style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      );
    }
    final left = statement.leftToPay;
    if (left.isZero) {
      return Row(
        children: [
          AppIcon(
            Icons.check_circle_rounded,
            size: 18,
            color: AppColors.income,
          ),
          const SizedBox(width: 8),
          Text(
            'Paid in full',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.income,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    final today = DateTime.now();
    final daysLeft = statement.dueOn
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    return _amountRow(
      theme,
      'Left to pay · due ${DateFormat('d MMM').format(statement.dueOn)} '
      '(${_dueInLabel(daysLeft)})',
      left,
      bold: true,
    );
  }

  /// A label and its amount on one line — the label wraps first.
  Widget _amountRow(
    ThemeData theme,
    String label,
    Money amount, {
    Color? color,
    bool bold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: bold
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: bold ? FontWeight.w600 : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        MoneyText(
          amount,
          color: color ?? (bold ? AppColors.expense : null),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
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
/// `showDialog` resolves — see `_MinimumBalanceDialog` in
/// `accounts_screen.dart` for why that races the dialog's own closing
/// animation.
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
            AppListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Statement closes'),
              subtitle: Text('The ${_ordinal(_statementDay)} of each month'),
              trailing: const AppIcon(Icons.calendar_month_outlined),
              onTap: () => _pickDay(forStatement: true),
            ),
            AppListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Payment due'),
              subtitle: Text('The ${_ordinal(_dueDay)} of each month'),
              trailing: const AppIcon(Icons.calendar_month_outlined),
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
