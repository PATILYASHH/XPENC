import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Accounts hidden via **Archive** on the Accounts screen. Restoring one here
/// is the only way back — archiving never deletes anything, so this list is
/// never empty for long if someone's been tidying up.
class ArchivedAccountsScreen extends ConsumerWidget {
  const ArchivedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final archivedAsync = ref.watch(archivedAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Archived accounts')),
      body: archivedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            "Couldn't load archived accounts.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return Padding(
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
                    'No archived accounts.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: accounts.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 70),
            itemBuilder: (context, i) =>
                _ArchivedAccountTile(account: accounts[i]),
          );
        },
      ),
    );
  }
}

class _ArchivedAccountTile extends ConsumerWidget {
  const _ArchivedAccountTile({required this.account});

  final AccountRow account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = Color(account.colorValue);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(AppIcons.resolve(account.iconKey), color: color, size: 22),
      ),
      title: Text(
        account.name,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        'Archived',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: TextButton.icon(
        icon: const Icon(Icons.unarchive_outlined, size: 18),
        label: const Text('Restore'),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          await ref.read(dbProvider).unarchiveAccount(account.id);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('"${account.name}" restored')),
            );
        },
      ),
    );
  }
}
