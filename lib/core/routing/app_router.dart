import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/accounts_screen.dart';
import '../../features/add_transaction/add_transaction_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/transactions/transactions_screen.dart';
import 'app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/dashboard',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/transactions',
              builder: (_, _) => const TransactionsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/accounts',
              builder: (_, _) => const AccountsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/more',
              builder: (_, _) => const MoreScreen(),
            ),
          ],
        ),
      ],
    ),

    // Pushed above the shell — the ➕ button, not a tab.
    GoRoute(
      path: '/add',
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const AddTransactionScreen(),
    ),
  ],
);
