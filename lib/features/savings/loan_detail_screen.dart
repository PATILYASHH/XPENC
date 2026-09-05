import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'savings_goals_screen.dart';

/// One loan: outstanding balance, original amount, repayment progress, and a
/// "Make a payment" shortcut that posts an ordinary transfer into the loan
/// account. [accountId] is the loan's own account id.
class LoanDetailScreen extends ConsumerWidget {
  const LoanDetailScreen({required this.accountId, super.key});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loan = ref.watch(loanProgressProvider(accountId));

    if (loan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loan')),
        body: const Center(child: Text('Loan not found')),
      );
    }

    final account = loan.account;
    final detail = loan.detail;
    final theme = Theme.of(context);
    final color = Color(account.colorValue);
    final isPaidOff = loan.outstanding.isZero;

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => openLoanEditor(context, loan),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More',
            onPressed: () => _showActions(context, ref, loan),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: loan.fraction,
                      strokeWidth: 12,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      color: color,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppIcons.resolve(account.iconKey), color: color, size: 28),
                      const SizedBox(height: 6),
                      Text(
                        '${(loan.fraction * 100).round()}%',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'paid',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: isPaidOff
                      ? null
                      : () => _openPaymentSheet(
                            context,
                            loanAccountId: accountId,
                            defaultCategoryId: detail.categoryId,
                            emiAmount: detail.emiAmount,
                          ),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Make a payment'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Column(
                children: [
                  _row(
                    context,
                    'Outstanding',
                    MoneyText(loan.outstanding, color: AppColors.expense),
                  ),
                  _divider(theme),
                  _row(
                    context,
                    'Original amount',
                    _plainValue(context, MoneyFormat.symbol(loan.principal)),
                  ),
                  _divider(theme),
                  _row(
                    context,
                    'Paid so far',
                    _plainValue(
                      context,
                      MoneyFormat.symbol(loan.principal - loan.outstanding),
                      color: AppColors.income,
                    ),
                  ),
                  if (detail.emiAmount != null) ...[
                    _divider(theme),
                    _row(
                      context,
                      'Monthly EMI',
                      _plainValue(context, MoneyFormat.symbol(detail.emiAmount!)),
                    ),
                  ],
                  if (isPaidOff) ...[
                    _divider(theme),
                    _row(
                      context,
                      'Status',
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: AppColors.income, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Paid off',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.income,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, Widget value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );
  }

  Widget _plainValue(BuildContext context, String text, {Color? color}) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );
  }

  Widget _divider(ThemeData theme) =>
      Divider(height: 1, color: theme.colorScheme.outline);

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    LoanProgress loan,
  ) async {
    final action = await showModalBottomSheet<_LoanAction>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              subtitle: const Text(
                'Hides it from active loans. Its history stays.',
              ),
              onTap: () => Navigator.of(sheetContext).pop(_LoanAction.archive),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
              ),
              subtitle: const Text(
                'Only for a loan with no payment history yet.',
              ),
              onTap: () => Navigator.of(sheetContext).pop(_LoanAction.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == _LoanAction.archive) {
      await _confirmArchive(context, ref, loan);
    } else {
      await _confirmDelete(context, ref, loan);
    }
  }

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    LoanProgress loan,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Archive "${loan.account.name}"?'),
        content: const Text(
          "It stays in your history and net worth — this only hides it from "
          'the active loans list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(dbProvider).archiveAccount(loan.account.id);
    if (!navigator.mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Loan archived')));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LoanProgress loan,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${loan.account.name}"?'),
        content: const Text(
          'Permanent. A loan that has had payments refuses to delete — '
          'archive it instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    bool rtaAutoDisabled;
    try {
      rtaAutoDisabled = await ref.read(dbProvider).deleteAccount(loan.account.id);
    } on ArgumentError catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(e.message?.toString() ?? 'Could not delete.')),
        );
      return;
    }
    if (!navigator.mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            rtaAutoDisabled
                ? 'Loan deleted. Ready to Assign turned off — no accounts '
                      'left in the pool.'
                : 'Loan deleted',
          ),
        ),
      );
  }
}

enum _LoanAction { archive, delete }

void _openPaymentSheet(
  BuildContext context, {
  required int loanAccountId,
  int? defaultCategoryId,
  Money? emiAmount,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _LoanPaymentSheet(
      loanAccountId: loanAccountId,
      defaultCategoryId: defaultCategoryId,
      emiAmount: emiAmount,
    ),
  );
}

class _LoanPaymentSheet extends ConsumerStatefulWidget {
  const _LoanPaymentSheet({
    required this.loanAccountId,
    this.defaultCategoryId,
    this.emiAmount,
  });

  final int loanAccountId;
  final int? defaultCategoryId;
  final Money? emiAmount;

  @override
  ConsumerState<_LoanPaymentSheet> createState() => _LoanPaymentSheetState();
}

class _LoanPaymentSheetState extends ConsumerState<_LoanPaymentSheet> {
  late final TextEditingController _amountController;
  int? _sourceAccountId;
  late int? _categoryId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.defaultCategoryId;
    _amountController = TextEditingController(
      text: widget.emiAmount == null ? '' : MoneyFormat.bare(widget.emiAmount!),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final amount = Money.tryParse(_amountController.text);
    if (amount == null || !amount.isPositive) {
      _showError('Enter an amount greater than zero.');
      return;
    }
    final sourceId = _sourceAccountId;
    if (sourceId == null) {
      _showError('Choose a source account.');
      return;
    }

    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
    try {
      await ref.read(dbProvider).addTransaction(
            type: TxType.transfer,
            accountId: sourceId,
            toAccountId: widget.loanAccountId,
            amount: amount,
            date: DateTime.now(),
            categoryId: _categoryId,
          );
      if (!mounted) return;
      navigator.pop();
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(e.message?.toString() ?? 'Could not save.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Could not save.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts =
        (ref.watch(balanceAccountsProvider).valueOrNull ?? const [])
            .where(
              (a) =>
                  a.id != widget.loanAccountId &&
                  a.type != AccountType.goal &&
                  a.type != AccountType.loan,
            )
            .toList();
    final categories = [
      ...ref.watch(categoriesProvider(CategoryKind.expense)).valueOrNull ?? [],
      ...ref.watch(categoriesProvider(CategoryKind.income)).valueOrNull ?? [],
    ];

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
          Text(
            'Make a payment',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<int>(
            initialValue: _sourceAccountId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'From'),
            items: [
              for (final a in accounts)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (v) => setState(() => _sourceAccountId = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: MoneyFormat.inputPrefix,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            initialValue: _categoryId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category (optional)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('None')),
              for (final c in categories)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _save,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Text('Make a payment'),
          ),
        ],
      ),
    );
  }
}
