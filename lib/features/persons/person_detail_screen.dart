import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// One person's ledger. Net balance = Σ(theyOwe) − Σ(iOwe).
/// `+` they owe you · `-` you owe them.
class PersonDetailScreen extends ConsumerWidget {
  const PersonDetailScreen({required this.personId, super.key});

  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personsAsync = ref.watch(personsProvider);

    return personsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Person')),
        body: const Center(child: Text('Something went wrong')),
      ),
      data: (persons) {
        PersonRow? person;
        for (final p in persons) {
          if (p.id == personId) {
            person = p;
            break;
          }
        }
        if (person == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Person')),
            body: const Center(child: Text('Person not found')),
          );
        }
        return _buildScaffold(context, ref, person);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, WidgetRef ref, PersonRow person) {
    final theme = Theme.of(context);
    final balance =
        ref.watch(personBalancesProvider).valueOrNull?[person.id] ??
        const Money.zero();
    final entriesAsync = ref.watch(personEntriesProvider(person.id));
    final accountMap = ref.watch(accountMapProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: Text(person.name), expandedHeight: 132),
          SliverToBoxAdapter(child: _BalanceHero(balance: balance)),
          SliverToBoxAdapter(
            child: _ActionButtons(personId: person.id, balance: balance),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
              child: Text(
                'HISTORY',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
          entriesAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    "Couldn't load history",
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Center(child: Text('No entries yet.')),
                  ),
                );
              }
              final sorted = [...entries]
                ..sort((a, b) {
                  final byDate = b.date.compareTo(a.date);
                  return byDate != 0
                      ? byDate
                      : b.createdAt.compareTo(a.createdAt);
                });
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList.builder(
                  itemCount: sorted.length,
                  itemBuilder: (context, i) {
                    final entry = sorted[i];
                    final accountName = entry.accountId == null
                        ? null
                        : accountMap[entry.accountId]?.name;
                    return _EntryRow(entry: entry, accountName: accountName);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Big net balance with a plain-language label.
class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.balance});

  final Money balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Money shown;
    final Color color;
    final String label;
    if (balance.isPositive) {
      shown = balance;
      color = AppColors.income;
      label = 'Owes you';
    } else if (balance.isNegative) {
      shown = balance.abs;
      color = AppColors.expense;
      label = 'You owe';
    } else {
      shown = balance;
      color = theme.colorScheme.onSurfaceVariant;
      label = 'Settled';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          child: Column(
            children: [
              MoneyText(
                shown,
                color: color,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 'They owe' (green) and 'I owe' (red) open the entry sheet in that
/// direction. "Mark as repaid" — a third, distinct entry point rather than
/// overloading 'I owe' — only shows when there's a balance to repay and the
/// setting is on (see [countRepaymentsAsIncomeProvider]).
class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.personId, required this.balance});

  final int personId;
  final Money balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offerRepayment =
        ref.watch(countRepaymentsAsIncomeProvider) && balance.isPositive;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.income.withValues(alpha: 0.14),
                    foregroundColor: AppColors.income,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _showEntrySheet(
                    context,
                    personId,
                    PersonDirection.theyOwe,
                  ),
                  child: const Text('They owe'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.expense.withValues(alpha: 0.14),
                    foregroundColor: AppColors.expense,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () =>
                      _showEntrySheet(context, personId, PersonDirection.iOwe),
                  child: const Text('I owe'),
                ),
              ),
            ],
          ),
          if (offerRepayment) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showEntrySheet(
                  context,
                  personId,
                  PersonDirection.iOwe,
                  isRepayment: true,
                ),
                icon: const Icon(Icons.paid_outlined, size: 18),
                label: const Text('Mark as repaid'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One ledger row. The leading icon shows which way *cash* moved:
/// theyOwe = money left you (up, red) · iOwe = money came to you (down, green).
class _EntryRow extends ConsumerWidget {
  const _EntryRow({required this.entry, required this.accountName});

  final PersonEntryRow entry;
  final String? accountName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final theyOwe = entry.direction == PersonDirection.theyOwe;
    final isRepayment = entry.categoryId != null;
    final color = isRepayment
        ? AppColors.income
        : (theyOwe ? AppColors.expense : AppColors.income);
    final icon = isRepayment
        ? Icons.paid_outlined
        : (theyOwe ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);

    final note = entry.note?.trim();
    final title = (note != null && note.isNotEmpty)
        ? note
        : (theyOwe ? 'You gave' : 'You received');

    final categoryName = isRepayment
        ? ref.watch(categoryMapProvider)[entry.categoryId]?.name
        : null;

    final dateStr = DateFormat('d MMM yyyy').format(entry.date);
    final subtitle = [
      dateStr,
      ?accountName,
      if (categoryName != null) 'Repaid · $categoryName',
    ].join(' · ');

    return Slidable(
      key: ValueKey(entry.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => _delete(context, ref),
            backgroundColor: AppColors.expense,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        onTap: () => _showEntrySheet(
          context,
          entry.personId,
          entry.direction,
          isRepayment: isRepayment,
          existing: entry,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          foregroundColor: color,
          child: Icon(icon, size: 20),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: MoneyText(
          entry.amount,
          color: color,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(dbProvider).deletePersonEntry(entry.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Entry deleted')));
  }
}

void _showEntrySheet(
  BuildContext context,
  int personId,
  PersonDirection direction, {
  bool isRepayment = false,
  PersonEntryRow? existing,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EntrySheet(
      personId: personId,
      direction: direction,
      isRepayment: isRepayment,
      existing: existing,
    ),
  );
}

/// Add a lend/borrow (or a repayment in the opposite direction — or, with
/// [isRepayment], a repayment explicitly counted as income). With
/// [existing] set, edits that entry in place instead of creating a new one —
/// the direction and repayment flag stay fixed to what the entry already
/// was; only amount, date, note, account and (for a repayment) category
/// can change.
class _EntrySheet extends ConsumerStatefulWidget {
  const _EntrySheet({
    required this.personId,
    required this.direction,
    this.isRepayment = false,
    this.existing,
  });

  final int personId;
  final PersonDirection direction;
  final bool isRepayment;
  final PersonEntryRow? existing;

  @override
  ConsumerState<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<_EntrySheet> {
  late final _amountController = TextEditingController(
    text: widget.existing == null
        ? ''
        : MoneyFormat.bare(widget.existing!.amount),
  );
  late final _noteController = TextEditingController(
    text: widget.existing?.note ?? '',
  );
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  late DateTime? _dueDate = widget.existing?.dueDate;

  /// `null` == "don't move money", the exception rather than the default.
  int? _accountId;

  /// Required only when [_EntrySheet.isRepayment] is true.
  late int? _repaymentCategoryId = widget.existing?.categoryId;
  bool _accountInitialised = false;
  String? _amountError;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;
  bool get _theyOwe => widget.direction == PersonDirection.theyOwe;

  /// Preselect an account the first time we know what accounts exist:
  /// editing starts from whatever the entry already had (including `null` —
  /// "don't move money" is a real, deliberate choice, not left unset);
  /// creating a new entry defaults to a real account. That default used to
  /// be "None (just track it)", so logging "Ram owes me 500" left every
  /// balance untouched and the money silently never moved.
  void _initAccount(List<AccountRow> accounts) {
    if (_accountInitialised) return;
    if (_isEdit) {
      _accountInitialised = true;
      _accountId = widget.existing!.accountId;
      return;
    }
    if (accounts.isEmpty) return;
    _accountInitialised = true;
    // A debit card draws from its bank; either works, but prefer a real holder.
    final holder = accounts.firstWhere(
      (a) => a.linkedAccountId == null,
      orElse: () => accounts.first,
    );
    _accountId = holder.id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool due}) async {
    final initial = due ? (_dueDate ?? DateTime.now()) : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (due) {
        _dueDate = picked;
      } else {
        _date = picked;
      }
    });
  }

  Future<void> _save() async {
    final amount = Money.tryParse(_amountController.text);
    if (amount == null || !amount.isPositive) {
      setState(() => _amountError = 'Enter an amount greater than zero');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final note = _noteController.text.trim();
    if (widget.isRepayment && _repaymentCategoryId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Choose a category for this income')),
      );
      return;
    }
    if (widget.isRepayment && _accountId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('A repayment counted as income must move money'),
        ),
      );
      return;
    }
    setState(() {
      _amountError = null;
      _saving = true;
    });
    try {
      final db = ref.read(dbProvider);
      if (_isEdit) {
        await db.updatePersonEntry(
          id: widget.existing!.id,
          direction: widget.direction,
          amount: amount,
          date: _date,
          dueDate: _dueDate,
          accountId: _accountId,
          note: note.isEmpty ? null : note,
          categoryId: widget.isRepayment ? _repaymentCategoryId : null,
        );
      } else {
        await db.addPersonEntry(
          personId: widget.personId,
          direction: widget.direction,
          amount: amount,
          date: _date,
          dueDate: _dueDate,
          accountId: _accountId,
          note: note.isEmpty ? null : note,
          categoryId: widget.isRepayment ? _repaymentCategoryId : null,
        );
      }
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _isEdit
                  ? 'Entry updated'
                  : widget.isRepayment
                  ? 'Saved as income'
                  : _theyOwe
                  ? 'Saved — they owe you'
                  : 'Saved — you owe them',
            ),
          ),
        );
    } catch (error) {
      if (mounted) setState(() => _saving = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not save: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts =
        ref.watch(accountsProvider).valueOrNull ?? const <AccountRow>[];
    _initAccount(accounts);
    final accent = _theyOwe ? AppColors.income : AppColors.expense;

    // Editing an old entry can point at an account archived since — the
    // dropdown's live list never includes those, and a value with no
    // matching item crashes DropdownButtonFormField. Splice it back in
    // (labelled) rather than silently dropping which account it was.
    var dropdownAccounts = accounts;
    if (_isEdit &&
        _accountId != null &&
        !accounts.any((a) => a.id == _accountId)) {
      final archivedAccounts =
          ref.watch(archivedAccountsProvider).valueOrNull ??
          const <AccountRow>[];
      for (final a in archivedAccounts) {
        if (a.id == _accountId) {
          dropdownAccounts = [...accounts, a];
          break;
        }
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isEdit
                    ? 'Edit entry'
                    : widget.isRepayment
                    ? 'Mark as repaid'
                    : _theyOwe
                    ? 'They owe you'
                    : 'You owe them',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isRepayment
                    ? 'Counts toward your income, under the category you '
                          'choose below.'
                    : _theyOwe
                    ? 'You gave money out. Their balance goes up.'
                    : 'You received money. Their balance goes down.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  errorText: _amountError,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_amountError != null) {
                    setState(() => _amountError = null);
                  }
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(due: false),
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(DateFormat('d MMM yyyy').format(_date)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(due: true),
                      icon: const Icon(
                        Icons.event_available_outlined,
                        size: 18,
                      ),
                      label: Text(
                        _dueDate == null
                            ? 'Due date'
                            : DateFormat('d MMM yyyy').format(_dueDate!),
                      ),
                    ),
                  ),
                  if (_dueDate != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear due date',
                      onPressed: () => setState(() => _dueDate = null),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int?>(
                // Defaults to a real account, never "None". Money changing
                // hands is the normal case; not moving any is the exception.
                initialValue: _accountId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Money moved through',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final a in dropdownAccounts)
                    DropdownMenuItem<int?>(
                      value: a.id,
                      child: Text(
                        a.isArchived ? '${a.name} (archived)' : a.name,
                      ),
                    ),
                  // A repayment counted as income must move real money — see
                  // the validation in `_save`.
                  if (!widget.isRepayment)
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text("Don't move money (just note it)"),
                    ),
                ],
                onChanged: (value) => setState(() => _accountId = value),
              ),
              const SizedBox(height: 8),
              Text(
                _accountId == null
                    ? 'No money will move. This only records who owes whom.'
                    : widget.isRepayment
                    ? 'This amount enters that account and posts as '
                          'income under the category below.'
                    : 'This amount will leave or enter that account and '
                          "appear in Transactions. Lending still isn't an "
                          'expense — it\'s your money, just held by '
                          'someone else.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.isRepayment) ...[
                const SizedBox(height: 14),
                _RepaymentCategoryField(
                  categoryId: _repaymentCategoryId,
                  onChanged: (id) => setState(() => _repaymentCategoryId = id),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Income category picker for a repayment marked to count as income. A plain
/// dropdown, not the grid sheet Add/Edit Transaction uses — this form is
/// already a dropdown-heavy sheet, and there's only ever one field to pick.
class _RepaymentCategoryField extends ConsumerWidget {
  const _RepaymentCategoryField({
    required this.categoryId,
    required this.onChanged,
  });

  final int? categoryId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoriesProvider(CategoryKind.income)).valueOrNull ??
        const <CategoryRow>[];
    final ids = {for (final c in categories) c.id};
    final value = ids.contains(categoryId) ? categoryId : null;

    return DropdownButtonFormField<int?>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final c in categories)
          DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
      ],
      onChanged: onChanged,
    );
  }
}
