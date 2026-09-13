import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// The ➕ button's entry point (GitHub #125): "start from scratch" or pick a
/// saved template to prefill from. Only ever called when
/// [hasTransactionTemplatesProvider] is true — a user with no templates yet
/// still gets the old one-tap-straight-to-`/add` behaviour, unchanged.
Future<void> openAddTransactionChoiceSheet(BuildContext context) async {
  final result = await showModalBottomSheet<_AddChoiceResult>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _AddChoiceSheet(),
  );
  if (result == null || !context.mounted) return;
  context.push(
    result.templateId == null ? '/add' : '/add?template=${result.templateId}',
  );
}

class _AddChoiceResult {
  const _AddChoiceResult.blank() : templateId = null;
  const _AddChoiceResult.template(int id) : templateId = id;
  final int? templateId;
}

class _AddChoiceSheet extends ConsumerWidget {
  const _AddChoiceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final templates =
        ref.watch(transactionTemplatesProvider).valueOrNull ?? const [];
    final categoryMap = ref.watch(categoryMapProvider);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'New transaction',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline_rounded),
            title: const Text('Start from scratch'),
            subtitle: const Text('A blank transaction.'),
            onTap: () =>
                Navigator.of(context).pop(const _AddChoiceResult.blank()),
          ),
          if (templates.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'TEMPLATES',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
            for (final t in templates)
              ListTile(
                leading: Icon(iconForTxType(t.type), color: colorForTxType(t.type)),
                title: Text(t.name),
                subtitle: Text(_subtitle(t, categoryMap)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete template',
                  onPressed: () => _confirmDelete(context, ref, t),
                ),
                onTap: () => Navigator.of(
                  context,
                ).pop(_AddChoiceResult.template(t.id)),
              ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _subtitle(TransactionTemplateRow t, Map<int, CategoryRow> categoryMap) {
    final amount = MoneyFormat.symbol(t.amount);
    final category = t.categoryId == null ? null : categoryMap[t.categoryId]?.name;
    final label = category ?? labelForTxType(t.type);
    return '$amount · $label';
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TransactionTemplateRow t,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${t.name}"?'),
        content: const Text(
          "This only removes the template — transactions already made from "
          "it are untouched.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(dbProvider).deleteTransactionTemplate(t.id);
  }
}
