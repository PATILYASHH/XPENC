import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/providers.dart';

/// Who you pay, or who pays you. Derived from the `payee` typed on each
/// expense or income (GitHub #62) — there is no separate table, so this
/// screen is a grouped view, not a CRUD list.
///
/// [embedded] is true when this screen is a bottom-nav tab (GitHub #70) —
/// `AppShell`'s shared top bar owns the title then. Default `false` keeps
/// `/more/payees` exactly as it was.
class PayeesScreen extends ConsumerWidget {
  const PayeesScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summaries = ref.watch(payeeSummariesProvider);
    final net = summaries.fold(const Money.zero(), (sum, s) => sum + s.net);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          if (!embedded) SliverAppBar(pinned: true, title: const Text('Payees')),
          SliverToBoxAdapter(
            child: _TotalsHeader(net: net, count: summaries.length),
          ),
          if (summaries.isEmpty)
            const SliverToBoxAdapter(child: _EmptyPayees())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < summaries.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 72,
                            color: theme.colorScheme.outline,
                          ),
                        _PayeeTile(summary: summaries[i]),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _TotalsHeader extends StatelessWidget {
  const _TotalsHeader({required this.net, required this.count});

  final Money net;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          child: Column(
            children: [
              MoneyText(
                net,
                signed: true,
                color: net.isNegative ? AppColors.expense : AppColors.income,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                count == 1 ? 'Net across 1 payee' : 'Net across $count payees',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One payee row. Tap to see every expense paid to them.
class _PayeeTile extends StatelessWidget {
  const _PayeeTile({required this.summary});

  final PayeeSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = summary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurface,
        child: Text(
          _initials(s.payee),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      title: Text(
        s.payee,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        s.count == 1 ? '1 transaction' : '${s.count} transactions',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 128),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: MoneyText(
            s.net,
            signed: true,
            color: s.net.isNegative ? AppColors.expense : AppColors.income,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      onTap: () => context.push('/more/payees/${Uri.encodeComponent(s.payee)}'),
    );
  }
}

class _EmptyPayees extends StatelessWidget {
  const _EmptyPayees();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      child: Column(
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No payees yet — name one on an expense or income to see it here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-letter initials from a name, e.g. "Rahul Kumar" -> "RK".
String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
