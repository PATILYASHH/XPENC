import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/currency.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../settings/currency_picker_sheet.dart';
import '../tags/tag_picker_sheet.dart';

/// Opens the add/edit sheet. Pass [existing] to edit that rule instead of
/// creating a new one.
Future<void> showRecurringRuleSheet(
  BuildContext context, {
  RecurringRuleRow? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => RecurringRuleSheet(existing: existing),
  );
}

/// Create or edit an Auto rule — an income or expense that posts itself on a
/// schedule, with no confirmation step. A rule marked "amount varies" still
/// posts on schedule, using the entered amount as a placeholder, but flags
/// the result via [Transactions.needsAmountReview] so the user is nudged to
/// correct it. See [AppDatabase.runDueRecurringRules].
class RecurringRuleSheet extends ConsumerStatefulWidget {
  const RecurringRuleSheet({this.existing, super.key});

  final RecurringRuleRow? existing;

  @override
  ConsumerState<RecurringRuleSheet> createState() => _RecurringRuleSheetState();
}

/// What a rule posts. [goalOrLoan] is the "G&L" option — a transfer into a
/// goal or loan account instead of a category-tagged income/expense.
enum _RuleKind { expense, income, goalOrLoan }

class _RecurringRuleSheetState extends ConsumerState<RecurringRuleSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _payeeController = TextEditingController();
  final _payeeFocus = FocusNode();
  final _noteController = TextEditingController();
  final _promoAmountController = TextEditingController();
  final _promoOccurrencesController = TextEditingController();
  final _foreignAmountController = TextEditingController();

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
  /// [_RuleKind.goalOrLoan] (see [RecurringRules.kind]), so pinned to
  /// [CategoryKind.expense] there.
  CategoryKind get _kind =>
      _ruleKind == _RuleKind.income ? CategoryKind.income : CategoryKind.expense;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) {
      _dueDate = DateTime.now();
      return;
    }
    _nameController.text = e.name;
    _amountController.text = _bufferFromMoney(e.amount);
    _payeeController.text = e.payee ?? '';
    _noteController.text = e.note ?? '';
    _ruleKind = e.toAccountId != null
        ? _RuleKind.goalOrLoan
        : (e.kind == CategoryKind.income ? _RuleKind.income : _RuleKind.expense);
    _accountId = e.accountId;
    _categoryId = e.categoryId;
    _toAccountId = e.toAccountId;
    _frequency = e.frequency;
    _dueDate = e.nextDueDate;
    _notifyDays = e.notifyDaysBefore.toDouble();
    _isEstimate = e.isEstimate;
    _hasPromo = e.promoAmount != null;
    if (e.promoAmount != null) {
      _promoAmountController.text = _bufferFromMoney(e.promoAmount!);
    }
    if (e.promoOccurrencesLeft != null) {
      _promoOccurrencesController.text = '${e.promoOccurrencesLeft}';
    }
    _hasForeignCurrency = e.foreignAmount != null;
    _foreignCurrencyCode = e.foreignCurrencyCode;
    if (e.foreignAmount != null) {
      _foreignAmountController.text = _bufferFromMoney(e.foreignAmount!);
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

  static String _bufferFromMoney(Money amount) {
    final paise = amount.abs.paise;
    final rupees = paise ~/ 100;
    final fraction = paise % 100;
    if (fraction == 0) return '$rupees';
    return '$rupees.${fraction.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _payeeController.dispose();
    _payeeFocus.dispose();
    _noteController.dispose();
    _promoAmountController.dispose();
    _promoOccurrencesController.dispose();
    _foreignAmountController.dispose();
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
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Give it a name.');
      return;
    }
    final amount = Money.tryParse(_amountController.text);
    if (amount == null || !amount.isPositive) {
      _showError('Enter an amount greater than zero.');
      return;
    }
    final isGoalOrLoan = _ruleKind == _RuleKind.goalOrLoan;
    if (_accountId == null) {
      _showError(isGoalOrLoan ? 'Choose a from account.' : 'Choose an account.');
      return;
    }
    if (isGoalOrLoan) {
      if (_toAccountId == null) {
        _showError('Choose a goal or loan.');
        return;
      }
    } else if (_categoryId == null) {
      _showError('Choose a category.');
      return;
    }
    final payeeText = isGoalOrLoan ? '' : _payeeController.text.trim();
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
        _showError('Enter a valid promo amount.');
        return;
      }
      promoOccurrences = int.tryParse(_promoOccurrencesController.text.trim());
      if (promoOccurrences == null || promoOccurrences < 1) {
        _showError('Enter how many occurrences the promotion covers.');
        return;
      }
    }

    String? foreignCurrencyCode;
    Money? foreignAmount;
    if (_hasForeignCurrency && !isGoalOrLoan) {
      foreignCurrencyCode = _foreignCurrencyCode;
      foreignAmount = Money.tryParse(_foreignAmountController.text);
      if (foreignCurrencyCode == null ||
          foreignAmount == null ||
          !foreignAmount.isPositive) {
        _showError('Choose a currency and enter its amount.');
        return;
      }
    }

    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
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
              categoryId: _categoryId,
              toAccountId: isGoalOrLoan ? _toAccountId : null,
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
              categoryId: _categoryId,
              toAccountId: isGoalOrLoan ? _toAccountId : null,
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
      _showError(e.message?.toString() ?? 'Could not save.');
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Could not save.');
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isGoalOrLoan = _ruleKind == _RuleKind.goalOrLoan;
    final allAccounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    // A goal/loan is not a spendable/depositable account — an expense/income
    // rule (or the "from" side of a G&L rule) never posts against one; only
    // a transfer can.
    final fromAccounts = allAccounts
        .where(
          (a) => a.type != AccountType.goal && a.type != AccountType.loan,
        )
        .toList();
    // A rule saved before loan accounts were excluded here may still point
    // at one — keep it selectable in its own dropdown rather than crashing
    // on a value with no matching item.
    if (_accountId != null && !fromAccounts.any((a) => a.id == _accountId)) {
      final stale = allAccounts.where((a) => a.id == _accountId);
      fromAccounts.addAll(stale);
    }
    final toAccounts = allAccounts
        .where((a) => a.type == AccountType.goal || a.type == AccountType.loan)
        .toList();
    final categories = isGoalOrLoan
        ? [
            ...ref.watch(categoriesProvider(CategoryKind.expense)).valueOrNull ??
                const [],
            ...ref.watch(categoriesProvider(CategoryKind.income)).valueOrNull ??
                const [],
          ]
        : ref.watch(categoriesProvider(_kind)).valueOrNull ?? const [];
    final categoryMap = ref.watch(categoryMapProvider);

    // The chosen category may no longer match the kind after toggling —
    // clear it rather than silently keep an invalid id selected.
    if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _categoryId = null);
      });
    }
    // The chosen destination may no longer be a goal/loan account (deleted,
    // converted) — clear it the same way.
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
              _isEditing ? 'Edit auto rule' : 'New auto rule',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<_RuleKind>(
              segments: const [
                ButtonSegment(
                  value: _RuleKind.expense,
                  label: Text('Expense'),
                ),
                ButtonSegment(value: _RuleKind.income, label: Text('Income')),
                ButtonSegment(
                  value: _RuleKind.goalOrLoan,
                  label: Text('G&L'),
                ),
              ],
              selected: {_ruleKind},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _ruleKind = s.first),
            ),
            if (isGoalOrLoan) ...[
              const SizedBox(height: 6),
              Text(
                'Automatically moves money into a goal or pays down a loan '
                'on schedule.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: isGoalOrLoan
                    ? 'e.g. Emergency Fund, Car Loan EMI'
                    : (_kind == CategoryKind.expense
                          ? 'e.g. Netflix, Rent'
                          : 'e.g. Salary'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: kTabularFigures,
              ),
              decoration: InputDecoration(
                labelText: (_isEstimate || _hasPromo)
                    ? 'Usual amount'
                    : 'Amount',
                prefixText: MoneyFormat.inputPrefix,
                helperText: _isEstimate
                    ? "You'll be nudged to confirm the exact figure each "
                          'time it posts.'
                    : null,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Amount varies each time'),
              subtitle: const Text(
                'For a salary or bill that changes, e.g. by hours worked.',
              ),
              value: _isEstimate,
              onChanged: (v) => setState(() => _isEstimate = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Add a promotion'),
              subtitle: const Text(
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
                    child: TextField(
                      controller: _promoAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Promo amount',
                        prefixText: MoneyFormat.inputPrefix,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _promoOccurrencesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Occurrences',
                        hintText: 'e.g. 3',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (!isGoalOrLoan) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Foreign currency'),
                subtitle: const Text(
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
                        child: Text(
                          currencyForCode(_foreignCurrencyCode).code,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _foreignAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Foreign amount',
                        ),
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
                labelText: isGoalOrLoan ? 'From account' : 'Account',
              ),
              items: [
                for (final a in fromAccounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            if (isGoalOrLoan) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: toAccounts.any((a) => a.id == _toAccountId)
                    ? _toAccountId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Goal or loan'),
                items: [
                  for (final a in toAccounts)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text(
                        '${a.name} '
                        '(${a.type == AccountType.goal ? 'Goal' : 'Loan'})',
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _toAccountId = v),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: categories.any((c) => c.id == _categoryId)
                  ? _categoryId
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: isGoalOrLoan ? 'Category (optional)' : 'Category',
              ),
              items: [
                if (isGoalOrLoan)
                  const DropdownMenuItem(value: null, child: Text('None')),
                for (final c in categories)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(_categoryLabel(c, categoryMap)),
                  ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            if (!isGoalOrLoan) ...[
              const SizedBox(height: 16),
              _payeeField(theme),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Why this rule exists, or anything else worth noting',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            _tagsField(theme),
            const SizedBox(height: 20),
            // Four segments can outgrow a narrow phone or a larger system
            // font scale — scroll rather than let it overflow (GitHub #14).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<RecurringFrequency>(
                segments: const [
                  ButtonSegment(
                    value: RecurringFrequency.daily,
                    label: Text('Daily'),
                  ),
                  ButtonSegment(
                    value: RecurringFrequency.weekly,
                    label: Text('Weekly'),
                  ),
                  ButtonSegment(
                    value: RecurringFrequency.biweekly,
                    label: Text('2 weeks'),
                  ),
                  ButtonSegment(
                    value: RecurringFrequency.monthly,
                    label: Text('Monthly'),
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
                    Icon(Icons.event_rounded, color: cs.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Next due date' : 'Starts on',
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
                    Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (_frequency == RecurringFrequency.monthly)
              Text(
                'A shorter month snaps to its last day, then returns to the '
                '${_dueDate.day}${_ordinalSuffix(_dueDate.day)} once it exists again.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submitting ? null : _save,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(_isEditing ? 'Save changes' : 'Create rule'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _payeeField(ThemeData theme) {
    final suggestions = ref.watch(payeeSuggestionsProvider);
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
            labelText: 'Payee (optional)',
            hintText: _kind == CategoryKind.income
                ? 'Who pays you?'
                : 'Who gets paid?',
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
            Icon(Icons.sell_outlined, color: cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tags (optional)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (selected.isEmpty)
                    Text(
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
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTags() async {
    final result = await showModalBottomSheet<Set<int>>(
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
