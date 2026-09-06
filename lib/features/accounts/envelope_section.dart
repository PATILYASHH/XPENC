import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database.dart';
import '../../data/providers.dart';

/// The on-budget (pool participation) toggle for [account] — only shown
/// while Ready to Assign is on globally (GitHub #100 v2); there's nothing to
/// configure here until then. The shared Ready to Assign figure and category
/// envelope list this account feeds once it's on-budget live on
/// [lib/features/budgets/ready_to_assign_screen.dart] instead — GitHub #48:
/// every pool account pools into one figure and one balance per category, so
/// there's nothing account-scoped left to show here.
class EnvelopeSection extends ConsumerWidget {
  const EnvelopeSection({required this.account, super.key});

  final AccountRow account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(rtaEnabledProvider)) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final poolSize = ref.watch(envelopeModeAccountsProvider).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: SwitchListTile(
            title: const Text('On-budget'),
            subtitle: Text(
              account.envelopeMode
                  ? 'In the shared Ready to Assign pool. An expense needs a '
                        'category.'
                  : 'Off-budget — balance-only, like a vending-machine key '
                        'fob. Outside the shared pool.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            value: account.envelopeMode,
            onChanged: (v) => _onToggle(context, ref, v),
          ),
        ),
        if (account.envelopeMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(
                  poolSize > 1
                      ? 'Shares one Ready to Assign pool with '
                            '${poolSize - 1} other account'
                            '${poolSize - 1 == 1 ? '' : 's'}'
                      : 'Its own Ready to Assign pool for now',
                ),
                subtitle: const Text('View shared budget'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/more/ready-to-assign'),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _onToggle(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Mark this account on-budget?'),
          content: const Text(
            'Money you assign to a category becomes reserved for it. '
            'Unassigned money sits in Ready to Assign. From now on, an '
            'expense on this account needs a category.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Turn on'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    final rtaAutoDisabled = await ref
        .read(dbProvider)
        .setEnvelopeMode(account.id, enabled);
    if (rtaAutoDisabled && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ready to Assign turned off — this was the last account in the '
            'pool.',
          ),
        ),
      );
    }
  }
}
