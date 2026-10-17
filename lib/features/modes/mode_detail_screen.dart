import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/database.dart';
import '../../data/mode_providers.dart';
import '../../data/modes_db.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'mode_widgets.dart';

/// A mode's own page (`/mode/:id`): the whole story of a trip — what it
/// came to, where it went, and every transaction in it. The one line a mode
/// becomes in the everyday app opens here.
class ModeDetailScreen extends ConsumerWidget {
  const ModeDetailScreen({required this.modeId, super.key});

  final int modeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final modesAsync = ref.watch(modesProvider);
    final mode = ref.watch(modeMapProvider)[modeId];
    if (mode == null) {
      return Scaffold(
        appBar: AppTopBar(title: const Text('Mode')),
        body: Center(
          child: modesAsync.isLoading
              ? const CircularProgressIndicator()
              : const Text('This mode no longer exists'),
        ),
      );
    }

    final summary = ref.watch(modeSummaryProvider(modeId));
    final txs = ref.watch(modeTransactionsProvider(modeId));
    final categories = ref.watch(categoryMapProvider);
    final accounts = ref.watch(accountMapProvider);
    final group = mode.groupId == null
        ? null
        : ref.watch(allGroupsMapProvider)[mode.groupId];
    final byCategory = summary.byCategory.entries.toList()
      ..sort((a, b) => b.value.paise.compareTo(a.value.paise));
    final byAccount = summary.byAccount.entries.toList()
      ..sort((a, b) => b.value.paise.compareTo(a.value.paise));

    return Scaffold(
      appBar: AppTopBar(
        title: Text(mode.name),
        actions: [
          IconButton(
            icon: const AppIcon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => context.push('/mode/${mode.id}/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') _delete(context, ref, mode);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete mode')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32).plusNavBar(context),
        children: [
          _Header(mode: mode),
          const SizedBox(height: 12),
          ModeSpendCard(
            mode: mode,
            summary: summary,
            currencyNote: mode.currencyCode,
          ),
          if (byCategory.isNotEmpty) ...[
            modeSectionLabel(theme, 'BY CATEGORY'),
            AppCard(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, e) in byCategory.indexed) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 60,
                        color: theme.colorScheme.outline,
                      ),
                    ModeShareRow(
                      iconKey: categories[e.key]?.iconKey ?? 'other',
                      colorValue:
                          categories[e.key]?.colorValue ??
                          theme.colorScheme.onSurfaceVariant.toARGB32(),
                      label: categories[e.key]?.name ?? 'Uncategorised',
                      amount: e.value,
                      total: summary.spent,
                      onTap: categories[e.key] == null
                          ? null
                          : () => context.push('/more/categories/${e.key}'),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (byAccount.length > 1) ...[
            modeSectionLabel(theme, 'BY ACCOUNT'),
            AppCard(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, e) in byAccount.indexed) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 60,
                        color: theme.colorScheme.outline,
                      ),
                    ModeShareRow(
                      iconKey: accounts[e.key]?.iconKey ?? 'bank',
                      colorValue:
                          accounts[e.key]?.colorValue ??
                          theme.colorScheme.onSurfaceVariant.toARGB32(),
                      label: accounts[e.key]?.name ?? 'Account',
                      amount: e.value,
                      total: summary.spent,
                      onTap: () => context.push('/account/${e.key}'),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (group != null) ...[
            modeSectionLabel(theme, 'GROUP'),
            AppCard(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: AppListTile(
                leading: const AppIcon(Icons.groups_outlined),
                title: Text(group.name),
                subtitle: const Text('Its expenses join this mode'),
                trailing: MoneyText(
                  ref.watch(groupBalanceProvider(group.id)),
                  signed: true,
                ),
                onTap: () => context.push('/group/${group.id}'),
              ),
            ),
          ],
          modeSectionLabel(theme, 'TRANSACTIONS'),
          if (txs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                mode.status == ModeStatus.active
                    ? 'Everything you add now joins ${mode.name}.'
                    : 'Nothing in ${mode.name} yet.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final t in txs) ModeTxRow(t),
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ModeRow mode,
  ) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${mode.name}?'),
        content: const Text(
          'Its transactions stay exactly as they are — they just stop being '
          'in a mode. Its own categories are archived, its own tags become '
          'everyday tags.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final router = GoRouter.of(context);
    await ref.read(dbProvider).deleteMode(mode.id);
    if (router.canPop()) router.pop();
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.mode});

  final ModeRow mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ModeBadge(mode, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    modeStatusLine(mode, DateTime.now()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (mode.status == ModeStatus.active)
              OutlinedButton(
                onPressed: () => endModeWithConfirm(context, ref, mode),
                child: const Text('End'),
              )
            else
              FilledButton(
                onPressed: () => startModeWithConfirm(context, ref, mode),
                child: Text(
                  mode.status == ModeStatus.ended ? 'Restart' : 'Start',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// [Money] spent in the mode the way a list row says it: "−₹18,400".
String modeSpentLabel(Money spent) =>
    spent.isZero ? 'Nothing spent' : '−${MoneyFormat.symbol(spent)}';
