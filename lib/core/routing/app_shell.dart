import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// `Dashboard · Transactions · ➕ · Accounts · More`
///
/// The ➕ slot is not a tab — it pushes the Add Transaction route. Tabs map to
/// shell branches 0,1,2,3 while sitting at bar slots 0,1,3,4.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _tabs = <_TabSpec>[
    _TabSpec(0, Icons.pie_chart_outline_rounded, Icons.pie_chart_rounded,
        'Dashboard'),
    _TabSpec(1, Icons.receipt_long_outlined, Icons.receipt_long_rounded,
        'Transactions'),
    _TabSpec(2, Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet_rounded, 'Accounts'),
    _TabSpec(3, Icons.grid_view_outlined, Icons.grid_view_rounded, 'More'),
  ];

  void _goBranch(int branchIndex) {
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.colorScheme.outline;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                _navItem(context, _tabs[0]),
                _navItem(context, _tabs[1]),
                _addButton(context),
                _navItem(context, _tabs[2]),
                _navItem(context, _tabs[3]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, _TabSpec tab) {
    final theme = Theme.of(context);
    final selected = navigationShell.currentIndex == tab.branch;
    final color = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: () => _goBranch(tab.branch),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? tab.activeIcon : tab.icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addButton(BuildContext context) {
    return Expanded(
      child: Center(
        child: Material(
          color: Theme.of(context).colorScheme.secondary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.push('/add'),
            child: const SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.branch, this.icon, this.activeIcon, this.label);
  final int branch;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
