import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/l10n.dart';
import '../../core/money.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// Goals and loans hidden via **Archive** on their detail screens. They also
/// sit in Archived accounts, but nobody looks there for a goal — this is the
/// way back from Goals & Loans itself. Archiving never deletes anything.
class ArchivedGoalsLoansScreen extends ConsumerWidget {
  const ArchivedGoalsLoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final archivedAsync = ref.watch(archivedAccountsProvider);

    return Scaffold(
      appBar: AppTopBar(title: const Tr('Archived goals & loans')),
      body: archivedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Tr(
            "Couldn't load archived goals and loans.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        data: (accounts) {
          final goals = [
            for (final a in accounts)
              if (a.type == AccountType.goal) a,
          ];
          final loans = [
            for (final a in accounts)
              if (a.type == AccountType.loan) a,
          ];
          if (goals.isEmpty && loans.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
              child: Column(
                children: [
                  AppIcon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Tr(
                    'No archived goals or loans.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(
              vertical: 8,
            ).plusNavBar(context),
            children: [
              if (goals.isNotEmpty) ...[
                _SectionLabel(tr('Goals')),
                for (final a in goals) _ArchivedTile(account: a),
              ],
              if (loans.isNotEmpty) ...[
                _SectionLabel(tr('Loans')),
                for (final a in loans) _ArchivedTile(account: a),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _ArchivedTile extends ConsumerWidget {
  const _ArchivedTile({required this.account});

  final AccountRow account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = Color(account.colorValue);
    final isLoan = account.type == AccountType.loan;
    final balance = account.currentBalance;
    final subtitle = isLoan
        ? (balance.isNegative
              ? tr('{0} left', [MoneyFormat.symbol(balance.abs)])
              : tr('Paid off'))
        : tr('{0} saved', [MoneyFormat.symbol(balance)]);

    return AppListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: IconWell(
          AppIcons.resolve(account.iconKey),
          color: color,
          size: 22,
        ),
      ),
      title: Text(
        account.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: TextButton.icon(
        icon: const AppIcon(Icons.unarchive_outlined, size: 18),
        label: const Tr('Restore'),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          await ref.read(dbProvider).unarchiveAccount(account.id);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(tr('"{0}" restored', [account.name]))),
            );
        },
      ),
    );
  }
}
