import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/currency.dart';
import '../../core/money.dart';
import '../../core/widgets/amount_keypad_field.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../settings/currency_picker_sheet.dart';
import '../tags/tag_picker_sheet.dart';
import '../../core/l10n/l10n.dart';

/// Opens the add/edit sheet. Pass [existing] to edit that rule instead of
/// creating a new one, or [prefillFrom] to seed a new rule's fields from a
/// past transaction (GitHub #129) — ignored when [existing] is set.
/// [presetToAccountId] opens a new rule already on Transfer, paying into
/// that goal or loan, seeded with [presetAmount]/[presetName] — the goal and
/// loan screens' "Set up auto-save / auto-pay" shortcut.
Future<void> showRecurringRuleSheet(
  BuildContext context, {
  RecurringRuleRow? existing,
  TransactionRow? prefillFrom,
  int? presetToAccountId,
  Money? presetAmount,
  String? presetName,
}) {
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => RecurringRuleSheet(
      existing: existing,
      prefillFrom: prefillFrom,
      presetToAccountId: presetToAccountId,
      presetAmount: presetAmount,
      presetName: presetName,
    ),
  );
}

/// Create or edit an Auto rule — an income or expense that posts itself on a
/// schedule, with no confirmation step. A rule marked "amount varies" still
/// posts on schedule, using the entered amount as a placeholder, but flags
/// the result via [Transactions.needsAmountReview] so the user is nudged to
/// correct it. See [AppDatabase.runDueRecurringRules].
class RecurringRuleSheet extends ConsumerStatefulWidget {
  const RecurringRuleSheet({
    this.existing,
    this.prefillFrom,
    this.presetToAccountId,
    this.presetAmount,
    this.presetName,
    super.key,
  });

  final RecurringRuleRow? existing;

  /// A past transaction to seed a new rule's fields from. Ignored when
  /// [existing] is set — editing always wins.
  final TransactionRow? prefillFrom;

  /// A goal or loan account a new rule should pay into — opens on
  /// Transfer. Ignored when [existing] or [prefillFrom] is set.
  final int? presetToAccountId;
  final Money? presetAmount;
  final String? presetName;

  @override
  ConsumerState<RecurringRuleSheet> createState() => _RecurringRuleSheetState();
}

/// What a rule posts. [transfer] moves money to another of the person's own
/// accounts — cash, a bank, a card, a goal or a loan — instead of posting a
/// category-tagged income/expense.
enum _RuleKind { expense, income, transfer }

class _RecurringRuleSheetState extends ConsumerState<RecurringRuleSheet> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  final _amountController = AmountKeypadController();
  final _payeeController = TextEditingController();
  final _payeeFocus = FocusNode();
  final _noteController = TextEditingController();
  final _promoAmountController = AmountKeypadController();
  final _promoOccurrencesController = TextEditingController();
  final _foreignAmountController = AmountKeypadController();

  /// Coordinates the three money fields above so only one keypad is open at
  /// a time — same idea as one real `TextField`'s focus blurring another.
  final _amountGroup = AmountKeypadFieldGroup();

  _RuleKind _ruleKind = _RuleKind.expense;
  int? _accountId;
  int? _categoryId;
  int? _toAccountId;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  late DateTime _dueDate;
  double _notifyDays = 3;
  bool _isEstimate = false;
  bool _hasPromo = false;
  bool _submitting = false;
  Set<int> _tagIds = {};

  /// Same annotation as a transaction's own (GitHub #85) — "this is really a
  /// $9.99 subscription" — carried on the rule so every occurrence it posts
  /// keeps showing it. Not offered for a goal/loan rule: a transfer into a
  /// goal or loan has no external "cost" to record.
  bool _hasForeignCurrency = false;
  String? _foreignCurrencyCode;

  bool get _isEditing => widget.existing != null;

  /// The [CategoryKind] the database call needs — meaningless for
  /// [_RuleKind.transfer] (see [RecurringRules.kind]), so pinned to
  /// [CategoryKind.expense] there.
  CategoryKind get _kind => _ruleKind == _RuleKind.income
      ? CategoryKind.income
      : CategoryKind.expense;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) {
      _dueDate = DateTime.now();
      final source = widget.prefillFrom;
      if (source != null && source.type.isIncomeOrExpense) {
        _prefillFromTransaction(source);
      } else if (widget.presetToAccountId != null) {
        _ruleKind = _RuleKind.transfer;
        _toAccountId = widget.presetToAccountId;
        if (widget.presetAmount != null) {
          _amountController.setAmount(widget.presetAmount!);
        }
        if (widget.presetName != null) {
          _nameController.text = widget.presetName!;
        }
      }
      return;
    }
    _nameController.text = e.name;
    _amountController.setAmount(e.amount);
    _payeeController.text = e.payee ?? '';
    _noteController.text = e.note ?? '';
    _ruleKind = e.toAccountId != null
        ? _RuleKind.transfer
        : (e.kind == CategoryKind.income
              ? _RuleKind.income
              : _RuleKind.expense);
    _accountId = e.accountId;
    _categoryId = e.categoryId;
    _toAccountId = e.toAccountId;
    _frequency = e.frequency;
    _dueDate = e.nextDueDate;
    _notifyDays = e.notifyDaysBefore.toDouble();
    _isEstimate = e.isEstimate;
    _hasPromo = e.promoAmount != null;
    if (e.promoAmount != null) {
      _promoAmountController.setAmount(e.promoAmount!);
    }
    if (e.promoOccurrencesLeft != null) {
      _promoOccurrencesController.text = '${e.promoOccurrencesLeft}';
    }
    _hasForeignCurrency = e.foreignAmount != null;
    _foreignCurrencyCode = e.foreignCurrencyCode;
    if (e.foreignAmount != null) {
      _foreignAmountController.setAmount(e.foreignAmount!);
    }
    _loadTagIds(e.id);
  }

  /// Preset tags aren't on [RecurringRuleRow] itself (see
  /// `RecurringRuleTags`) — fetch them once, same shape as
  /// `AddTransactionScreen._loadForEdit` fetching a transaction's tags.
  Future<void> _loadTagIds(int ruleId) async {
    final ids = await ref.read(dbProvider).tagIdsForRecurringRule(ruleId);
    if (mounted) setState(() => _tagIds = ids.toSet());
  }

  /// Seeds a brand-new rule's fields from [t] (GitHub #129 — "turn this
  /// transaction into a recurring payment"). The due date is left at "now"
  /// (set by the caller) rather than derived from [t.date]: the source
  /// transaction may be old, and guessing the next occurrence from it is
  /// more likely to surprise than help — the user picks the real start date.
  void _prefillFromTransaction(TransactionRow t) {
    _ruleKind = t.type == TxType.income ? _RuleKind.income : _RuleKind.expense;
    _amountController.setAmount(t.amount);
    _accountId = t.accountId;
    _categoryId = t.categoryId;
    final payee = t.payee?.trim();
    if (payee != null && payee.isNotEmpty) {
      _payeeController.text = payee;
      _nameController.text = payee;
    } else {
      final category = ref.read(categoryMapProvider)[t.categoryId];
      _nameController.text =
          category?.name ??
          (t.type == TxType.income
              ? tr('Recurring money in')
              : tr('Recurring money out'));
    }
    final note = t.note?.trim();
    if (note != null && note.isNotEmpty) _noteController.text = note;
    _loadTransactionTagIds(t.id);
  }

  Future<void> _loadTransactionTagIds(int transactionId) async {
    final ids = await ref.read(dbProvider).tagIdsForTransaction(transactionId);
    if (mounted) setState(() => _tagIds = ids.toSet());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    _amountController.dispose();
    _payeeController.dispose();
    _payeeFocus.dispose();
    _noteController.dispose();
    _promoAmountController.dispose();
    _promoOccurrencesController.dispose();
    _foreignAmountController.dispose();
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
      initialDate: _dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError(tr('Give it a name.'));
      return;
    }
    final amount = Money.tryParse(_amountController.text);
    if (amount == null || !amount.isPositive) {
      _showError(tr('Enter an amount greater than zero.'));
      return;
    }
    final isTransfer = _ruleKind == _RuleKind.transfer;
    if (_accountId == null) {
      _showError(
        isTransfer ? tr('Choose a from account.') : tr('Choose an account.'),
      );
      return;
    }
    if (isTransfer) {
      if (_toAccountId == null) {
        _showError(tr('Choose where the money goes.'));
        return;
      }
    } else if (_categoryId == null) {
      _showError(tr('Choose a category.'));
      return;
    }
    final payeeText = _allowsPayee ? _payeeController.text.trim() : '';
    final payee = payeeText.isEmpty ? null : payeeText;
    final noteText = _noteController.text.trim();
    final note = noteText.isEmpty ? null : noteText;

    Money? promoAmount;
    int? promoOccurrences;
    if (_hasPromo) {
      promoAmount = Money.tryParse(_promoAmountController.text);
      // Zero is a valid promo price — a free trial period, not just a
      // discount (GitHub #87: e.g. a service free for the first N months).
      if (promoAmount == null || promoAmount.isNegative) {
        _showError(tr('Enter a valid promo amount.'));
        return;
      }
      promoOccurrences = int.tryParse(_promoOccurrencesController.text.trim());
      if (promoOccurrences == null || promoOccurrences < 1) {
        _showError(tr('Enter how many occurrences the promotion covers.'));
        return;
      }
    }

    String? foreignCurrencyCode;
    Money? foreignAmount;
    if (_hasForeignCurrency && !isTransfer) {
      foreignCurrencyCode = _foreignCurrencyCode;
      foreignAmount = Money.tryParse(_foreignAmountController.text);
      if (foreignCurrencyCode == null ||
          foreignAmount == null ||
          !foreignAmount.isPositive) {
        _showError(tr('Choose a currency and enter its amount.'));
        return;
      }
    }

    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_isEditing) {
        await ref
            .read(dbProvider)
            .updateRecurringRule(
              id: widget.existing!.id,
              name: name,
              kind: _kind,
              amount: amount,
              accountId: _accountId!,
              categoryId: _ruleCategoryId,
              toAccountId: isTransfer ? _toAccountId : null,
              payee: payee,
              note: note,
              frequency: _frequency,
              nextDueDate: _dueDate,
              notifyDaysBefore: _notifyDays.round(),
              isEstimate: _isEstimate,
              promoAmount: promoAmount,
              promoOccurrences: promoOccurrences,
              tagIds: _tagIds,
              foreignCurrencyCode: foreignCurrencyCode,
              foreignAmount: foreignAmount,
            );
      } else {
        await ref
            .read(dbProvider)
            .addRecurringRule(
              name: name,
              kind: _kind,
              amount: amount,
              accountId: _accountId!,
              categoryId: _ruleCategoryId,
              toAccountId: isTransfer ? _toAccountId : null,
              payee: payee,
              note: note,
              frequency: _frequency,
              startsOn: _dueDate,
              notifyDaysBefore: _notifyDays.round(),
              isEstimate: _isEstimate,
              promoAmount: promoAmount,
              promoOccurrences: promoOccurrences,
              tagIds: _tagIds,
              foreignCurrencyCode: foreignCurrencyCode,
              foreignAmount: foreignAmount,
            );
      }
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(e.message?.toString() ?? tr('Could not save.'));
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(tr('Could not save.'));
      return;
    }
    // A due date today or earlier would otherwise wait for the next app
    // resume to post — catch up now so a backdated rule's history shows up
    // straight away.
    final now = DateTime.now();
    final posted = _dueDate.isAfter(DateTime(now.year, now.month, now.day))
        ? 0
        : await ref.read(dbProvider).runDueRecurringRules();
    navigator.pop();
    if (posted > 0) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              posted == 1
                  ? tr('1 past payment posted')
                  : tr('{0} past payments posted', [posted]),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isTransfer = _ruleKind == _RuleKind.transfer;
    final allAccounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    // [_allowsPayee] reads loan rates — rebuild once they've loaded.
    ref.watch(loanDetailsProvider);
    // A goal/loan is not a spendable/depositable account — an expense/income
    // rule (or the "from" side of a transfer rule) never posts against one;
    // only a transfer can. A goal with "Show in Money in / out" on (#173)
    // is the exception for an expense/income rule.
    final moneyInOutGoals = ref.watch(moneyInOutGoalIdsProvider);
    final fromAccounts = allAccounts
        .where(
          (a) => isTransfer
              ? a.type != AccountType.goal && a.type != AccountType.loan
              : takesMoneyInOut(a, moneyInOutGoals),
        )
        .toList();
    // A rule saved before loan accounts were excluded here may still point
    // at one — keep it selectable in its own dropdown rather than crashing
    // on a value with no matching item.
    if (_accountId != null && !fromAccounts.any((a) => a.id == _accountId)) {
      final stale = allAccounts.where((a) => a.id == _accountId);
      fromAccounts.addAll(stale);
    }
    // Any other account of the person's — never the source itself, and
    // never a debit card/UPI instrument, which holds no money of its own.
    final toAccounts = allAccounts
        .where((a) => a.id != _accountId && a.linkedAccountId == null)
        .toList();
    final toGoalOrLoan = _toGoalOrLoan;
    final categories = !isTransfer
        ? ref.watch(categoriesProvider(_kind)).valueOrNull ?? const []
        : toGoalOrLoan
        ? [
            ...ref
                    .watch(categoriesProvider(CategoryKind.expense))
                    .valueOrNull ??
                const [],
            ...ref.watch(categoriesProvider(CategoryKind.income)).valueOrNull ??
                const [],
          ]
        // A transfer between everyday accounts has no category.
        : const <CategoryRow>[];
    final categoryMap = ref.watch(categoryMapProvider);

    // The chosen category may no longer match the kind after toggling —
    // clear it rather than silently keep an invalid id selected.
    if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _categoryId = null);
      });
    }
    // The chosen destination may be gone (deleted, archived) or have become
    // the source — clear it the same way.
    if (_toAccountId != null && !toAccounts.any((a) => a.id == _toAccountId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _toAccountId = null);
      });
    }

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
              _isEditing ? tr('Edit auto rule') : tr('New auto rule'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<_RuleKind>(
              segments: const [
                ButtonSegment(value: _RuleKind.expense, label: Tr('Money out')),
                ButtonSegment(value: _RuleKind.income, label: Tr('Money in')),
                ButtonSegment(value: _RuleKind.transfer, label: Tr('Transfer')),
              ],
              selected: {_ruleKind},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _ruleKind = s.first),
            ),
            if (isTransfer) ...[
              const SizedBox(height: 6),
              Tr(
                'Moves money between your own accounts on schedule — to '
                'cash, onto a credit card, into a goal or towards a loan.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              focusNode: _nameFocus,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: tr('Name'),
                hintText: isTransfer
                    ? tr('e.g. Savings, Card bill, Car Loan EMI')
                    : (_kind == CategoryKind.expense
                          ? tr('e.g. Netflix, Rent')
                          : tr('e.g. Salary')),
              ),
            ),
            const SizedBox(height: 16),
            AmountKeypadField(
              controller: _amountController,
              group: _amountGroup,
              yieldTo: [_nameFocus],
              label: (_isEstimate || _hasPromo)
                  ? tr('Usual amount')
                  : tr('Amount'),
            ),
            if (_isEstimate) ...[
              const SizedBox(height: 4),
              Tr(
                "You'll be nudged to confirm the exact figure each time it "
                'posts.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            AppSwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Tr('Amount varies each time'),
              subtitle: const Tr(
                'For a salary or bill that changes, e.g. by hours worked.',
              ),
              value: _isEstimate,
              onChanged: (v) => setState(() => _isEstimate = v),
            ),
            AppSwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Tr('Add a promotion'),
              subtitle: const Tr(
                'A discounted price for the next few occurrences, then back '
                'to the usual amount automatically.',
              ),
              value: _hasPromo,
              onChanged: (v) => setState(() => _hasPromo = v),
            ),
            if (_hasPromo) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: AmountKeypadField(
                      controller: _promoAmountController,
                      group: _amountGroup,
                      yieldTo: [_nameFocus],
                      label: tr('Promo amount'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _promoOccurrencesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: tr('Occurrences'),
                        hintText: 'e.g. 3',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (!isTransfer) ...[
              AppSwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Tr('Foreign currency'),
                subtitle: const Tr(
                  'Record what this really costs in another currency.',
                ),
                value: _hasForeignCurrency,
                onChanged: (v) => setState(() => _hasForeignCurrency = v),
              ),
              if (_hasForeignCurrency) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await CurrencyPickerSheet.pick(
                            context,
                            initialCode:
                                _foreignCurrencyCode ??
                                MoneyFormat.currency.code,
                          );
                          if (picked == null || !mounted) return;
                          setState(() => _foreignCurrencyCode = picked.code);
                        },
                        child: Text(currencyForCode(_foreignCurrencyCode).code),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AmountKeypadField(
                        controller: _foreignAmountController,
                        group: _amountGroup,
                        yieldTo: [_nameFocus],
                        label: tr('Foreign amount'),
                        // The currency chip to the left already shows which
                        // currency this is — showing the home currency's
                        // symbol here too would be misleading.
                        showPrefix: false,
                      ),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              initialValue: _accountId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: isTransfer ? tr('From account') : tr('Account'),
              ),
              items: [
                for (final a in fromAccounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            if (isTransfer) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                // Keyed by the source: picking it as the source drops it
                // from this list, so the field must rebuild without it.
                key: ValueKey('to-$_accountId'),
                initialValue: toAccounts.any((a) => a.id == _toAccountId)
                    ? _toAccountId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: tr('To account')),
                items: [
                  for (final a in toAccounts)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text(_destinationLabel(a)),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _toAccountId = v;
                  _suggestFromTarget(v);
                }),
              ),
            ],
            // Every expense/income rule has a category; a transfer only
            // optionally, and only into a goal or loan.
            if (!isTransfer || toGoalOrLoan) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: categories.any((c) => c.id == _categoryId)
                    ? _categoryId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: isTransfer
                      ? tr('Category (optional)')
                      : tr('Category'),
                ),
                items: [
                  if (isTransfer)
                    const DropdownMenuItem(value: null, child: Tr('None')),
                  for (final c in categories)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(_categoryLabel(c, categoryMap)),
                    ),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
            ],
            if (_allowsPayee) ...[
              const SizedBox(height: 16),
              _payeeField(theme),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: tr('Notes (optional)'),
                hintText: tr(
                  'Why this rule exists, or anything else worth noting',
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            _tagsField(theme),
            const SizedBox(height: 20),
            // Five segments can outgrow a narrow phone or a larger system
            // font scale — scroll rather than let it overflow (GitHub #14).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<RecurringFrequency>(
                segments: const [
                  ButtonSegment(
                    value: RecurringFrequency.daily,
                    label: Tr('Daily'),
                  ),
                  ButtonSegment(
                    value: RecurringFrequency.weekly,
                    label: Tr('Weekly'),
                  ),
                  ButtonSegment(
                    value: RecurringFrequency.biweekly,
                    label: Tr('2 weeks'),
                  ),
                  ButtonSegment(
                    value: RecurringFrequency.monthly,
                    label: Tr('Monthly'),
                  ),
                  // The engine always scheduled yearly rules (anchored to the
                  // start date's month and day); the picker just never
                  // offered it (GitHub #197).
                  ButtonSegment(
                    value: RecurringFrequency.yearly,
                    label: Tr('Yearly'),
                  ),
                ],
                selected: {_frequency},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _frequency = s.first),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    AppIcon(Icons.event_rounded, color: cs.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? tr('Next due date') : tr('Starts on'),
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
                    AppIcon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (_frequency == RecurringFrequency.monthly)
              Text(
                tr(
                  'A shorter month snaps to its last day, then returns to the '
                  '{0}{1} once it exists again.',
                  [_dueDate.day, _ordinalSuffix(_dueDate.day)],
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            if (_frequency == RecurringFrequency.yearly)
              Text(
                tr(
                  'Repeats every {0}.'
                  '{1}',
                  [
                    DateFormat('d MMMM').format(_dueDate),
                    _dueDate.month == 2 && _dueDate.day == 29
                        ? tr(' In a year without Feb 29 it posts on Feb 28.')
                        : '',
                  ],
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              tr(
                'Notify me {0} '
                'day{1} before',
                [_notifyDays.round(), _notifyDays.round() == 1 ? '' : 's'],
              ),
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
              onPressed: _submitting ? null : _save,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(_isEditing ? tr('Save changes') : tr('Create rule')),
            ),
          ],
        ),
      ),
    );
  }

  /// Whether the transfer's destination is a goal or loan — the only kind
  /// that can carry a category, and (a loan) an interest payee.
  bool get _toGoalOrLoan {
    final type = ref.read(accountMapProvider)[_toAccountId]?.type;
    return type == AccountType.goal || type == AccountType.loan;
  }

  /// The category actually saved: none for a transfer between everyday
  /// accounts, whatever was picked before switching.
  int? get _ruleCategoryId =>
      _ruleKind == _RuleKind.transfer && !_toGoalOrLoan ? null : _categoryId;

  /// A destination's name, with what kind of account it is when that's not
  /// obvious from the name alone.
  String _destinationLabel(AccountRow a) => switch (a.type) {
    AccountType.goal => tr('{0} · Goal', [a.name]),
    AccountType.loan => tr('{0} · Loan', [a.name]),
    AccountType.card => tr('{0} · Card', [a.name]),
    AccountType.payLater => tr('{0} · Pay later', [a.name]),
    _ => a.name,
  };

  /// Picking a loan with a known EMI (or a goal) for a rule that has no
  /// amount/name yet fills them in — the obvious values, still editable.
  void _suggestFromTarget(int? accountId) {
    if (accountId == null) return;
    final account = ref.read(accountMapProvider)[accountId];
    if (account == null) return;
    if (account.type != AccountType.goal && account.type != AccountType.loan) {
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = 'To ${account.name}';
      }
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      _nameController.text = account.type == AccountType.loan
          ? '${account.name} EMI'
          : account.name;
    }
    if (_amountController.text.trim().isEmpty &&
        account.type == AccountType.loan) {
      final emi = ref.read(loanProgressProvider(accountId))?.emi;
      if (emi != null) _amountController.setAmount(emi);
    }
  }

  /// A payee only ever lands on an income/expense. An ordinary rule posts
  /// one; a loan rule posts one only as the interest leg of a rate-based
  /// EMI split — a plain transfer can't carry a payee, and a goal has no
  /// one to pay.
  bool get _allowsPayee {
    if (_ruleKind != _RuleKind.transfer) return true;
    return _isRateLoan;
  }

  bool get _isRateLoan {
    final id = _toAccountId;
    if (id == null) return false;
    if (ref.read(accountMapProvider)[id]?.type != AccountType.loan) {
      return false;
    }
    return ref.read(loanDetailProvider(id))?.interestRatePct != null;
  }

  Widget _payeeField(ThemeData theme) {
    final suggestions = ref.watch(payeeSuggestionsProvider);
    final forLoan = _ruleKind == _RuleKind.transfer;
    return Autocomplete<String>(
      textEditingController: _payeeController,
      focusNode: _payeeFocus,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return suggestions.where((s) => s.toLowerCase().contains(q));
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: tr('Payee (optional)'),
            hintText: forLoan
                ? tr('The lender, e.g. your bank')
                : (_kind == CategoryKind.income
                      ? tr('Who pays you?')
                      : tr('Who gets paid?')),
            helperText: forLoan
                ? tr('Set on the interest part of each EMI')
                : null,
          ),
        );
      },
    );
  }

  /// Preset tags every posting of this rule gets stamped with automatically
  /// — see GitHub #63 and `AppDatabase.runDueRecurringRules`.
  Widget _tagsField(ThemeData theme) {
    final cs = theme.colorScheme;
    final tagMap = ref.watch(tagMapProvider);
    final selected = [
      for (final id in _tagIds)
        if (tagMap[id] != null) tagMap[id]!,
    ]..sort((a, b) => a.name.compareTo(b.name));

    return InkWell(
      onTap: _pickTags,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(Icons.sell_outlined, color: cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tr(
                    'Tags (optional)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (selected.isEmpty)
                    Tr(
                      'Stamped on every transaction this rule posts',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in selected)
                          Chip(
                            label: Text(tag.name),
                            backgroundColor: Color(
                              tag.colorValue,
                            ).withValues(alpha: 0.15),
                            labelStyle: TextStyle(color: Color(tag.colorValue)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide.none,
                          ),
                      ],
                    ),
                ],
              ),
            ),
            AppIcon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTags() async {
    final result = await showAppSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TagPickerSheet(initiallySelected: _tagIds),
    );
    if (result == null || !mounted) return;
    setState(() => _tagIds = result);
  }

  String _categoryLabel(CategoryRow c, Map<int, CategoryRow> byId) {
    if (c.parentId == null) return c.name;
    final parent = byId[c.parentId];
    return parent == null ? c.name : '${parent.name} › ${c.name}';
  }

  static String _ordinalSuffix(int day) {
    // English only; other languages write the plain number.
    if (L10n.code != 'en') return '';
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
