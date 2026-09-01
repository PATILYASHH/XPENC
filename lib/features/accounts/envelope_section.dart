import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database.dart';
import '../../data/providers.dart';

/// The Envelope Mode toggle for [account]. The shared Ready to Assign figure
/// and category envelope list this account feeds once it's on live on
/// [lib/features/budgets/ready_to_assign_screen.dart] instead — GitHub #48:
/// every Envelope-Mode account pools into one figure and one balance per
/// category, so there's nothing account-scoped left to show here.
class EnvelopeSection extends ConsumerWidget {
  const EnvelopeSection({required this.account, super.key});

  final AccountRow account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final poolSize = ref.watch(envelopeModeAccountsProvider).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: SwitchListTile(
            title: const Text('Envelope Mode'),
            subtitle: Text(
              account.envelopeMode
                  ? 'Every rupee here has a job. An expense needs a category.'
                  : 'Optional — "every rupee has a job" budgeting for just '
                        'this account.',
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
          title: const Text('Turn on Envelope Mode?'),
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
    await ref.read(dbProvider).setEnvelopeMode(account.id, enabled);
  }
}
