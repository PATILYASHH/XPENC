import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/about_screen.dart';
import '../../features/accounts/account_detail_screen.dart';
import '../../features/accounts/accounts_screen.dart';
import '../../features/add_transaction/add_transaction_screen.dart';
import '../../features/budgets/budgets_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/categories/categories_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/data_export/backup_screen.dart';
import '../../features/data_export/download_data_screen.dart';
import '../../features/message_capture/message_capture_screen.dart';
import '../../features/message_capture/review_inbox_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/persons/person_detail_screen.dart';
import '../../features/persons/persons_screen.dart';
import '../../features/reports/account_reports_screen.dart';
import '../../features/reports/stats_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/transactions/transaction_detail_screen.dart';
import '../../features/transactions/transactions_screen.dart';
import 'app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Detail screens push above the shell (`parentNavigatorKey: _rootKey`) so they
/// get a back button and hide the bottom bar, One UI style.
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
              routes: [
                GoRoute(
                  path: 'budgets',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const BudgetsScreen(),
                ),
                GoRoute(
                  path: 'calendar',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const CalendarScreen(),
                ),
                GoRoute(
                  path: 'settings',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const SettingsScreen(),
                ),
                GoRoute(
                  path: 'about',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const AboutScreen(),
                ),
                GoRoute(
                  path: 'capture',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const MessageCaptureScreen(),
                ),
                GoRoute(
                  path: 'categories',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const CategoriesScreen(),
                ),
                GoRoute(
                  path: 'stats',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const StatsScreen(),
                ),
                GoRoute(
                  path: 'account-reports',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const AccountReportsScreen(),
                ),
                GoRoute(
                  path: 'export',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const DownloadDataScreen(),
                ),
                GoRoute(
                  path: 'backup',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const BackupScreen(),
                ),
                GoRoute(
                  path: 'persons',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const PersonsScreen(),
                  routes: [
                    GoRoute(
                      path: ':id',
                      parentNavigatorKey: _rootKey,
                      builder: (_, state) => PersonDetailScreen(
                        personId: int.parse(state.pathParameters['id']!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // First run.
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const OnboardingScreen(),
    ),

    // The ➕ button — a route pushed above the shell, not a tab.
    // With an `id` it edits that transaction instead of creating one.
    GoRoute(
      path: '/add',
      parentNavigatorKey: _rootKey,
      builder: (_, state) {
        final id = state.uri.queryParameters['id'];
        return AddTransactionScreen(
          transactionId: id == null ? null : int.tryParse(id),
        );
      },
    ),

    // Detected bank transactions awaiting review.
    GoRoute(
      path: '/inbox',
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const ReviewInboxScreen(),
    ),

    GoRoute(
      path: '/transaction/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, state) => TransactionDetailScreen(
        transactionId: int.parse(state.pathParameters['id']!),
      ),
    ),

    GoRoute(
      path: '/account/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, state) => AccountDetailScreen(
        accountId: int.parse(state.pathParameters['id']!),
      ),
    ),
  ],
);
