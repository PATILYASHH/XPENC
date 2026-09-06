import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// Auto rules paused via **Pause** on [AutoScreen] — hidden from its main
/// list entirely (see GitHub #61) and gathered here instead. Restoring one
/// is the only way back; nothing is ever deleted by pausing.
class ArchivedAutoRulesScreen extends ConsumerWidget {
  const ArchivedAutoRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rules = ref.watch(archivedRecurringRulesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Archived auto rules')),
      body: rules.isEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No paused auto rules.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: rules.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 70),
              itemBuilder: (context, i) => _ArchivedRuleTile(rule: rules[i]),
            ),
    );
  }
}

class _ArchivedRuleTile extends ConsumerWidget {
  const _ArchivedRuleTile({required this.rule});

  final RecurringRuleRow rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isExpense = rule.kind == CategoryKind.expense;
    final color = isExpense ? AppColors.expense : AppColors.income;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        child: Icon(
          isExpense ? Icons.north_east_rounded : Icons.south_west_rounded,
        ),
      ),
      title: Text(
        rule.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        'Paused',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: TextButton.icon(
        icon: const Icon(Icons.unarchive_outlined, size: 18),
        label: const Text('Restore'),
        style: TextButton.styleFrom(foregroundColor: color),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          await ref.read(dbProvider).setRecurringActive(rule.id, true);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('"${rule.name}" restored')));
        },
      ),
    );
  }
}
