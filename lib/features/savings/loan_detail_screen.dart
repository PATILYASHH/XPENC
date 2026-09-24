import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/loan_amortization.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/amount_keypad_field.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/transaction_history.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../add_transaction/date_time_combine.dart';
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
    final txAsync = ref.watch(accountTransactionsProvider(accountId));
    final accountMap = ref.watch(accountMapProvider);
    final categoryMap = ref.watch(categoryMapProvider);

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
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: color,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.resolve(account.iconKey),
                        color: color,
                        size: 28,
                      ),
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
                      : () => _openPaymentSheet(context, loan: loan),
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
                  if (loan.totalInterestPaid.isPositive) ...[
                    _divider(theme),
                    _row(
                      context,
                      'Interest paid',
                      _plainValue(
                        context,
                        MoneyFormat.symbol(loan.totalInterestPaid),
                        color: AppColors.expense,
                      ),
                    ),
                  ],
                  if (detail.interestRatePct != null) ...[
                    _divider(theme),
                    _row(
                      context,
                      'Interest rate',
                      _plainValue(
                        context,
                        '${_formatRate(detail.interestRatePct!)}% / yr',
                      ),
                    ),
                  ],
                  if (loan.emi != null) ...[
                    _divider(theme),
                    _row(
                      context,
                      'Monthly EMI',
                      _plainValue(context, MoneyFormat.symbol(loan.emi!)),
                    ),
                  ],
                  if (!isPaidOff &&
                      loan.nextInterest != null &&
                      loan.nextPrincipal != null) ...[
                    _divider(theme),
                    _row(
                      context,
                      'Next payment',
                      _plainValue(
                        context,
                        '${MoneyFormat.symbol(loan.nextInterest!)} interest + '
                        '${MoneyFormat.symbol(loan.nextPrincipal!)} principal',
                      ),
                    ),
                  ],
                  if (loan.totalInterestScheduled != null) ...[
                    _divider(theme),
                    _row(
                      context,
                      'Total interest',
                      _plainValue(
                        context,
                        MoneyFormat.symbol(loan.totalInterestScheduled!),
                      ),
                    ),
                  ],
                  if (loan.totalPayableScheduled != null) ...[
                    _divider(theme),
                    _row(
                      context,
                      'Total payable',
                      _plainValue(
                        context,
                        MoneyFormat.symbol(loan.totalPayableScheduled!),
                      ),
                    ),
                  ],
                  if (loan.interestSaved != null) ...[
                    _divider(theme),
                    _row(
                      context,
                      "You're saving",
                      _plainValue(
                        context,
                        loan.monthsSaved != null && loan.monthsSaved! > 0
                            ? '~${MoneyFormat.symbol(loan.interestSaved!)} '
                                  '(~${loan.monthsSaved} months)'
                            : '~${MoneyFormat.symbol(loan.interestSaved!)}',
                        color: AppColors.income,
                      ),
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
                          Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.income,
                            size: 18,
                          ),
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
          const SizedBox(height: 28),
          Text(
            'History',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          TransactionHistorySection(
            txAsync: txAsync,
            accountMap: accountMap,
            categoryMap: categoryMap,
            ownIds: {accountId},
            currency: null,
            emptyMessage: 'No payments yet.',
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
      rtaAutoDisabled = await ref
          .read(dbProvider)
          .deleteAccount(loan.account.id);
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

/// `8.5` stays `8.5`, `8.0` becomes `8`.
String _formatRate(double rate) {
  return rate == rate.roundToDouble()
      ? rate.toStringAsFixed(0)
      : rate.toString();
}

void _openPaymentSheet(BuildContext context, {required LoanProgress loan}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _LoanPaymentSheet(loan: loan),
  );
}

class _LoanPaymentSheet extends ConsumerStatefulWidget {
  const _LoanPaymentSheet({required this.loan});

  final LoanProgress loan;

  @override
  ConsumerState<_LoanPaymentSheet> createState() => _LoanPaymentSheetState();
}

class _LoanPaymentSheetState extends ConsumerState<_LoanPaymentSheet> {
  final _amountController = AmountKeypadController();
  final _interestController = AmountKeypadController();
  final _amountGroup = AmountKeypadFieldGroup();
  int? _sourceAccountId;
  late int? _categoryId;
  DateTime _date = DateTime.now();
  bool _submitting = false;

  /// Once the user types into the interest field themselves, the rate-based
  /// estimate stops overwriting it — e.g. to match what the bank statement
  /// actually charged this cycle.
  bool _interestEditedByUser = false;
  bool _autoFilling = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.loan.detail.categoryId;
    final emi = widget.loan.emi;
    if (emi != null) _amountController.setAmount(emi);
    _amountController.addListener(_onAmountChanged);
    _interestController.addListener(_onInterestChanged);
    _applyInterestEstimate();
  }

  void _onAmountChanged() {
    _applyInterestEstimate();
    setState(() {});
  }

  void _onInterestChanged() {
    if (!_autoFilling) _interestEditedByUser = true;
    setState(() {});
  }

  /// Suggests this period's interest from the loan's own rate — see
  /// [LoanAmortization.periodInterest] — whenever there's a rate to work
  /// from and the user hasn't already overridden the field. A loan with no
  /// rate leaves the field exactly as manual as it's always been.
  void _applyInterestEstimate() {
    final rate = widget.loan.detail.interestRatePct;
    if (rate == null || _interestEditedByUser) return;
    final amount = Money.tryParse(_amountController.text);
    if (amount == null || !amount.isPositive) return;
    var estimate = LoanAmortization.periodInterest(
      outstandingPrincipal: widget.loan.outstanding,
      annualRatePct: rate,
    );
    if (estimate.paise > amount.paise) estimate = amount;
    _autoFilling = true;
    _interestController.setAmount(estimate);
    _autoFilling = false;
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _interestController.removeListener(_onInterestChanged);
    _interestController.dispose();
    _amountGroup.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _date = combineDateAndTime(picked, TimeOfDay.fromDateTime(_date)),
    );
  }

  /// Optional — most payments are logged the day they happen. Lets a loan
  /// with years of history (its first payment long before this feature
  /// existed) be backfilled at its real dates instead of everything
  /// landing on "now".
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = combineDateAndTime(_date, picked));
  }

  bool get _hasInterest => _interestController.text.trim().isNotEmpty;

  /// The portion left to reduce the loan once interest is taken out —
  /// clamped at zero for display only; [_save] does the real validation.
  Money get _principalPreview {
    final amount = Money.tryParse(_amountController.text) ?? const Money.zero();
    final interest =
        Money.tryParse(_interestController.text) ?? const Money.zero();
    final remaining = amount.paise - interest.paise;
    return remaining > 0 ? Money.fromPaise(remaining) : const Money.zero();
  }

  /// What a normal EMI would reduce the loan by this cycle, per the loan's
  /// own amortization schedule — `null` for a loan with no rate, where
  /// there's no schedule to compare a payment against.
  Money? get _scheduledPrincipal => widget.loan.nextPrincipal;

  /// How much of [_principalPreview] is *beyond* [_scheduledPrincipal] — a
  /// voluntary prepayment, not just this cycle's normal EMI. Zero whenever
  /// there's no schedule to compare against, or the payment doesn't exceed
  /// it.
  Money get _extraPrincipal {
    final scheduled = _scheduledPrincipal;
    if (scheduled == null) return const Money.zero();
    final extra = _principalPreview.paise - scheduled.paise;
    return extra > 0 ? Money.fromPaise(extra) : const Money.zero();
  }

  String _paymentHint() {
    if (!_hasInterest) {
      return 'Split out the interest part of an EMI — it posts as an '
          'expense instead of reducing the loan balance.';
    }
    final scheduled = _scheduledPrincipal;
    final principalText = scheduled != null && _extraPrincipal.isPositive
        ? '${MoneyFormat.symbol(scheduled)} scheduled + '
              '${MoneyFormat.symbol(_extraPrincipal)} extra'
        : MoneyFormat.symbol(_principalPreview);
    final estimated =
        widget.loan.detail.interestRatePct != null && !_interestEditedByUser;
    return estimated
        ? "Estimated from the loan's rate — edit to match your statement. "
              'Only $principalText reduces the loan.'
        : 'Interest posts as a real expense; only the rest ($principalText) '
              'reduces the loan.';
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
    Money? interest;
    if (_hasInterest) {
      interest = Money.tryParse(_interestController.text);
      if (interest == null || !interest.isPositive) {
        _showError('Interest must be greater than zero, or leave it blank.');
        return;
      }
      if (interest.paise > amount.paise) {
        _showError('Interest cannot be more than the total payment.');
        return;
      }
      if (_categoryId == null) {
        _showError('Pick a category for the interest portion.');
        return;
      }
    }

    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(dbProvider)
          .addLoanPayment(
            sourceAccountId: sourceId,
            loanAccountId: widget.loan.account.id,
            amount: amount,
            interestAmount: interest,
            interestCategoryId: interest != null ? _categoryId : null,
            transferCategoryId: interest == null ? _categoryId : null,
            date: _date,
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
                  a.id != widget.loan.account.id &&
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
      child: SingleChildScrollView(
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
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('d MMM yyyy, h:mm a').format(_date),
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Change time',
                      icon: Icon(
                        Icons.access_time_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: _pickTime,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
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
            AmountKeypadField(
              controller: _amountController,
              group: _amountGroup,
              autofocus: true,
              label: 'Amount',
              yieldTo: const [],
            ),
            const SizedBox(height: 16),
            AmountKeypadField(
              controller: _interestController,
              group: _amountGroup,
              label: 'Interest (optional)',
              hintText: '0.00',
              yieldTo: const [],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
              child: Text(
                _paymentHint(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: _categoryId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _hasInterest
                    ? 'Interest category'
                    : 'Category (optional)',
                helperText: _hasInterest
                    ? 'Required — tags the interest expense.'
                    : null,
              ),
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
      ),
    );
  }
}
