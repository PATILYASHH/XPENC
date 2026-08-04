import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// One shopping list's items — not linked to the ledger. Checking an item
/// off just marks it bought; logging the actual expense (if any) happens
/// separately, the normal way.
class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({required this.listId, super.key});

  final int listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final listsAsync = ref.watch(shoppingListsProvider);
    final itemsAsync = ref.watch(shoppingItemsProvider(listId));

    ShoppingListRow? list;
    for (final l in listsAsync.valueOrNull ?? const <ShoppingListRow>[]) {
      if (l.id == listId) {
        list = l;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(list?.name ?? 'Shopping List'),
        actions: [
          if (list case final currentList?)
            PopupMenuButton<_ListAction>(
              onSelected: (action) => switch (action) {
                _ListAction.rename => _renameList(context, ref, currentList),
                _ListAction.delete => _deleteList(context, ref, currentList),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _ListAction.rename,
                  child: Text('Rename list'),
                ),
                PopupMenuItem(
                  value: _ListAction.delete,
                  child: Text('Delete list'),
                ),
              ],
            ),
          itemsAsync.maybeWhen(
            data: (items) => items.any((i) => i.isChecked)
                ? IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Clear checked items',
                    onPressed: () =>
                        ref.read(dbProvider).clearCheckedShoppingItems(listId),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            "Couldn't load this list.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
              child: Column(
                children: [
                  Icon(
                    Icons.checklist_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nothing here yet — tap + to add something.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          final unchecked = items.where((i) => !i.isChecked).toList();
          final estimatedTotal = unchecked.fold(
            const Money.zero(),
            (sum, i) => sum + (i.estimatedAmount ?? const Money.zero()),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            children: [
              if (unchecked.isNotEmpty && !estimatedTotal.isZero)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Estimated total',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            MoneyFormat.symbol(estimatedTotal),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 56,
                          color: theme.colorScheme.outline,
                        ),
                      _ShoppingItemTile(item: items[i]),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add item',
        onPressed: () => _openItemEditor(context, listId),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _renameList(
    BuildContext context,
    WidgetRef ref,
    ShoppingListRow list,
  ) async {
    final controller = TextEditingController(text: list.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename list'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 60,
          decoration: const InputDecoration(counterText: ''),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = newName?.trim();
    if (trimmed == null || trimmed.isEmpty || !context.mounted) return;
    await ref
        .read(dbProvider)
        .updateShoppingList(
          id: list.id,
          name: trimmed,
          colorValue: list.colorValue,
        );
  }

  Future<void> _deleteList(
    BuildContext context,
    WidgetRef ref,
    ShoppingListRow list,
  ) async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${list.name}"?'),
        content: const Text('This removes the list and everything on it.'),
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
    await ref.read(dbProvider).deleteShoppingList(list.id);
    if (navigator.canPop()) navigator.pop();
  }
}

enum _ListAction { rename, delete }

class _ShoppingItemTile extends ConsumerWidget {
  const _ShoppingItemTile({required this.item});

  final ShoppingItemRow item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Slidable(
      key: ValueKey(item.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => ref.read(dbProvider).deleteShoppingItem(item.id),
            backgroundColor: AppColors.expense,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 4, right: 16),
        onTap: () => _openItemEditor(context, item.listId!, existing: item),
        leading: Checkbox(
          value: item.isChecked,
          onChanged: (v) =>
              ref.read(dbProvider).setShoppingItemChecked(item.id, v ?? false),
        ),
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            decoration: item.isChecked ? TextDecoration.lineThrough : null,
            color: item.isChecked ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
        trailing: item.estimatedAmount == null
            ? null
            : Text(
                MoneyFormat.symbol(item.estimatedAmount!),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  decoration: item.isChecked
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
      ),
    );
  }
}

Future<void> _openItemEditor(
  BuildContext context,
  int listId, {
  ShoppingItemRow? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ItemEditorSheet(listId: listId, existing: existing),
  );
}

class _ItemEditorSheet extends ConsumerStatefulWidget {
  const _ItemEditorSheet({required this.listId, this.existing});

  final int listId;
  final ShoppingItemRow? existing;

  @override
  ConsumerState<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends ConsumerState<_ItemEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _amountController = TextEditingController(
      text: widget.existing?.estimatedAmount == null
          ? ''
          : MoneyFormat.bare(widget.existing!.estimatedAmount!),
    );
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

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Give the item a name.');
      return;
    }
    final amount = Money.tryParse(_amountController.text);

    setState(() => _submitting = true);
    final db = ref.read(dbProvider);
    try {
      if (_isEdit) {
        await db.updateShoppingItem(
          id: widget.existing!.id,
          name: name,
          estimatedAmount: amount,
        );
      } else {
        await db.addShoppingItem(
          listId: widget.listId,
          name: name,
          estimatedAmount: amount,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Could not save the item.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Edit item' : 'New item',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Item',
                hintText: 'e.g. Milk, New shoes',
                counterText: '',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Estimated price (optional)',
                prefixText: '₹ ',
                hintText: '0.00',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 24),
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
}
