import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Which accounts count toward Net Worth — shown wherever that figure
/// appears (Dashboard, Accounts screen total, More screen subtitle). Turn an
/// account off here (a savings goal you're not counting as spendable, a
/// second bank account you track separately) and its balance stops adding
/// to that number, while it keeps showing everywhere else exactly as before.
class DashboardSettingsScreen extends ConsumerWidget {
  const DashboardSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accountsAsync = ref.watch(balanceAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customize dashboard')),
      body: accountsAsync.when(
        data: (accounts) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
              child: Text(
                'Included in Net Worth',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            if (accounts.isEmpty)
              Text(
                'Add an account to see it here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < accounts.length; i++) ...[
                      if (i > 0) Divider(height: 1, indent: 60, color: cs.outline),
                      _AccountToggleTile(account: accounts[i]),
                    ],
                  ],
                ),
              ),
          ],
        ),
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            'Could not load your accounts.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountToggleTile extends ConsumerWidget {
  const _AccountToggleTile({required this.account});

  final AccountRow account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(account.colorValue);
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      secondary: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(AppIcons.resolve(account.iconKey), color: color, size: 20),
      ),
      title: Text(account.name),
      subtitle: BalanceText(
        account.currentBalance,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      value: account.includeInNetWorth,
      onChanged: (v) =>
          ref.read(dbProvider).setAccountIncludeInNetWorth(account.id, v),
    );
  }
}
