import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/tables.dart';
import '../../features/about/about_screen.dart';
import '../../features/accounts/account_detail_screen.dart';
import '../../features/accounts/accounts_screen.dart';
import '../../features/accounts/archived_accounts_screen.dart';
import '../../features/add_transaction/add_transaction_screen.dart';
import '../../features/auto/auto_screen.dart';
import '../../features/budgets/budget_detail_screen.dart';
import '../../features/budgets/budgets_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/categories/categories_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/data_export/backup_screen.dart';
import '../../features/data_export/csv_import_screen.dart';
import '../../features/data_export/download_data_screen.dart';
import '../../features/message_capture/message_capture_screen.dart';
import '../../features/message_capture/review_inbox_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/payees/payee_detail_screen.dart';
import '../../features/payees/payees_screen.dart';
import '../../features/persons/archived_persons_screen.dart';
import '../../features/persons/person_detail_screen.dart';
import '../../features/persons/persons_screen.dart';
import '../../features/reports/account_reports_screen.dart';
import '../../features/reports/stats_screen.dart';
import '../../features/savings/savings_goal_detail_screen.dart';
import '../../features/savings/savings_goals_screen.dart';
import '../../features/security/set_passcode_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/widgets_screen.dart';
import '../../features/shopping/shopping_list_screen.dart';
import '../../features/shopping/shopping_lists_screen.dart';
import '../../features/tags/tags_screen.dart';
import '../../features/transactions/transaction_detail_screen.dart';
import '../../features/transactions/transactions_screen.dart';
import 'app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Shows a SnackBar from outside any screen's own `BuildContext` — e.g. a
/// share-intake result arriving in `app.dart`, which runs before any route's
/// `build` has necessarily settled. `_rootKey`'s context always has the
/// `ScaffoldMessenger` `MaterialApp.router` installs, same as any in-screen
/// `ScaffoldMessenger.of(context)` call. A no-op if the router isn't mounted
/// yet (there is nothing to show a SnackBar over).
void showAppSnackBar(String message, {SnackBarAction? action}) {
  final context = _rootKey.currentContext;
  if (context == null) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

/// The raw text ML Kit recognised off a shared screenshot XPENC couldn't
/// turn into a transaction. A rejected screenshot parse never reaches
/// `PendingTxns`, so without this there is no way to see what OCR actually
/// read — see `ShareIntakeRejected.recognizedText` and GitHub #25.
void showRecognizedTextDialog(String text) {
  final context = _rootKey.currentContext;
  if (context == null) return;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Recognised text'),
      content: SingleChildScrollView(
        child: SelectableText(
          text.trim().isEmpty ? '(nothing recognised)' : text,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

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
            GoRoute(path: '/persons', builder: (_, _) => const PersonsScreen()),
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
                  routes: [
                    GoRoute(
                      path: ':categoryId',
                      parentNavigatorKey: _rootKey,
                      builder: (_, state) => BudgetDetailScreen(
                        categoryId: int.parse(
                          state.pathParameters['categoryId']!,
                        ),
                      ),
                    ),
                  ],
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
                  routes: [
                    GoRoute(
                      path: 'passcode',
                      parentNavigatorKey: _rootKey,
                      builder: (_, state) => SetPasscodeScreen(
                        isRemoving:
                            state.uri.queryParameters['remove'] == 'true',
                      ),
                    ),
                    GoRoute(
                      path: 'widgets',
                      parentNavigatorKey: _rootKey,
                      builder: (_, _) => const WidgetsScreen(),
                    ),
                  ],
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
                  path: 'tags',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const TagsScreen(),
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
                  path: 'auto',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const AutoScreen(),
                ),
                GoRoute(
                  path: 'shopping',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const ShoppingListsScreen(),
                  routes: [
                    GoRoute(
                      path: ':id',
                      parentNavigatorKey: _rootKey,
                      builder: (_, state) => ShoppingListScreen(
                        listId: int.parse(state.pathParameters['id']!),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'savings',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const SavingsGoalsScreen(),
                  routes: [
                    GoRoute(
                      path: ':id',
                      parentNavigatorKey: _rootKey,
                      builder: (_, state) => SavingsGoalDetailScreen(
                        goalId: int.parse(state.pathParameters['id']!),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'accounts',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const AccountsScreen(),
                  routes: [
                    GoRoute(
                      path: 'archived',
                      parentNavigatorKey: _rootKey,
                      builder: (_, _) => const ArchivedAccountsScreen(),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'payees',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const PayeesScreen(),
                  routes: [
                    GoRoute(
                      path: ':name',
                      parentNavigatorKey: _rootKey,
                      builder: (_, state) => PayeeDetailScreen(
                        payee: Uri.decodeComponent(
                          state.pathParameters['name']!,
                        ),
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
        final type = switch (state.uri.queryParameters['type']) {
          'expense' => TxType.expense,
          'income' => TxType.income,
          _ => null,
        };
        return AddTransactionScreen(
          transactionId: id == null ? null : int.tryParse(id),
          initialType: type,
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
      path: '/import-csv',
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const CsvImportScreen(),
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

    GoRoute(
      path: '/person/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, state) =>
          PersonDetailScreen(personId: int.parse(state.pathParameters['id']!)),
    ),

    GoRoute(
      path: '/persons/archived',
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const ArchivedPersonsScreen(),
    ),
  ],
);
