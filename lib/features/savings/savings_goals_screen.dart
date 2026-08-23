import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

const _presetColors = <int>[
  0xFF16A34A,
  0xFF2563EB,
  0xFFDC2626,
  0xFFA855F7,
  0xFFF97316,
  0xFF0EA5E9,
  0xFF78716C,
  0xFFEC4899,
];

const _iconKeys = <String>[
  'savings',
  'travel',
  'education',
  'shopping',
  'health',
  'gift',
  'card',
  'other',
];

/// Goals & Loans hub — two-tab screen combining savings goals (Goals tab) with
/// loan tracking (Loans tab). Goals are [AccountType.goal]; loans are
/// [AccountType.loan]. Both are real accounts in the ledger.
class SavingsGoalsScreen extends ConsumerStatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  ConsumerState<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends ConsumerState<SavingsGoalsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGoalsTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals & Loans'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Goals'),
            Tab(text: 'Loans'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_GoalsTab(), _LoansTab()],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: isGoalsTab ? 'New goal' : 'New loan',
        onPressed: isGoalsTab
            ? () => _openNewGoalChoice(context)
            : () => _openLoanEditor(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Goals tab ────────────────────────────────────────────────────────────────

class _GoalsTab extends ConsumerWidget {
  const _GoalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final detailsAsync = ref.watch(goalDetailsProvider);
    final progress = ref.watch(goalProgressListProvider);

    return detailsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Text(
          "Couldn't load savings goals.",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      data: (_) {
        if (progress.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
            child: Column(
              children: [
                Icon(
                  Icons.savings_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No savings goals yet — tap + to set one, either fresh '
                  'or by turning an account you already have into a goal.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          itemCount: progress.length,
          itemBuilder: (context, i) => _GoalCard(progress: progress[i]),
        );
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.progress});

  final GoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = progress.account;
    final detail = progress.detail;
    final color = Color(account.colorValue);
    final daysLeft = detail.targetDate?.difference(DateTime.now()).inDays;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/more/goals/goal/${account.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(AppIcons.resolve(account.iconKey), color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (progress.reached)
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.income,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.fraction,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: color,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: MoneyFormat.symbol(progress.saved),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' of ${MoneyFormat.symbol(detail.targetAmount)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (daysLeft != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        daysLeft >= 0 ? '$daysLeft days left' : 'Past due',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: daysLeft >= 0
                              ? theme.colorScheme.onSurfaceVariant
                              : AppColors.expense,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Loans tab ────────────────────────────────────────────────────────────────

class _LoansTab extends ConsumerWidget {
  const _LoansTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final detailsAsync = ref.watch(loanDetailsProvider);
    final loans = ref.watch(loanProgressListProvider);

    return detailsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Text(
          "Couldn't load loans.",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      data: (_) {
        if (loans.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No loans tracked yet — tap + to add a loan you have taken.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          itemCount: loans.length,
          itemBuilder: (context, i) => _LoanCard(loan: loans[i]),
        );
      },
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan});

  final LoanProgress loan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = loan.account;
    final color = Color(account.colorValue);
    final paid = loan.fraction;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/more/goals/loan/${account.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(AppIcons.resolve(account.iconKey), color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (loan.outstanding.isZero)
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.income,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: paid,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: color,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: MoneyFormat.symbol(loan.outstanding),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.expense,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' of ${MoneyFormat.symbol(loan.principal)} left',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (loan.detail.emiAmount != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'EMI ${MoneyFormat.compact(loan.detail.emiAmount!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── New goal choice ──────────────────────────────────────────────────────────

enum _NewGoalChoice { fresh, fromAccount }

Future<void> _openNewGoalChoice(BuildContext context) async {
  final theme = Theme.of(context);
  final choice = await showModalBottomSheet<_NewGoalChoice>(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'New goal',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline_rounded),
            title: const Text('Start fresh'),
            subtitle: const Text('A new goal, empty until you fund it.'),
            onTap: () => Navigator.of(sheetContext).pop(_NewGoalChoice.fresh),
          ),
          ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: const Text('Turn an account into a goal'),
            subtitle: const Text(
              'Move its balance in and set it aside for this.',
            ),
            onTap: () =>
                Navigator.of(sheetContext).pop(_NewGoalChoice.fromAccount),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  await _openGoalEditor(
    context,
    fromExistingAccount: choice == _NewGoalChoice.fromAccount,
  );
}

Future<void> _openGoalEditor(
  BuildContext context, {
  GoalProgress? existing,
  bool fromExistingAccount = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _GoalEditorSheet(
      existing: existing,
      fromExistingAccount: fromExistingAccount,
    ),
  );
}

class _GoalEditorSheet extends ConsumerStatefulWidget {
  const _GoalEditorSheet({this.existing, this.fromExistingAccount = false});

  final GoalProgress? existing;
  final bool fromExistingAccount;

  @override
  ConsumerState<_GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends ConsumerState<_GoalEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late int _colorValue;
  late String _iconKey;
  int? _sourceAccountId;
  DateTime? _targetDate;
  int? _categoryId;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;
  bool get _fromExistingAccount => !_isEdit && widget.fromExistingAccount;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.account.name ?? '');
    _amountController = TextEditingController(
      text: existing == null
          ? ''
          : MoneyFormat.bare(existing.detail.targetAmount),
    );
    _colorValue = existing?.account.colorValue ?? _presetColors.first;
    _iconKey = existing?.account.iconKey ?? _iconKeys.first;
    _targetDate = existing?.detail.targetDate;
    _categoryId = existing?.detail.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 30),
    );
    if (picked == null) return;
    setState(() => _targetDate = picked);
  }

  void _onSourceAccountChanged(int? id) {
    setState(() {
      _sourceAccountId = id;
      if (id != null && _nameController.text.trim().isEmpty) {
        final account = ref.read(accountMapProvider)[id];
        if (account != null) _nameController.text = account.name;
      }
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Give the goal a name.');
      return;
    }
    final amount = Money.tryParse(_amountController.text);
    if (amount == null || !amount.isPositive) {
      _showError('Enter a target amount greater than zero.');
      return;
    }
    if (_fromExistingAccount && _sourceAccountId == null) {
      _showError('Pick the account to turn into this goal.');
      return;
    }

    setState(() => _submitting = true);
    final db = ref.read(dbProvider);
    final navigator = Navigator.of(context);
    try {
      if (_isEdit) {
        await db.updateGoal(
          accountId: widget.existing!.account.id,
          name: name,
          targetAmount: amount,
          targetDate: _targetDate,
          colorValue: _colorValue,
          iconKey: _iconKey,
          categoryId: _categoryId,
        );
      } else {
        final goalAccountId = await db.addGoal(
          name: name,
          targetAmount: amount,
          targetDate: _targetDate,
          colorValue: _colorValue,
          iconKey: _iconKey,
          categoryId: _categoryId,
        );
        if (_fromExistingAccount && mounted) {
          await _fundFromSourceAccount(db, goalAccountId);
        }
      }
      if (!mounted) return;
      navigator.pop();
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(e.message?.toString() ?? 'Could not save the goal.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Could not save the goal.');
    }
  }

  Future<void> _fundFromSourceAccount(AppDatabase db, int goalAccountId) async {
    final sourceId = _sourceAccountId;
    if (sourceId == null) return;
    final source = ref.read(accountMapProvider)[sourceId];
    if (source == null || !source.currentBalance.isPositive) return;

    final move = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move the balance in?'),
        content: Text(
          'Transfer ${MoneyFormat.symbol(source.currentBalance)} from '
          '"${source.name}" into this goal now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Move it'),
          ),
        ],
      ),
    );
    if (move == true) {
      await db.addTransaction(
        type: TxType.transfer,
        accountId: sourceId,
        toAccountId: goalAccountId,
        amount: source.currentBalance,
        date: DateTime.now(),
      );
    }
    if (!mounted) return;

    final archive = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Archive "${source.name}"?'),
        content: const Text(
          'It stays in your history — this only hides it from active '
          "accounts, if you don't need it day-to-day anymore.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (archive == true) {
      await db.archiveAccount(sourceId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = [
      ...ref.watch(categoriesProvider(CategoryKind.expense)).valueOrNull ?? [],
      ...ref.watch(categoriesProvider(CategoryKind.income)).valueOrNull ?? [],
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom +
            MediaQuery.of(context).viewInsets.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit
                  ? 'Edit goal'
                  : _fromExistingAccount
                  ? 'Turn an account into a goal'
                  : 'New savings goal',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            if (_fromExistingAccount) ...[
              _SourceAccountPicker(
                selected: _sourceAccountId,
                onChanged: _onSourceAccountChanged,
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _nameController,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.words,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Emergency fund, Goa trip',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Target amount',
                prefixText: MoneyFormat.inputPrefix,
                hintText: '0.00',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              value: _categoryId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Category (optional)',
                helperText: 'Tag contributions to this category.',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                for (final c in categories)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickTargetDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(
                _targetDate == null
                    ? 'Target date (optional)'
                    : DateFormat('d MMM yyyy').format(_targetDate!),
              ),
            ),
            if (_targetDate != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _targetDate = null),
                  child: const Text('Clear date'),
                ),
              ),
            const SizedBox(height: 12),
            _fieldLabel(theme, 'Colour'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [for (final c in _presetColors) _colorDot(theme, c)],
            ),
            const SizedBox(height: 24),
            _fieldLabel(theme, 'Icon'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [for (final k in _iconKeys) _iconTile(theme, k)],
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submitting ? null : _save,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(ThemeData theme, String text) {
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _colorDot(ThemeData theme, int value) {
    final selected = _colorValue == value;
    return GestureDetector(
      onTap: () => setState(() => _colorValue = value),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Color(value),
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: theme.colorScheme.onSurface, width: 2.5)
              : null,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  Widget _iconTile(ThemeData theme, String key) {
    final selected = _iconKey == key;
    final color = Color(_colorValue);
    return GestureDetector(
      onTap: () => setState(() => _iconKey = key),
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : theme.colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? color : theme.colorScheme.outline,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Icon(
          AppIcons.resolve(key),
          color: selected ? color : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ── Loan editor ──────────────────────────────────────────────────────────────

Future<void> _openLoanEditor(BuildContext context, {LoanProgress? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _LoanEditorSheet(existing: existing),
  );
}

class _LoanEditorSheet extends ConsumerStatefulWidget {
  const _LoanEditorSheet({this.existing});

  final LoanProgress? existing;

  @override
  ConsumerState<_LoanEditorSheet> createState() => _LoanEditorSheetState();
}

class _LoanEditorSheetState extends ConsumerState<_LoanEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _principalController;
  late final TextEditingController _emiController;
  late int _colorValue;
  late String _iconKey;
  int? _categoryId;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.account.name ?? '');
    _principalController = TextEditingController(
      text: existing == null ? '' : MoneyFormat.bare(existing.principal),
    );
    _emiController = TextEditingController(
      text: existing?.detail.emiAmount == null
          ? ''
          : MoneyFormat.bare(existing!.detail.emiAmount!),
    );
    _colorValue = existing?.account.colorValue ?? _presetColors.first;
    _iconKey = existing?.account.iconKey ?? _iconKeys.first;
    _categoryId = existing?.detail.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _principalController.dispose();
    _emiController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Give the loan a name.');
      return;
    }
    final principal = Money.tryParse(_principalController.text);
    if (!_isEdit && (principal == null || !principal.isPositive)) {
      _showError('Enter the amount borrowed (greater than zero).');
      return;
    }
    final emiText = _emiController.text.trim();
    final emi = emiText.isEmpty ? null : Money.tryParse(emiText);
    if (emiText.isNotEmpty && (emi == null || !emi.isPositive)) {
      _showError('EMI must be greater than zero, or leave it blank.');
      return;
    }

    setState(() => _submitting = true);
    final db = ref.read(dbProvider);
    final navigator = Navigator.of(context);
    try {
      if (_isEdit) {
        await db.updateLoan(
          accountId: widget.existing!.account.id,
          name: name,
          colorValue: _colorValue,
          iconKey: _iconKey,
          categoryId: _categoryId,
          emiAmount: emi,
        );
      } else {
        await db.addLoan(
          name: name,
          principal: principal!,
          colorValue: _colorValue,
          iconKey: _iconKey,
          categoryId: _categoryId,
          emiAmount: emi,
        );
      }
      if (!mounted) return;
      navigator.pop();
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(e.message?.toString() ?? 'Could not save the loan.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Could not save the loan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = [
      ...ref.watch(categoriesProvider(CategoryKind.expense)).valueOrNull ?? [],
      ...ref.watch(categoriesProvider(CategoryKind.income)).valueOrNull ?? [],
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom +
            MediaQuery.of(context).viewInsets.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Edit loan' : 'New loan',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Home loan, Car loan',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            if (!_isEdit) ...[
              TextField(
                controller: _principalController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount borrowed',
                  prefixText: MoneyFormat.inputPrefix,
                  hintText: '0.00',
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _emiController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Monthly EMI (optional)',
                prefixText: MoneyFormat.inputPrefix,
                hintText: '0.00',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              value: _categoryId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Category (optional)',
                helperText: 'Tag repayments to this category.',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                for (final c in categories)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 16),
            _fieldLabel(theme, 'Colour'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [for (final c in _presetColors) _colorDot(theme, c)],
            ),
            const SizedBox(height: 24),
            _fieldLabel(theme, 'Icon'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [for (final k in _iconKeys) _iconTile(theme, k)],
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submitting ? null : _save,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(ThemeData theme, String text) {
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _colorDot(ThemeData theme, int value) {
    final selected = _colorValue == value;
    return GestureDetector(
      onTap: () => setState(() => _colorValue = value),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Color(value),
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: theme.colorScheme.onSurface, width: 2.5)
              : null,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  Widget _iconTile(ThemeData theme, String key) {
    final selected = _iconKey == key;
    final color = Color(_colorValue);
    return GestureDetector(
      onTap: () => setState(() => _iconKey = key),
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : theme.colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? color : theme.colorScheme.outline,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Icon(
          AppIcons.resolve(key),
          color: selected ? color : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ── Source account picker (used by goal editor) ──────────────────────────────

class _SourceAccountPicker extends ConsumerWidget {
  const _SourceAccountPicker({required this.selected, required this.onChanged});

  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = (ref.watch(balanceAccountsProvider).valueOrNull ?? const [])
        .where((a) => a.type != AccountType.goal)
        .toList();

    return DropdownButtonFormField<int>(
      initialValue: accounts.any((a) => a.id == selected) ? selected : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Account',
        helperText: 'Its balance can be moved into the goal next.',
      ),
      items: [
        for (final a in accounts)
          DropdownMenuItem(
            value: a.id,
            child: Text('${a.name} · ${MoneyFormat.symbol(a.currentBalance)}'),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

// ── Public API ───────────────────────────────────────────────────────────────

/// Opens the goal editor for an existing goal — used by the detail screen's
/// Edit action.
void openGoalEditor(BuildContext context, GoalProgress existing) {
  _openGoalEditor(context, existing: existing);
}

/// Opens the loan editor for an existing loan — used by the loan detail
/// screen's Edit action.
void openLoanEditor(BuildContext context, LoanProgress existing) {
  _openLoanEditor(context, existing: existing);
}
