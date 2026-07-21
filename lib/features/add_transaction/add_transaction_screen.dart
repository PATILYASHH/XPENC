import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// The ➕ route. Expense / Income / Transfer.
///
/// A transfer is neither income nor expense: it never carries a category and
/// always moves money between two different accounts.
///
/// With a [transactionId] the screen edits that existing transaction instead
/// of creating a new one.
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({this.transactionId, super.key});

  final int? transactionId;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  TxType _type = TxType.expense;

  /// Raw rupee text as typed on the keypad: digits + at most one '.'.
  String _buffer = '';

  int? _accountId; // expense/income: account. transfer: FROM account.
  int? _toAccountId; // transfer: TO account.
  int? _categoryId; // income/expense only.
  DateTime _date = DateTime.now();

  final _noteController = TextEditingController();

  /// True while an existing transaction is being fetched for editing.
  bool _loading = false;

  bool get _isEditing => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadForEdit());
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// Fetch the row being edited and prefill every field from it.
  Future<void> _loadForEdit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final row =
        await ref.read(dbProvider).transactionById(widget.transactionId!);
    if (!mounted) return;

    if (row == null) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Transaction not found')),
      );
      return;
    }

    // This screen only offers Expense / Income / Transfer. A person movement
    // has no segment, and `SegmentedButton` asserts that its selected value is
    // one of its segments — assigning it here would crash the screen.
    if (row.type.isPersonMovement) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Edit this from the person\'s page.'),
        ),
      );
      return;
    }

    setState(() {
      _type = row.type;
      _buffer = _bufferFromMoney(row.amount);
      _accountId = row.accountId;
      _toAccountId = row.toAccountId;
      _categoryId = row.categoryId;
      _date = row.date;
      _noteController.text = row.note ?? '';
      _loading = false;
    });
  }

  /// Render a stored amount back into the keypad buffer: plain rupees with up
  /// to two decimals, dropping a trailing `.00` / `.X0`. `1500` paise -> "15",
  /// `1550` -> "15.5", `1555` -> "15.55".
  static String _bufferFromMoney(Money amount) {
    final paise = amount.abs.paise;
    final rupees = paise ~/ 100;
    final fraction = paise % 100;
    if (fraction == 0) return '$rupees';
    if (fraction % 10 == 0) return '$rupees.${fraction ~/ 10}';
    return '$rupees.${fraction.toString().padLeft(2, '0')}';
  }

  /// The live amount. Tolerates a trailing dot while the user is mid-type.
  Money get _amount {
    var b = _buffer;
    if (b.endsWith('.')) b = b.substring(0, b.length - 1);
    return Money.tryParse(b) ?? const Money.zero();
  }

  // ── Keypad ────────────────────────────────────────────────────────────────

  void _onKey(String k) {
    setState(() {
      if (k == '.') {
        if (!_buffer.contains('.')) {
          _buffer = _buffer.isEmpty ? '0.' : '$_buffer.';
        }
        return;
      }
      final dot = _buffer.indexOf('.');
      if (dot != -1 && _buffer.length - dot - 1 >= 2) {
        return; // already two decimal places
      }
      if (_buffer == '0') {
        _buffer = k; // replace a lone leading zero
      } else {
        if (_buffer.replaceAll('.', '').length >= 12) return; // sane cap
        _buffer = '$_buffer$k';
      }
    });
  }

  void _onBackspace() {
    if (_buffer.isEmpty) return;
    setState(() => _buffer = _buffer.substring(0, _buffer.length - 1));
  }

  // ── Pickers ───────────────────────────────────────────────────────────────

  Future<void> _pickAccount({required bool isFrom}) async {
    final forTo = _type == TxType.transfer && !isFrom;
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AccountPickerSheet(
        title: forTo
            ? 'To account'
            : (_type == TxType.transfer ? 'From account' : 'Account'),
        excludeId: forTo ? _accountId : null,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (forTo) {
        _toAccountId = selected;
      } else {
        _accountId = selected;
        if (_toAccountId == selected) _toAccountId = null;
      }
    });
  }

  Future<void> _pickCategory() async {
    final kind =
        _type == TxType.income ? CategoryKind.income : CategoryKind.expense;
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CategoryPickerSheet(kind: kind),
    );
    if (selected == null || !mounted) return;
    setState(() => _categoryId = selected);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final amount = _amount;

    if (!amount.isPositive) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero')),
      );
      return;
    }
    if (_accountId == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(_type == TxType.transfer
              ? 'Choose the account to transfer from'
              : 'Choose an account'),
        ),
      );
      return;
    }
    if (_type == TxType.transfer) {
      if (_toAccountId == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Choose the account to transfer to')),
        );
        return;
      }
      if (_toAccountId == _accountId) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Transfer must be between two different accounts'),
          ),
        );
        return;
      }
    } else if (_categoryId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Choose a category')),
      );
      return;
    }

    final note = _noteController.text.trim();
    try {
      if (_isEditing) {
        await ref.read(dbProvider).updateTransaction(
              id: widget.transactionId!,
              type: _type,
              amount: amount,
              accountId: _accountId!,
              toAccountId: _type == TxType.transfer ? _toAccountId : null,
              categoryId: _type == TxType.transfer ? null : _categoryId,
              date: _date,
              note: note.isEmpty ? null : note,
            );
      } else {
        await ref.read(dbProvider).addTransaction(
              type: _type,
              amount: amount,
              accountId: _accountId!,
              toAccountId: _type == TxType.transfer ? _toAccountId : null,
              categoryId: _type == TxType.transfer ? null : _categoryId,
              date: _date,
              note: note.isEmpty ? null : note,
            );
      }
    } on ArgumentError catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message?.toString() ?? 'Could not save transaction'),
        ),
      );
      return;
    }

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(_isEditing ? 'Updated' : 'Saved')),
    );
  }

  // ── Delete ──────────────────────────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final theme = Theme.of(context);
    // Capture before the first await — never touch `context` across the gap.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this transaction?'),
        content: const Text('The amount will be added back to your balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(dbProvider).deleteTransaction(widget.transactionId!);
    } on ArgumentError catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message?.toString() ?? 'Could not delete')),
      );
      return;
    }
    if (!mounted) return;

    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Transaction deleted')),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountMap = ref.watch(accountMapProvider);
    final categoryMap = ref.watch(categoryMapProvider);
    final amount = _amount;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(_isEditing ? 'Edit' : 'Add'),
        actions: _loading
            ? null
            : [
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: _confirmDelete,
                  ),
                TextButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<TxType>(
                        segments: const [
                          ButtonSegment(
                            value: TxType.expense,
                            label: Text('Expense'),
                          ),
                          ButtonSegment(
                            value: TxType.income,
                            label: Text('Income'),
                          ),
                          ButtonSegment(
                            value: TxType.transfer,
                            label: Text('Transfer'),
                          ),
                        ],
                        selected: {_type},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => setState(() {
                          _type = s.first;
                          // category is meaningless on type change
                          _categoryId = null;
                          if (_type != TxType.transfer) _toAccountId = null;
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        MoneyFormat.symbol(amount),
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorForTxType(_type),
                          fontFeatures: kTabularFigures,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _buildPickers(accountMap, categoryMap),
                      ),
                    ),
                  ),
                  _buildKeypad(theme),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildPickers(
    Map<int, AccountRow> accountMap,
    Map<int, CategoryRow> categoryMap,
  ) {
    final tiles = <Widget>[];

    if (_type == TxType.transfer) {
      tiles.add(_pickerTile(
        icon: AppIcons.resolve('bank'),
        label: 'From account',
        value: accountMap[_accountId]?.name ?? 'Select account',
        selected: _accountId != null,
        onTap: () => _pickAccount(isFrom: true),
      ));
      tiles.add(const SizedBox(height: 12));
      tiles.add(_pickerTile(
        icon: AppIcons.resolve('transfer'),
        label: 'To account',
        value: accountMap[_toAccountId]?.name ?? 'Select account',
        selected: _toAccountId != null,
        onTap: () => _pickAccount(isFrom: false),
      ));
    } else {
      tiles.add(_pickerTile(
        icon: AppIcons.resolve('wallet'),
        label: _type == TxType.income ? 'Deposit to' : 'Paid via',
        value: accountMap[_accountId]?.name ?? 'Select account',
        selected: _accountId != null,
        onTap: () => _pickAccount(isFrom: true),
      ));
      tiles.add(const SizedBox(height: 12));
      final cat = categoryMap[_categoryId];
      final parent =
          cat?.parentId == null ? null : categoryMap[cat!.parentId];
      tiles.add(_pickerTile(
        icon: AppIcons.resolve(cat?.iconKey ?? 'other'),
        label: 'Category',
        value: cat == null
            ? 'Select category'
            : parent == null
                ? cat.name
                : '${parent.name} › ${cat.name}',
        selected: _categoryId != null,
        onTap: _pickCategory,
      ));
    }

    tiles.add(const SizedBox(height: 12));
    tiles.add(_pickerTile(
      icon: Icons.event_outlined,
      label: 'Date',
      value: DateFormat('d MMM yyyy').format(_date),
      selected: true,
      onTap: _pickDate,
    ));
    tiles.add(const SizedBox(height: 12));
    tiles.add(_noteCard());
    return tiles;
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required String value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        title: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: selected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  Widget _noteCard() {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _noteController,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Note (optional)',
            border: InputBorder.none,
            icon: Icon(
              Icons.notes_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(ThemeData theme) {
    const keys = <String>[
      '1', '2', '3', //
      '4', '5', '6', //
      '7', '8', '9', //
      '.', '0', '<', //
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < 4; r++)
            Row(
              children: [
                for (var c = 0; c < 3; c++)
                  Expanded(child: _keypadButton(theme, keys[r * 3 + c])),
              ],
            ),
        ],
      ),
    );
  }

  Widget _keypadButton(ThemeData theme, String k) {
    final isBackspace = k == '<';
    return Padding(
      padding: const EdgeInsets.all(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => isBackspace ? _onBackspace() : _onKey(k),
        child: SizedBox(
          height: 56,
          child: Center(
            child: isBackspace
                ? Icon(
                    Icons.backspace_outlined,
                    color: theme.colorScheme.onSurface,
                  )
                : Text(k, style: theme.textTheme.titleLarge),
          ),
        ),
      ),
    );
  }
}

/// A round badge showing an account/category icon on its own stored colour.
Widget _iconCircle(String iconKey, int colorValue, {double size = 40}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Color(colorValue),
      shape: BoxShape.circle,
    ),
    child: Icon(
      AppIcons.resolve(iconKey),
      color: Colors.white,
      size: size * 0.5,
    ),
  );
}

/// Bottom sheet: pick an account (or a debit-card instrument) to pay/receive
/// with. Debit cards are selectable but show the bank they draw from instead of
/// a balance.
class _AccountPickerSheet extends ConsumerWidget {
  const _AccountPickerSheet({required this.title, this.excludeId});

  final String title;
  final int? excludeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accountsAsync = ref.watch(accountsProvider);
    final accountMap = ref.watch(accountMapProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
            Flexible(
              child: accountsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Could not load accounts.\n$e',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                data: (accounts) {
                  final list =
                      accounts.where((a) => a.id != excludeId).toList();
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No accounts available',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final a = list[i];
                      final isDebitCard = a.linkedAccountId != null;
                      final linkedName = a.linkedAccountId == null
                          ? null
                          : accountMap[a.linkedAccountId]?.name;
                      return ListTile(
                        leading: _iconCircle(a.iconKey, a.colorValue),
                        title: Text(a.name),
                        subtitle: isDebitCard
                            ? Text('Draws from ${linkedName ?? 'linked bank'}')
                            : null,
                        trailing:
                            isDebitCard ? null : BalanceText(a.currentBalance),
                        onTap: () => Navigator.of(context).pop(a.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: pick a category, as a grid of coloured chips. Only shown for
/// income/expense — a transfer has no category.
///
/// Two levels deep: the first grid is the top-level categories. Tapping one that
/// has subcategories drills into a second grid of its children (with a "Use
/// [parent]" chip to pick the parent directly); a childless one is picked on the
/// spot. Popping returns the chosen category id.
class _CategoryPickerSheet extends ConsumerStatefulWidget {
  const _CategoryPickerSheet({required this.kind});

  final CategoryKind kind;

  @override
  ConsumerState<_CategoryPickerSheet> createState() =>
      _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<_CategoryPickerSheet> {
  /// Non-null while drilled into a parent's subcategories.
  int? _drillParentId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catsAsync = ref.watch(categoriesProvider(widget.kind));

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: SafeArea(
        top: false,
        child: catsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Could not load categories.\n$e',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          data: (cats) => _content(theme, cats),
        ),
      ),
    );
  }

  Widget _content(ThemeData theme, List<CategoryRow> cats) {
    if (cats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No categories yet',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final childrenByParent = <int, List<CategoryRow>>{};
    for (final c in cats) {
      if (c.parentId != null) {
        (childrenByParent[c.parentId!] ??= []).add(c);
      }
    }

    final drillParent = _drillParentId == null
        ? null
        : cats.where((c) => c.id == _drillParentId).firstOrNull;

    // The list of cells to render, and the header, depend on the level.
    final Widget header;
    final List<Widget> cells;
    if (drillParent == null) {
      header = Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Text(
          widget.kind == CategoryKind.income ? 'Income category' : 'Category',
          style: theme.textTheme.titleLarge,
        ),
      );
      cells = [
        for (final c in cats.where((c) => c.parentId == null))
          _cell(
            theme,
            iconKey: c.iconKey,
            colorValue: c.colorValue,
            label: c.name,
            hasChildren: (childrenByParent[c.id]?.isNotEmpty) ?? false,
            onTap: () {
              if ((childrenByParent[c.id]?.isNotEmpty) ?? false) {
                setState(() => _drillParentId = c.id);
              } else {
                Navigator.of(context).pop(c.id);
              }
            },
          ),
      ];
    } else {
      header = Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 20, 12),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'All categories',
              onPressed: () => setState(() => _drillParentId = null),
            ),
            Expanded(
              child: Text(
                drillParent.name,
                style: theme.textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
      cells = [
        // Pick the parent itself, not one of its children.
        _cell(
          theme,
          iconKey: drillParent.iconKey,
          colorValue: drillParent.colorValue,
          label: 'All ${drillParent.name}',
          onTap: () => Navigator.of(context).pop(drillParent.id),
        ),
        for (final c in childrenByParent[drillParent.id] ?? const [])
          _cell(
            theme,
            iconKey: c.iconKey,
            colorValue: c.colorValue,
            label: c.name,
            onTap: () => Navigator.of(context).pop(c.id),
          ),
      ];
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Flexible(
          child: GridView.count(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
            children: cells,
          ),
        ),
      ],
    );
  }

  /// One tappable category chip. A small dot marks a parent that opens into
  /// subcategories rather than being picked directly.
  Widget _cell(
    ThemeData theme, {
    required String iconKey,
    required int colorValue,
    required String label,
    required VoidCallback onTap,
    bool hasChildren = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _iconCircle(iconKey, colorValue, size: 52),
              if (hasChildren)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
