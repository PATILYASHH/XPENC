import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/currency.dart';
import '../core/home_widget/home_widget_service.dart';
import '../core/money.dart';
import '../core/notifications/notification_service.dart';
import '../core/theme/font_options.dart';
import '../core/theme/theme_preset.dart';
import '../features/data_export/backup_service.dart';
import '../features/message_capture/capture_service.dart';
import '../features/message_capture/message_source.dart';
import '../features/message_capture/share_intake.dart';
import '../features/transactions/transaction_filters.dart';
import 'database.dart';
import 'tables.dart';

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Opens the database once at startup and surfaces the failure loudly.
///
/// Drift opens lazily on first query, so a broken native library (a missing
/// `libsqlite3.so`, for instance) used to show up as every screen spinning
/// forever. Touching the DB here turns that into a visible error with a retry.
final databaseReadyProvider = FutureProvider<bool>((ref) async {
  await ref.watch(dbProvider).getSettings();
  return true;
});

// ── Accounts ────────────────────────────────────────────────────────────────

final accountsProvider = StreamProvider<List<AccountRow>>(
  (ref) => ref.watch(dbProvider).watchAccounts(),
);

final archivedAccountsProvider = StreamProvider<List<AccountRow>>(
  (ref) => ref.watch(dbProvider).watchArchivedAccounts(),
);

/// Accounts that hold money. Debit cards / UPI instruments excluded.
final balanceAccountsProvider = StreamProvider<List<AccountRow>>(
  (ref) => ref.watch(dbProvider).watchBalanceHoldingAccounts(),
);

final netWorthProvider = StreamProvider<Money>(
  (ref) => ref.watch(dbProvider).watchNetWorth(),
);

// ── Categories ──────────────────────────────────────────────────────────────

final categoriesProvider =
    StreamProvider.family<List<CategoryRow>, CategoryKind>(
      (ref, kind) => ref.watch(dbProvider).watchCategories(kind),
    );

/// Every category, keyed by id — for resolving names/icons on list rows.
final categoryMapProvider = Provider<Map<int, CategoryRow>>((ref) {
  final income =
      ref.watch(categoriesProvider(CategoryKind.income)).valueOrNull ?? [];
  final expense =
      ref.watch(categoriesProvider(CategoryKind.expense)).valueOrNull ?? [];
  return {
    for (final c in [...income, ...expense]) c.id: c,
  };
});

/// A category's top-level ancestor. The tree is two deep, so a child resolves
/// to its parent and a parent (or an unknown id) resolves to itself. Used to
/// roll subcategory spend up into the parent it belongs to.
int topLevelCategoryId(Map<int, CategoryRow> byId, int id) {
  final parent = byId[id]?.parentId;
  return parent ?? id;
}

/// Re-keys a per-category map onto top-level parents, summing children into the
/// parent they roll up under. A spend map keyed by leaf category becomes a spend
/// map keyed by parent — the shape the dashboard and reports show.
Map<int, Money> rollUpToParents(
  Map<int, Money> byCategory,
  Map<int, CategoryRow> byId,
) {
  final out = <int, Money>{};
  byCategory.forEach((id, amount) {
    final top = topLevelCategoryId(byId, id);
    out[top] = (out[top] ?? const Money.zero()) + amount;
  });
  return out;
}

final accountMapProvider = Provider<Map<int, AccountRow>>((ref) {
  final accounts = ref.watch(accountsProvider).valueOrNull ?? [];
  return {for (final a in accounts) a.id: a};
});

// ── Transactions ────────────────────────────────────────────────────────────

final recentTransactionsProvider = StreamProvider<List<TransactionRow>>(
  (ref) => ref.watch(dbProvider).watchTransactions(limit: 8),
);

final allTransactionsProvider = StreamProvider<List<TransactionRow>>(
  (ref) => ref.watch(dbProvider).watchTransactions(),
);

/// The month currently being viewed. Defaults to this month.
final selectedMonthProvider = StateProvider<DateTime>(
  (ref) => DateTime(DateTime.now().year, DateTime.now().month),
);

final monthTotalsProvider = StreamProvider<({Money income, Money expense})>((
  ref,
) {
  final month = ref.watch(selectedMonthProvider);
  return ref.watch(dbProvider).watchMonthTotals(month);
});

/// Stats-screen only: false shows one month (the existing, shared
/// [selectedMonthProvider] behaviour Dashboard and Budgets also depend on),
/// true shows the whole calendar year of [selectedMonthProvider]'s year.
/// Deliberately local to Stats — [spendByCategoryProvider] below stays
/// month-only so nothing else silently starts aggregating a year.
final statsShowYearProvider = StateProvider<bool>((ref) => false);

/// The "Spending by category" pie: main categories (rolled up, the default)
/// or a per-subcategory breakdown. See GitHub #40.
final statsShowSubcategoriesProvider = StateProvider<bool>((ref) => false);

/// Stats "Standings" section: ranks either individual transactions or
/// categories (the latter respecting [statsShowSubcategoriesProvider], same
/// grouping as the pie above). See GitHub #95.
enum StandingsMetric { transactions, categories }

final statsStandingsMetricProvider = StateProvider<StandingsMetric>(
  (ref) => StandingsMetric.transactions,
);

/// Standings sort direction: false (the default) ranks the highest amount
/// first; true reverses it to lowest first.
final statsStandingsAscendingProvider = StateProvider<bool>((ref) => false);

// ── Transactions search & filter ───────────────────────────────────────────
// Shared between the shared top bar (which owns the search/filter buttons —
// see `AppShell`) and `TransactionsScreen` (which applies them to the list),
// since the buttons no longer live inside the screen they act on.

final txSearchActiveProvider = StateProvider<bool>((ref) => false);
final txSearchQueryProvider = StateProvider<String>((ref) => '');

/// `null` == the "All" chip.
final txQuickFilterProvider = StateProvider<TxType?>((ref) => null);

/// The "Linked" chip — narrows the list to transactions with at least one
/// manual link and regroups it by link-cluster instead of by day (GitHub
/// #68). Mutually exclusive with [txQuickFilterProvider] in the UI (see
/// `_FilterChips` in `transactions_screen.dart`), not enforced here.
final txLinkedOnlyProvider = StateProvider<bool>((ref) => false);

final txAdvancedFiltersProvider = StateProvider<TransactionFilters>(
  (ref) => const TransactionFilters(),
);

/// Bumped by `AppShell` whenever the Transactions tab is tapped while it's
/// already the active tab, so `TransactionsScreen` can scroll itself back to
/// the top — see GitHub #66. The value itself is meaningless, only the change
/// matters (a `ref.listen` trigger).
final txScrollToTopProvider = StateProvider<int>((ref) => 0);

/// Bumped by `AppShell`'s top bar when Calendar is the active tab and its
/// "Today" action is tapped — `CalendarScreen` listens and jumps to today.
/// The value itself is meaningless, only the change matters, same idiom as
/// `txScrollToTopProvider` above (GitHub #70).
final calendarGoToTodaySignalProvider = StateProvider<int>((ref) => 0);

/// Same idiom, for the "New reminder" action.
final calendarNewReminderSignalProvider = StateProvider<int>((ref) => 0);

/// Same split-aware category aggregation as [spendByCategoryProvider], for a
/// whole calendar year instead of one month — composed locally so the
/// shared, month-scoped provider never has to know "year" exists.
final yearSpendByCategoryProvider = Provider.family<Map<int, Money>, int>((
  ref,
  year,
) {
  final txs = ref.watch(allTransactionsProvider).valueOrNull ?? const [];
  final splitsByTx = ref.watch(transactionSplitsByTxProvider);
  final out = <int, Money>{};
  for (final t in txs) {
    if (t.type != TxType.expense || t.date.year != year) continue;
    if (t.categoryId != null) {
      out[t.categoryId!] =
          (out[t.categoryId!] ?? const Money.zero()) + t.amount;
    } else {
      for (final s in splitsByTx[t.id] ?? const []) {
        out[s.categoryId] =
            (out[s.categoryId] ?? const Money.zero()) + s.amount;
      }
    }
  }
  return out;
});

final spendByCategoryProvider = StreamProvider<Map<int, Money>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final start = DateTime(month.year, month.month);
  final end = DateTime(
    month.year,
    month.month + 1,
  ).subtract(const Duration(milliseconds: 1));
  return ref.watch(dbProvider).watchSpendByCategory(start, end);
});

// ── Budgets ─────────────────────────────────────────────────────────────────

final budgetsProvider = StreamProvider<List<BudgetRow>>(
  (ref) => ref.watch(dbProvider).watchBudgets(),
);

/// One expense line on a category's Budget Detail page — either a normal
/// transaction wholly in that category, or one leg of a split expense, in
/// which case [amount] is that leg's slice, not the whole transaction.
typedef CategoryTx = ({TransactionRow tx, Money amount, bool isSplit});

/// Every expense in [categoryId] for the currently [selectedMonthProvider]
/// window — a parent category also pulls in its live children's spend, same
/// roll-up rule [budgetProgressProvider] already uses, so the numbers on this
/// page always agree with the summary tile that links to it.
final categoryTransactionsProvider = Provider.family<List<CategoryTx>, int>((
  ref,
  categoryId,
) {
  final month = ref.watch(selectedMonthProvider);
  final start = DateTime(month.year, month.month);
  final end = DateTime(
    month.year,
    month.month + 1,
  ).subtract(const Duration(milliseconds: 1));

  final cats = ref.watch(categoryMapProvider);
  final categoryIds = {
    categoryId,
    for (final c in cats.values)
      if (c.parentId == categoryId) c.id,
  };

  final txs = ref.watch(allTransactionsProvider).valueOrNull ?? const [];
  final splitsByTx = ref.watch(transactionSplitsByTxProvider);

  final out = <CategoryTx>[];
  for (final t in txs) {
    if (t.date.isBefore(start) || t.date.isAfter(end)) continue;
    if (t.type == TxType.expense) {
      if (t.categoryId != null) {
        if (categoryIds.contains(t.categoryId)) {
          out.add((tx: t, amount: t.amount, isSplit: false));
        }
        continue;
      }
      for (final s in splitsByTx[t.id] ?? const []) {
        if (categoryIds.contains(s.categoryId)) {
          out.add((tx: t, amount: s.amount, isSplit: true));
        }
      }
      continue;
    }
    // A categorized goal/loan transfer counts toward category drill-down.
    if (t.type == TxType.transfer && t.categoryId != null) {
      if (categoryIds.contains(t.categoryId)) {
        out.add((tx: t, amount: t.amount, isSplit: false));
      }
    }
  }
  out.sort((a, b) => b.tx.date.compareTo(a.tx.date));
  return out;
});

/// A budget joined with what has actually been spent this period.
typedef BudgetProgress = ({
  BudgetRow budget,
  CategoryRow category,
  Money spent,
  double fraction,
  bool overspent,
  bool nearingLimit,
});

final budgetProgressProvider = Provider<List<BudgetProgress>>((ref) {
  final budgets = ref.watch(budgetsProvider).valueOrNull ?? [];
  final spend = ref.watch(spendByCategoryProvider).valueOrNull ?? {};
  final cats = ref.watch(categoryMapProvider);

  final out = <BudgetProgress>[];
  for (final b in budgets) {
    final cat = cats[b.categoryId];
    if (cat == null) continue;
    // A budget on a parent covers its whole subtree: the category's own spend
    // plus every live child's. A budget on a child (or a childless category)
    // is just its own line.
    var spent = spend[b.categoryId] ?? const Money.zero();
    for (final c in cats.values) {
      if (c.parentId == b.categoryId) {
        spent += spend[c.id] ?? const Money.zero();
      }
    }
    final fraction = b.amount.isZero ? 0.0 : spent.paise / b.amount.paise;
    out.add((
      budget: b,
      category: cat,
      spent: spent,
      fraction: fraction,
      overspent: fraction > 1.0,
      nearingLimit: fraction >= b.alertThresholdPct / 100 && fraction <= 1.0,
    ));
  }
  out.sort((a, b) => b.fraction.compareTo(a.fraction));
  return out;
});

/// The Budgets home-screen widget's content — the same most-pressing-first
/// order [budgetProgressProvider] already sorts into, capped to however
/// many rows the widget's static layout has. See `HomeWidgetService`.
final widgetBudgetSummaryProvider = Provider<List<WidgetBudgetLine>>((ref) {
  final progress = ref.watch(budgetProgressProvider);
  return [
    for (final p in progress.take(HomeWidgetService.maxBudgetLines))
      (name: p.category.name, spent: p.spent, limit: p.budget.amount),
  ];
});

/// The "This Month" home-screen widget's content — this calendar month's
/// income and expense totals. Deliberately not [monthTotalsProvider]: that
/// one follows [selectedMonthProvider], which Stats/Calendar can point at a
/// different month, and the widget must always mean "this month", not
/// "whatever month was last browsed". See `HomeWidgetService`.
final widgetMonthSummaryProvider = Provider<({Money income, Money expense})>((
  ref,
) {
  final months = ref.watch(monthlyTotalsProvider(1));
  if (months.isEmpty) {
    return (income: const Money.zero(), expense: const Money.zero());
  }
  final current = months.single;
  return (income: current.income, expense: current.expense);
});

// ── Envelope Mode ────────────────────────────────────────────────────────────
//
// `category_balance` and `ready_to_assign` are derived here, reactively,
// from `allocations` + the ledger — never stored as a column. That is
// exactly the discipline that would have prevented the 1.3.0 parent/child
// budget double-count bug: a derived money value must be recomputed from its
// source rows every time, not cached and trusted.

final allAllocationsProvider = StreamProvider<List<AllocationRow>>(
  (ref) => ref.watch(dbProvider).watchAllAllocations(),
);

/// Every allocation, summed per (account, category) — see
/// [Allocations.amount] for the sign convention.
final _envelopeAllocatedProvider = Provider<Map<(int, int), Money>>((ref) {
  final rows = ref.watch(allAllocationsProvider).valueOrNull ?? const [];
  final out = <(int, int), Money>{};
  for (final a in rows) {
    final key = (a.accountId, a.categoryId);
    out[key] = (out[key] ?? const Money.zero()) + a.amount;
  }
  return out;
});

/// Every expense, summed per (account, category) it was actually paid from —
/// unlike [spendByCategoryProvider], this is scoped to one account (Envelope
/// Mode is per-account) and carries no month window (an envelope's balance
/// rolls forward, it never resets). Split legs count toward whichever
/// category they name, same as [spendByCategoryProvider].
final _envelopeSpentProvider = Provider<Map<(int, int), Money>>((ref) {
  final txs = ref.watch(allTransactionsProvider).valueOrNull ?? const [];
  final splitsByTx = ref.watch(transactionSplitsByTxProvider);

  final out = <(int, int), Money>{};
  void add(int accountId, int categoryId, Money amount) {
    final key = (accountId, categoryId);
    out[key] = (out[key] ?? const Money.zero()) + amount;
  }

  for (final t in txs) {
    if (t.type != TxType.expense) continue;
    if (t.categoryId != null) {
      add(t.accountId, t.categoryId!, t.amount);
    } else {
      for (final s in splitsByTx[t.id] ?? const []) {
        add(t.accountId, s.categoryId, s.amount);
      }
    }
  }
  return out;
});

/// Every account currently in Envelope Mode, in the same order
/// `watchAccounts()` returns (by `sortOrder`) — the shared "which accounts
/// feed the pool" set behind [categoryBalanceProvider] and
/// [readyToAssignProvider]. GitHub #48: multiple accounts can each opt in,
/// but there is exactly one pool across all of them, not one per account.
final envelopeModeAccountsProvider = Provider<List<AccountRow>>((ref) {
  final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
  return [
    for (final a in accounts)
      if (a.envelopeMode) a,
  ];
});

/// The account [addAllocation]/[moveAllocation] record a manual assign
/// against when there's no real transaction-level account to attribute it
/// to (e.g. a move made from the shared Ready to Assign screen rather than
/// alongside a specific transfer). Purely an audit trail — see
/// [Allocations.accountId] — never read back by [categoryBalanceProvider]
/// or [readyToAssignProvider], both of which pool across every account in
/// [envelopeModeAccountsProvider] regardless of which one a row names.
final defaultEnvelopeAccountIdProvider = Provider<int?>((ref) {
  final accounts = ref.watch(envelopeModeAccountsProvider);
  return accounts.isEmpty ? null : accounts.first.id;
});

/// `SUM(allocations) − SUM(expenses)` for one category, pooled across every
/// account in [envelopeModeAccountsProvider] — GitHub #48: one shared
/// balance per category, not one per account. An account that isn't (or is
/// no longer) in Envelope Mode never contributes here, even if it shares a
/// category with an Envelope-Mode account; otherwise an ordinary account's
/// everyday spending would silently drain the shared pool. Never touches
/// [Accounts.currentBalance] or `net worth` — Envelope Mode only re-labels
/// money already correctly tracked by the ledger, it never moves any.
final categoryBalanceProvider = Provider.family<Money, int>((
  ref,
  categoryId,
) {
  final poolAccountIds = {
    for (final a in ref.watch(envelopeModeAccountsProvider)) a.id,
  };
  final allocated = ref.watch(_envelopeAllocatedProvider);
  final spent = ref.watch(_envelopeSpentProvider);

  var balance = const Money.zero();
  for (final accountId in poolAccountIds) {
    final pairKey = (accountId, categoryId);
    balance +=
        (allocated[pairKey] ?? const Money.zero()) -
        (spent[pairKey] ?? const Money.zero());
  }
  return balance;
});

/// The three-state (RTA on) / two-state (RTA off) funding indicator for a
/// category with a [Budgets] ceiling — GitHub #100 v2. `overspent` always
/// wins regardless of funding; `funded`/`underfunded` only distinguish
/// whether the pooled envelope balance ([categoryBalanceProvider]) fully
/// backs the ceiling yet. Callers should only use this while
/// [rtaEnabledProvider] is on — with RTA off, fall back to
/// [BudgetProgress.nearingLimit] instead, which this deliberately doesn't
/// touch or replace.
enum CategoryFundingState { overspent, funded, underfunded }

/// Returns null when [categoryId] has no [Budgets] row — there's nothing to
/// color either way, in RTA on or off.
final categoryFundingStateProvider = Provider.family<CategoryFundingState?, int>((
  ref,
  categoryId,
) {
  final p = ref
      .watch(budgetProgressProvider)
      .where((p) => p.budget.categoryId == categoryId)
      .firstOrNull;
  if (p == null) return null;
  if (p.overspent) return CategoryFundingState.overspent;
  final balance = ref.watch(categoryBalanceProvider(categoryId));
  return balance >= p.budget.amount
      ? CategoryFundingState.funded
      : CategoryFundingState.underfunded;
});

/// `Σ(currentBalance) − Σ(category_balance > 0)`, across every account in
/// [envelopeModeAccountsProvider] — GitHub #48: one shared Ready to Assign
/// figure, not one per account. A category that has gone negative
/// (overspent — allowed, shown in red, never blocked) does *not* reduce
/// this further: those rupees already left an account and are already
/// reflected in its `currentBalance`, so only a category still holding a
/// **positive**, unspent balance counts as "claimed". This keeps
/// `ready_to_assign` bounded by the pool's real combined balance in every
/// case.
final readyToAssignProvider = Provider<Money>((ref) {
  final poolAccounts = ref.watch(envelopeModeAccountsProvider);
  if (poolAccounts.isEmpty) return const Money.zero();
  final poolAccountIds = {for (final a in poolAccounts) a.id};

  final allocated = ref.watch(_envelopeAllocatedProvider);
  final spent = ref.watch(_envelopeSpentProvider);
  final categoryIds = <int>{
    for (final k in allocated.keys)
      if (poolAccountIds.contains(k.$1)) k.$2,
    for (final k in spent.keys)
      if (poolAccountIds.contains(k.$1)) k.$2,
  };

  var claimed = const Money.zero();
  for (final categoryId in categoryIds) {
    final balance = ref.watch(categoryBalanceProvider(categoryId));
    if (balance.isPositive) claimed += balance;
  }

  var totalBalance = const Money.zero();
  for (final a in poolAccounts) {
    totalBalance += a.currentBalance;
  }
  return totalBalance - claimed;
});

// ── Persons ─────────────────────────────────────────────────────────────────

final personsProvider = StreamProvider<List<PersonRow>>(
  (ref) => ref.watch(dbProvider).watchPersons(),
);

final archivedPersonsProvider = StreamProvider<List<PersonRow>>(
  (ref) => ref.watch(dbProvider).watchArchivedPersons(),
);

final personBalancesProvider = StreamProvider<Map<int, Money>>(
  (ref) => ref.watch(dbProvider).watchAllPersonBalances(),
);

/// For naming the person on a `personOut` / `personIn` ledger row.
final personMapProvider = Provider<Map<int, PersonRow>>((ref) {
  final people = ref.watch(personsProvider).valueOrNull ?? const [];
  return {for (final p in people) p.id: p};
});

final personEntriesProvider = StreamProvider.family<List<PersonEntryRow>, int>(
  (ref, personId) => ref.watch(dbProvider).watchPersonEntries(personId),
);

/// Headline totals: what you'll collect, what you'll pay.
final personTotalsProvider = Provider<({Money youGet, Money youPay})>((ref) {
  final balances = ref.watch(personBalancesProvider).valueOrNull ?? {};
  var youGet = const Money.zero();
  var youPay = const Money.zero();
  for (final b in balances.values) {
    if (b.isPositive) {
      youGet += b;
    } else if (b.isNegative) {
      youPay += b.abs;
    }
  }
  return (youGet: youGet, youPay: youPay);
});

// ── Groups ───────────────────────────────────────────────────────────────

final groupsProvider = StreamProvider<List<GroupRow>>(
  (ref) => ref.watch(dbProvider).watchGroups(),
);

final archivedGroupsProvider = StreamProvider<List<GroupRow>>(
  (ref) => ref.watch(dbProvider).watchArchivedGroups(),
);

final groupMembersProvider = StreamProvider.family<List<PersonRow>, int>(
  (ref, groupId) => ref.watch(dbProvider).watchGroupMembers(groupId),
);

final groupExpensesProvider = StreamProvider.family<List<GroupExpenseRow>, int>(
  (ref, groupId) => ref.watch(dbProvider).watchGroupExpenses(groupId),
);

/// A group's aggregate balance — the sum of the already-correct, live
/// [personBalancesProvider] over exactly that group's member ids. Not new
/// balance math; a group is never a second source of truth for money.
final groupBalanceProvider = Provider.family<Money, int>((ref, groupId) {
  final members = ref.watch(groupMembersProvider(groupId)).valueOrNull ?? const [];
  final balances =
      ref.watch(personBalancesProvider).valueOrNull ?? const <int, Money>{};
  return members.fold(
    const Money.zero(),
    (sum, m) => sum + (balances[m.id] ?? const Money.zero()),
  );
});

// ── Reminders ───────────────────────────────────────────────────────────────

final remindersProvider = StreamProvider<List<ReminderRow>>(
  (ref) => ref.watch(dbProvider).watchReminders(),
);

final openRemindersProvider = Provider<List<ReminderRow>>((ref) {
  final all = ref.watch(remindersProvider).valueOrNull ?? [];
  return all.where((r) => r.status == ReminderStatus.open).toList();
});

/// One row in the dashboard's "Upcoming" strip — a cash reminder or an Auto
/// rule's next occurrence, whichever comes first.
typedef UpcomingItem = ({
  DateTime date,
  String title,
  Money? amount,
  bool isOutgoing,
  bool isReminder,
  int id,
});

/// Every open reminder and active Auto rule due within [days], nearest first.
/// Composed from providers already watched elsewhere — see the "compose,
/// don't resubscribe" note on [monthlyTotalsProvider].
final upcomingPaymentsProvider = Provider.family<List<UpcomingItem>, int>((
  ref,
  days,
) {
  final reminders = ref.watch(openRemindersProvider);
  final rules = ref.watch(recurringRulesProvider).valueOrNull ?? const [];
  final windowEnd = DateTime.now()
      .add(Duration(days: days))
      .add(const Duration(days: 1));

  final items = <UpcomingItem>[
    for (final r in reminders)
      if (r.dueDate.isBefore(windowEnd))
        (
          date: r.dueDate,
          title: r.title,
          amount: r.amount,
          isOutgoing: r.direction == ReminderDirection.pay,
          isReminder: true,
          id: r.id,
        ),
    for (final r in rules)
      if (r.isActive && r.nextDueDate.isBefore(windowEnd))
        (
          date: r.nextDueDate,
          title: r.name,
          // A promo in its window quotes at the promo price — same check as
          // `_RuleTile._onPromo` in the Auto tab, so the two never disagree
          // about what the next occurrence actually costs (GitHub #94).
          amount: r.promoAmount != null && (r.promoOccurrencesLeft ?? 0) > 0
              ? r.promoAmount
              : r.amount,
          isOutgoing: r.kind == CategoryKind.expense,
          isReminder: false,
          id: r.id,
        ),
  ]..sort((a, b) => a.date.compareTo(b.date));
  return items;
});

// ── Recurring rules (Auto) ──────────────────────────────────────────────────

final recurringRulesProvider = StreamProvider<List<RecurringRuleRow>>(
  (ref) => ref.watch(dbProvider).watchRecurringRules(),
);

/// Paused rules, across both kinds — [AutoScreen] hides these from its main
/// list entirely and [ArchivedAutoRulesScreen] is the only place they still
/// show, with a way back in (see GitHub #61).
final archivedRecurringRulesProvider = Provider<List<RecurringRuleRow>>((ref) {
  final rules = ref.watch(recurringRulesProvider).valueOrNull ?? const [];
  return rules.where((r) => !r.isActive).toList();
});

/// For naming the rule behind a transaction's [TransactionRow.recurringRuleId].
final recurringRuleMapProvider = Provider<Map<int, RecurringRuleRow>>((ref) {
  final rules = ref.watch(recurringRulesProvider).valueOrNull ?? const [];
  return {for (final r in rules) r.id: r};
});

// ── Settings ────────────────────────────────────────────────────────────────

final settingsProvider = StreamProvider<SettingRow>(
  (ref) => ref.watch(dbProvider).watchSettings(),
);

/// The theme the user picked. Falls back to [ThemePreset.fallback] while the
/// settings row is loading, and if the database never opens — the app must
/// still be able to paint its own error screen.
final themePresetProvider = Provider<ThemePreset>((ref) {
  final name = ref.watch(settingsProvider).valueOrNull?.themeName;
  return ThemePreset.fromName(name);
});

/// Text-size multiplier, as a percentage — 100 is normal. See
/// `Settings.fontScalePercent`.
final fontScalePercentProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.fontScalePercent ?? 100;
});

/// How much bolder/lighter than the theme's own weight text reads. See
/// `Settings.fontWeightDelta`.
final fontWeightDeltaProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.fontWeightDelta ?? 0;
});

/// The font family the user picked, or [AppFontFamily.system] to keep each
/// theme's own choice.
final fontFamilyProvider = Provider<AppFontFamily>((ref) {
  final name = ref.watch(settingsProvider).valueOrNull?.fontFamily;
  return AppFontFamily.fromName(name);
});

/// The currency the user picked. An unknown code degrades to the default, so a
/// bad setting never blanks out every amount in the app.
final currencyProvider = Provider<Currency>((ref) {
  final code = ref.watch(settingsProvider).valueOrNull?.currencyCode;
  return currencyForCode(code);
});

/// Whether to draw the currency symbol. Defaults to shown while settings load.
final showCurrencySymbolProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.showCurrencySymbol ?? true;
});

/// One row per currency that has a rate entered, each the most recent — the
/// Currency settings screen's list.
final currencyRatesProvider = StreamProvider<List<CurrencyRateRow>>(
  (ref) => ref.watch(dbProvider).watchCurrentRates(),
);

/// Whether "Mark as repaid" (Persons) is offered at all. Off by default —
/// lending/borrowing stays out of income/expense unless asked for.
final countRepaymentsAsIncomeProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.countRepaymentsAsIncome ??
      false;
});

/// The app user's own UPI VPA — set once in Settings, required to build a
/// `upi://collect` link (the "Request" button on a person who owes the
/// user). Null until set.
final myUpiIdProvider = Provider<String?>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.myUpiId;
});

/// The app user's own display name, sent as `pn` on a collect link.
final myUpiNameProvider = Provider<String?>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.myUpiName;
});

/// The app user's own PayPal.me id — set once in Settings, required to
/// build the "Request" link on a person who owes the user. Null until set.
final myPaypalProvider = Provider<String?>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.myPaypal;
});

/// The app user's own Venmo username, for the "Request" link.
final myVenmoProvider = Provider<String?>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.myVenmo;
});

/// The app user's own Cash App cashtag, for the "Request" link.
final myCashappProvider = Provider<String?>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.myCashapp;
});

/// The app user's own Revolut.me username, for the "Request" link.
final myRevolutProvider = Provider<String?>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.myRevolut;
});

/// Whether the UPI button/fields are offered at all — see "Payment
/// support" in Settings. Defaults true while settings load.
final upiEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.upiEnabled ?? true;
});

/// Same as [upiEnabledProvider], for PayPal.
final paypalEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.paypalEnabled ?? true;
});

/// Same as [upiEnabledProvider], for Venmo.
final venmoEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.venmoEnabled ?? true;
});

/// Same as [upiEnabledProvider], for Cash App.
final cashappEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.cashappEnabled ?? true;
});

/// Same as [upiEnabledProvider], for Revolut.
final revolutEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.revolutEnabled ?? true;
});

/// Whether a passcode is set at all — the switch the app-lock gate checks on
/// every launch and resume.
final hasPasscodeProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.passcodeHash != null;
});

final biometricEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.biometricEnabled ?? false;
});

/// The current passcode's digit count — 4, 5 or 6. Null in [Settings] means
/// 4 (every passcode set before length was configurable, see GitHub #18).
final passcodeLengthProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.passcodeLength ?? 4;
});

final preventScreenshotsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.preventScreenshots ?? false;
});

/// Whether a small on-screen reminder shows whenever [preventScreenshotsProvider]
/// is off. Off by default — opt-in, since leaving screenshot-blocking off can
/// be a deliberate choice, not an oversight (GitHub #90).
final screenshotReminderEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.screenshotReminderEnabled ??
      false;
});

/// Whether a master recovery phrase is set — the switch the lock screen
/// checks alongside [failedPasscodeAttemptsProvider] (GitHub #74).
final hasMasterPhraseProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.masterPhraseHash != null;
});

final masterPhraseAttemptThresholdProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.masterPhraseAttemptThreshold ??
      5;
});

/// Consecutive wrong-PIN count, persisted with no time decay. The lock
/// screen forces master-phrase entry once this reaches the threshold.
final failedPasscodeAttemptsProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.failedPasscodeAttempts ?? 0;
});

/// Whether the calendar's selected-day section shows an inflow/outflow total
/// strip. On by default — see GitHub #75.
final showCalendarDayTotalsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.showCalendarDayTotals ?? true;
});

/// Whether the bottom nav bar shows each item's small text label under its
/// icon. On by default; off collapses the bar to icon-only.
final showBottomNavLabelsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.showBottomNavLabels ?? true;
});

/// Off by default — see `Settings.holdMenuEnabled`.
final holdMenuEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.holdMenuEnabled ?? false;
});

/// The 3 destinations the hold-➕ menu offers. Falls back to the same
/// default `Settings.holdMenuSlots` itself defaults to if the stored value
/// somehow doesn't parse to exactly 3 ids — mirrors `AppShell._slotIds`'s
/// defensive fallback for `bottomNavSlots`.
final holdMenuSlotsProvider = Provider<List<String>>((ref) {
  final raw =
      ref.watch(settingsProvider).valueOrNull?.holdMenuSlots ??
      'calendar,budgets,stats';
  final parts = raw.split(',');
  return parts.length == 3 ? parts : const ['calendar', 'budgets', 'stats'];
});

/// Extra logical pixels of bottom clearance layered over the OS's own
/// reported nav-bar inset — 0 unless the user turned it up in Settings ▸
/// Customize bottom nav to fix an overlap the OS didn't account for
/// (GitHub #78). See `Settings.extraBottomInset`.
final extraBottomInsetProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.extraBottomInset ?? 0;
});

/// Icon keys most recently picked from the icon sheet, newest first — see
/// `Settings.frequentIconKeys` and `AppDatabase.recordIconUsed`.
final frequentIconKeysProvider = Provider<List<String>>((ref) {
  final raw = ref.watch(settingsProvider).valueOrNull?.frequentIconKeys ?? '';
  return raw.isEmpty ? const [] : raw.split(',');
});

/// Minutes the app may sit backgrounded before the next resume re-locks it —
/// `0` means immediately. See GitHub #60.
final pinTimeoutMinutesProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.pinTimeoutMinutes ?? 0;
});

/// Which numpad style the lock screen (and set/change-passcode screen) draws.
/// See GitHub #81.
final lockScreenStyleProvider = Provider<LockScreenStyle>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.lockScreenStyle ??
      LockScreenStyle.classic;
});

/// How the More hub lays out its items — see [MoreScreenViewMode].
final moreScreenViewModeProvider = Provider<MoreScreenViewMode>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.moreScreenViewMode ??
      MoreScreenViewMode.list;
});

/// Whether every amount app-wide is masked — the top bar's eye icon. See
/// `AmountVisibilityScope` in `money_text.dart`.
final hideAmountsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.hideAmounts ?? false;
});

/// Whether Ready to Assign — the shared envelope pool — is turned on
/// globally (GitHub #100 v2). Budget (the per-category ceiling system) is
/// always on regardless of this flag; see [BudgetingMode]'s doc comment for
/// the superseded enum this replaces.
final rtaEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.rtaEnabled ?? false;
});

/// A standing notification with "Add expense" / "Add income" shortcuts —
/// off by default. See GitHub #38.
final notificationQuickAddEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.notificationQuickAddEnabled ??
      false;
});

/// The account a quick-add reply posts to — null means "use the first
/// account" (see `AppDatabase.resolveQuickAddAccountId`).
final quickAddAccountIdProvider = Provider<int?>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.quickAddAccountId;
});

/// A daily nudge to log spending — hour/minute in the user's local wall
/// clock, defaulting to 8 PM.
typedef ExpenseReminderSettings = ({bool enabled, int hour, int minute});

final expenseReminderProvider = Provider<ExpenseReminderSettings>((ref) {
  final row = ref.watch(settingsProvider).valueOrNull;
  return (
    enabled: row?.expenseReminderEnabled ?? false,
    hour: row?.expenseReminderHour ?? 20,
    minute: row?.expenseReminderMinute ?? 0,
  );
});

// ── Message auto-capture ────────────────────────────────────────────────────

/// Capture is paused: the SMS source was removed in 1.1.0 because Google Play
/// Protect blocks direct-download APKs that request SMS permissions. The
/// pipeline behind this provider (parser, dedupe, Review Inbox) is intact —
/// swap in a Play-compliant source here when capture returns.
final messageSourceProvider = Provider<MessageSource>(
  (ref) => const NullMessageSource(),
);

final captureServiceProvider = Provider<CaptureService>(
  (ref) => CaptureService(
    db: ref.watch(dbProvider),
    source: ref.watch(messageSourceProvider),
  ),
);

final shareIntakeServiceProvider = Provider<ShareIntakeService>(
  (ref) => ShareIntakeService(db: ref.watch(dbProvider)),
);

/// Cards awaiting review, plus auto-filled ones shown for information.
final pendingCardsProvider = StreamProvider<List<PendingTxnRow>>(
  (ref) => ref.watch(dbProvider).watchPendingCards(),
);

final pendingCountProvider = Provider<int>(
  (ref) => ref.watch(pendingCardsProvider).valueOrNull?.length ?? 0,
);

final allPendingProvider = StreamProvider<List<PendingTxnRow>>(
  (ref) => ref.watch(dbProvider).watchAllPendingTxns(),
);

final pendingOcrCorrectionsProvider = StreamProvider<List<OcrCorrectionRow>>(
  (ref) => ref.watch(dbProvider).watchPendingOcrCorrections(),
);

final sentOcrCorrectionsProvider = StreamProvider<List<OcrCorrectionRow>>(
  (ref) => ref.watch(dbProvider).watchSentOcrCorrections(),
);

final merchantRulesProvider = StreamProvider<List<MerchantRuleRow>>(
  (ref) => ref.watch(dbProvider).watchMerchantRules(),
);

final senderRulesProvider = StreamProvider<List<SenderRuleRow>>(
  (ref) => ref.watch(dbProvider).watchSenderRules(),
);

// ── Notifications ───────────────────────────────────────────────────────────

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref.watch(dbProvider)),
);

final homeWidgetServiceProvider = Provider<HomeWidgetService>(
  (ref) => const HomeWidgetService(),
);

// ── Categories management ───────────────────────────────────────────────────

final allCategoriesProvider = StreamProvider<List<CategoryRow>>(
  (ref) => ref.watch(dbProvider).watchAllCategories(),
);

// ── Per-account history ─────────────────────────────────────────────────────

/// Every transaction touching an account, including transfers in and out and
/// anything paid via a debit card linked to it.
final accountTransactionsProvider =
    StreamProvider.family<List<TransactionRow>, int>(
      (ref, accountId) =>
          ref.watch(dbProvider).watchTransactionsForAccount(accountId),
    );

final accountByIdProvider = StreamProvider.family<AccountRow?, int>(
  (ref, id) => ref.watch(dbProvider).watchAccount(id),
);

final transactionByIdProvider = StreamProvider.family<TransactionRow?, int>(
  (ref, id) => ref.watch(dbProvider).watchTransaction(id),
);

/// Every leg of the hybrid/split payment a transaction belongs to (itself
/// included), or empty for an ordinary one — see GitHub #43 and
/// `AppDatabase.paymentGroupLegs`. Re-reads whenever the ledger changes, so
/// a leg edited or deleted elsewhere is reflected without a manual refresh.
final paymentGroupLegsProvider =
    FutureProvider.family<List<TransactionRow>, int>((ref, id) {
      ref.watch(allTransactionsProvider);
      return ref.watch(dbProvider).paymentGroupLegs(id);
    });

/// Raw rows of every manual transaction-to-transaction link, across the
/// whole ledger — see GitHub #64 and `AppDatabase.watchTransactionLinks`.
final _transactionLinkRowsProvider = StreamProvider<List<TransactionLinkRow>>(
  (ref) => ref.watch(dbProvider).watchTransactionLinks(),
);

/// The other transaction(s) manually linked to [id], either direction.
/// Re-reads whenever a link is added/removed or the ledger changes, so a
/// linked transaction edited or deleted elsewhere is reflected without a
/// manual refresh.
final linkedTransactionsProvider =
    FutureProvider.family<List<TransactionRow>, int>((ref, id) {
      ref.watch(allTransactionsProvider);
      ref.watch(_transactionLinkRowsProvider);
      return ref.watch(dbProvider).linkedTransactions(id);
    });

/// Every linked transaction id mapped to a canonical cluster id — a union-find
/// over [TransactionLinks] so `A-B` and `B-C` collapse into one cluster of 3
/// even though they're two separate rows (see the Transactions tab's "Linked"
/// chip, GitHub #68). A transaction absent from this map isn't linked to
/// anything.
final txLinkClusterProvider = Provider<Map<int, int>>((ref) {
  final links = ref.watch(_transactionLinkRowsProvider).valueOrNull ?? const [];
  final parent = <int, int>{};

  int find(int x) {
    parent.putIfAbsent(x, () => x);
    while (parent[x] != x) {
      parent[x] = parent[parent[x]!]!;
      x = parent[x]!;
    }
    return x;
  }

  for (final link in links) {
    final rootA = find(link.transactionAId);
    final rootB = find(link.transactionBId);
    if (rootA != rootB) parent[rootA] = rootB;
  }

  return {for (final id in parent.keys) id: find(id)};
});

// ── Shopping lists ──────────────────────────────────────────────────────────

final shoppingListsProvider = StreamProvider<List<ShoppingListRow>>(
  (ref) => ref.watch(dbProvider).watchShoppingLists(),
);

final shoppingItemsProvider = StreamProvider.family<List<ShoppingItemRow>, int>(
  (ref, listId) => ref.watch(dbProvider).watchShoppingItems(listId),
);

final allShoppingItemsProvider = StreamProvider<List<ShoppingItemRow>>(
  (ref) => ref.watch(dbProvider).watchAllShoppingItems(),
);

/// Item counts per list, for the lists overview — how many total and how
/// many already checked off.
typedef ShoppingListSummary = ({int total, int checked});

final shoppingListSummaryProvider = Provider<Map<int, ShoppingListSummary>>((
  ref,
) {
  final items = ref.watch(allShoppingItemsProvider).valueOrNull ?? const [];
  final out = <int, ({int total, int checked})>{};
  for (final item in items) {
    final listId = item.listId;
    if (listId == null) continue;
    final current = out[listId] ?? (total: 0, checked: 0);
    out[listId] = (
      total: current.total + 1,
      checked: current.checked + (item.isChecked ? 1 : 0),
    );
  }
  return out;
});

// ── Savings goals ───────────────────────────────────────────────────────────
//
// A goal is a real AccountType.goal account (see GoalDetails in tables.dart)
// — `saved` is simply that account's own balance, never a separate figure to
// keep in sync.

final goalDetailsProvider = StreamProvider<List<GoalDetailRow>>(
  (ref) => ref.watch(dbProvider).watchGoalDetails(),
);

final goalDetailProvider = StreamProvider.family<GoalDetailRow?, int>(
  (ref, accountId) => ref.watch(dbProvider).watchGoalDetail(accountId),
);

typedef GoalProgress = ({
  AccountRow account,
  GoalDetailRow detail,
  Money saved,
  double fraction,
  bool reached,
});

/// Archived goals drop out on their own: [accountMapProvider] only ever
/// holds non-archived accounts, so a goal whose account has been archived
/// simply has no match here.
final goalProgressListProvider = Provider<List<GoalProgress>>((ref) {
  final details = ref.watch(goalDetailsProvider).valueOrNull ?? const [];
  final accountMap = ref.watch(accountMapProvider);
  final out = <GoalProgress>[
    for (final d in details)
      if (accountMap[d.accountId] case final account?)
        _goalProgressOf(account, d),
  ];
  // Most-funded goal first (GitHub #77); ties keep creation order so the
  // list doesn't reshuffle unnecessarily among equally-funded goals.
  out.sort((a, b) {
    final byFraction = b.fraction.compareTo(a.fraction);
    if (byFraction != 0) return byFraction;
    return a.account.createdAt.compareTo(b.account.createdAt);
  });
  return out;
});

final goalProgressProvider = Provider.family<GoalProgress?, int>((
  ref,
  accountId,
) {
  final detail = ref.watch(goalDetailProvider(accountId)).valueOrNull;
  final account = ref.watch(accountMapProvider)[accountId];
  if (detail == null || account == null) return null;
  return _goalProgressOf(account, detail);
});

GoalProgress _goalProgressOf(AccountRow account, GoalDetailRow detail) {
  final saved = account.currentBalance;
  final fraction = detail.targetAmount.isZero
      ? 0.0
      : saved.paise / detail.targetAmount.paise;
  return (
    account: account,
    detail: detail,
    saved: saved,
    fraction: fraction.clamp(0.0, 1.0),
    reached: saved.paise >= detail.targetAmount.paise,
  );
}

// ── Loans ────────────────────────────────────────────────────────────────────

final loanDetailsProvider = StreamProvider<List<LoanDetailRow>>(
  (ref) => ref.watch(dbProvider).watchLoanDetails(),
);

final loanDetailProvider = Provider.family<LoanDetailRow?, int>((
  ref,
  accountId,
) {
  final details = ref.watch(loanDetailsProvider).valueOrNull ?? const [];
  for (final d in details) {
    if (d.accountId == accountId) return d;
  }
  return null;
});

typedef LoanProgress = ({
  AccountRow account,
  LoanDetailRow detail,
  Money outstanding,
  Money principal,
  double fraction,
});

final loanProgressListProvider = Provider<List<LoanProgress>>((ref) {
  final details = ref.watch(loanDetailsProvider).valueOrNull ?? const [];
  final accountMap = ref.watch(accountMapProvider);
  final out = <LoanProgress>[
    for (final d in details)
      if (accountMap[d.accountId] case final account?)
        _loanProgressOf(account, d),
  ];
  out.sort((a, b) => a.account.createdAt.compareTo(b.account.createdAt));
  return out;
});

final loanProgressProvider = Provider.family<LoanProgress?, int>((
  ref,
  accountId,
) {
  final detail = ref.watch(loanDetailProvider(accountId));
  final account = ref.watch(accountMapProvider)[accountId];
  if (detail == null || account == null) return null;
  return _loanProgressOf(account, detail);
});

// ── Credit card statements (GitHub #91) ─────────────────────────────────────

/// `null` means the card isn't tracking a statement cycle.
final creditCardDetailsProvider =
    StreamProvider.family<CreditCardDetailRow?, int>(
      (ref, accountId) =>
          ref.watch(dbProvider).watchCreditCardDetails(accountId),
    );

/// The next payment-due date for a tracked card, recomputed live off
/// whatever "today" is — `null` means the card isn't tracking a cycle.
final creditCardNextDueDateProvider = Provider.family<DateTime?, int>((
  ref,
  accountId,
) {
  final detail = ref.watch(creditCardDetailsProvider(accountId)).valueOrNull;
  if (detail == null) return null;
  return AppDatabase.creditCardNextDueDate(
    today: DateTime.now(),
    statementDay: detail.statementDay,
    dueDay: detail.dueDay,
  );
});

/// The statement period currently accumulating charges — `null` means the
/// card isn't tracking a cycle.
final creditCardStatementPeriodProvider =
    Provider.family<({DateTime start, DateTime end})?, int>((ref, accountId) {
      final detail = ref
          .watch(creditCardDetailsProvider(accountId))
          .valueOrNull;
      if (detail == null) return null;
      return AppDatabase.creditCardStatementPeriod(
        today: DateTime.now(),
        statementDay: detail.statementDay,
      );
    });

LoanProgress _loanProgressOf(AccountRow account, LoanDetailRow detail) {
  final principal = Money.fromPaise(-account.openingBalance.paise);
  final currentBalance = account.currentBalance;
  final outstanding = currentBalance.isNegative
      ? Money.fromPaise(-currentBalance.paise)
      : const Money.zero();
  final paid = principal - outstanding;
  return (
    account: account,
    detail: detail,
    outstanding: outstanding,
    principal: principal,
    fraction: principal.isZero
        ? 1.0
        : (paid.paise / principal.paise).clamp(0.0, 1.0),
  );
}

// ── Tags ────────────────────────────────────────────────────────────────────

final tagsProvider = StreamProvider<List<TagRow>>(
  (ref) => ref.watch(dbProvider).watchTags(),
);

final tagMapProvider = Provider<Map<int, TagRow>>((ref) {
  final tags = ref.watch(tagsProvider).valueOrNull ?? const [];
  return {for (final t in tags) t.id: t};
});

final _transactionTagLinksProvider = StreamProvider<List<TransactionTagRow>>(
  (ref) => ref.watch(dbProvider).watchAllTransactionTags(),
);

/// Every transaction's tags, keyed by transaction id — composed from the raw
/// links plus the tag map so list/detail rows never issue a query per row.
final transactionTagsByTxProvider = Provider<Map<int, List<TagRow>>>((ref) {
  final links = ref.watch(_transactionTagLinksProvider).valueOrNull ?? const [];
  final tagMap = ref.watch(tagMapProvider);
  final out = <int, List<TagRow>>{};
  for (final link in links) {
    final tag = tagMap[link.tagId];
    if (tag == null) continue;
    (out[link.transactionId] ??= []).add(tag);
  }
  return out;
});

// ── Tag groups ──────────────────────────────────────────────────────────────

final tagGroupsProvider = StreamProvider<List<TagGroupRow>>(
  (ref) => ref.watch(dbProvider).watchTagGroups(),
);

final _tagGroupTagLinksProvider = StreamProvider<List<TagGroupTagRow>>(
  (ref) => ref.watch(dbProvider).watchAllTagGroupTags(),
);

/// Every group's member tags, keyed by group id — same compose-don't-
/// resubscribe shape as [transactionTagsByTxProvider].
final tagGroupTagsByGroupProvider = Provider<Map<int, List<TagRow>>>((ref) {
  final links = ref.watch(_tagGroupTagLinksProvider).valueOrNull ?? const [];
  final tagMap = ref.watch(tagMapProvider);
  final out = <int, List<TagRow>>{};
  for (final link in links) {
    final tag = tagMap[link.tagId];
    if (tag == null) continue;
    (out[link.groupId] ??= []).add(tag);
  }
  return out;
});

// ── Split expenses ──────────────────────────────────────────────────────────

final _transactionSplitLinksProvider =
    StreamProvider<List<TransactionSplitRow>>(
      (ref) => ref.watch(dbProvider).watchAllTransactionSplits(),
    );

/// Every transaction's split lines, keyed by transaction id — same
/// compose-don't-resubscribe shape as [transactionTagsByTxProvider].
final transactionSplitsByTxProvider =
    Provider<Map<int, List<TransactionSplitRow>>>((ref) {
      final links =
          ref.watch(_transactionSplitLinksProvider).valueOrNull ?? const [];
      final out = <int, List<TransactionSplitRow>>{};
      for (final s in links) {
        (out[s.transactionId] ??= []).add(s);
      }
      return out;
    });

// ── Payees ──────────────────────────────────────────────────────────────────
//
// A payee is free text on an expense or income (GitHub #62 — a salary needs
// one too), not its own table (see Transactions.payee in tables.dart) — these
// all derive their view by grouping that column out of transactions already
// being watched elsewhere. Compose, don't re-subscribe.

/// Distinct payee names used on past expenses/income, most recently used
/// first — the source for autocomplete suggestions on the add/edit screen.
final payeeSuggestionsProvider = Provider<List<String>>((ref) {
  final txs = ref.watch(allTransactionsProvider).valueOrNull ?? const [];
  final lastUsed = <String, DateTime>{};
  for (final t in txs) {
    final p = t.payee;
    if (!t.type.isIncomeOrExpense || p == null || p.isEmpty) continue;
    final seen = lastUsed[p];
    if (seen == null || t.date.isAfter(seen)) lastUsed[p] = t.date;
  }
  return lastUsed.keys.toList()
    ..sort((a, b) => lastUsed[b]!.compareTo(lastUsed[a]!));
});

/// One payee's net flow: income minus expense, how many transactions, and
/// when one last happened. [net] is signed — positive when a payee has paid
/// more than they've been paid (e.g. an employer, income-only), negative the
/// other way (e.g. a shop, expense-only).
typedef PayeeSummary = ({
  String payee,
  Money net,
  int count,
  DateTime lastUsed,
});

/// Every payee named on an expense or income, ranked by absolute net flow —
/// the Payees hub.
final payeeSummariesProvider = Provider<List<PayeeSummary>>((ref) {
  final txs = ref.watch(allTransactionsProvider).valueOrNull ?? const [];
  final nets = <String, Money>{};
  final counts = <String, int>{};
  final lastUsed = <String, DateTime>{};
  for (final t in txs) {
    final p = t.payee;
    if (!t.type.isIncomeOrExpense || p == null || p.isEmpty) continue;
    final signed = t.type == TxType.expense ? -t.amount : t.amount;
    nets[p] = (nets[p] ?? const Money.zero()) + signed;
    counts[p] = (counts[p] ?? 0) + 1;
    final seen = lastUsed[p];
    if (seen == null || t.date.isAfter(seen)) lastUsed[p] = t.date;
  }
  final out = [
    for (final name in nets.keys)
      (
        payee: name,
        net: nets[name]!,
        count: counts[name]!,
        lastUsed: lastUsed[name]!,
      ),
  ]..sort((a, b) => b.net.abs.paise.compareTo(a.net.abs.paise));
  return out;
});

/// One payee's expense/income history, newest first.
final payeeTransactionsProvider = Provider.family<List<TransactionRow>, String>(
  (ref, payee) {
    final txs = ref.watch(allTransactionsProvider).valueOrNull ?? const [];
    return txs
        .where((t) => t.type.isIncomeOrExpense && t.payee == payee)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  },
);

// ── Export / Backup ─────────────────────────────────────────────────────────

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(dbProvider)),
);

/// The live list of known backups. Reads `AppDatabase.watchBackupRecords`
/// directly (a real stream) rather than `BackupService.listBackups` (a
/// one-shot snapshot), so the screen updates itself after every backup or
/// delete with no explicit `ref.invalidate` needed.
final backupRecordsProvider = StreamProvider<List<BackupRecordRow>>(
  (ref) => ref.watch(dbProvider).watchBackupRecords(),
);

/// Auto-backup schedule + retention, straight off [Settings] — a safe
/// default (off) while settings are still loading.
typedef AutoBackupSettings = ({
  bool enabled,
  AutoBackupFrequency frequency,
  int customDays,
  int customHours,
  int retentionDays,
  DateTime? lastAutoBackupAt,
});

final autoBackupSettingsProvider = Provider<AutoBackupSettings>((ref) {
  final s = ref.watch(settingsProvider).valueOrNull;
  return (
    enabled: s?.autoBackupEnabled ?? false,
    frequency: s?.autoBackupFrequency ?? AutoBackupFrequency.daily,
    customDays: s?.autoBackupCustomDays ?? 0,
    customHours: s?.autoBackupCustomHours ?? 0,
    retentionDays: s?.backupRetentionDays ?? 180,
    lastAutoBackupAt: s?.lastAutoBackupAt,
  );
});

// ── Reports ─────────────────────────────────────────────────────────────────

final allPersonEntriesProvider = StreamProvider<List<PersonEntryRow>>(
  (ref) => ref.watch(dbProvider).watchAllPersonEntries(),
);

/// These are plain [Provider]s that COMPOSE existing stream providers.
///
/// They must never open a drift query they already watch. Drift caches query
/// streams by query: subscribing to an identical query re-fetches and re-emits
/// to every listener, so `ref.watch(allTransactionsProvider)` plus an inner
/// `db.watchTransactions()` recomputes forever — the Stats screen would hang
/// and never render. Compose, don't re-subscribe.

/// Net worth at the end of each of the last N months, oldest first.
/// Rebuilt from the ledger, so it obeys every rule the ledger obeys.
final netWorthTrendProvider =
    Provider.family<List<({DateTime month, Money value})>, int>((ref, months) {
      final accounts =
          ref.watch(balanceAccountsProvider).valueOrNull ?? const [];
      final txs = ref.watch(allTransactionsProvider).valueOrNull ?? const [];
      final entries =
          ref.watch(allPersonEntriesProvider).valueOrNull ?? const [];

      final opening = accounts.fold(
        const Money.zero(),
        (sum, a) => sum + a.openingBalance,
      );

      final now = DateTime.now();
      final out = <({DateTime month, Money value})>[];

      for (var i = months - 1; i >= 0; i--) {
        // Last millisecond of the month `i` months back. DateTime normalises the
        // month overflow/underflow, so December and January need no special case.
        final end = DateTime(
          now.year,
          now.month - i + 1,
        ).subtract(const Duration(milliseconds: 1));
        var total = opening;

        for (final t in txs) {
          if (t.date.isAfter(end)) continue;
          // A transfer moves money between our own accounts: net zero.
          if (t.type == TxType.income) total += t.amount;
          if (t.type == TxType.expense) total -= t.amount;
        }
        for (final e in entries) {
          if (e.accountId == null || e.date.isAfter(end)) continue;
          // theyOwe = money left us; iOwe = money came to us.
          total += e.direction == PersonDirection.theyOwe
              ? -e.amount
              : e.amount;
        }
        out.add((month: DateTime(end.year, end.month), value: total));
      }
      return out;
    });

/// Combined balance of every account of one [AccountType], at the end of each
/// of the last N months, oldest first. Dashboard's Savings/Loan sparkline
/// tabs use this — goal accounts for Savings, pay-later accounts for Loan.
///
/// A transfer between two accounts of the *same* type nets to zero (the money
/// never left the group); a transfer across the boundary counts as in/out,
/// same accounting [netWorthTrendProvider] uses for the whole ledger.
final accountTypeBalanceTrendProvider =
    Provider.family<
      List<({DateTime month, Money value})>,
      ({AccountType type, int months})
    >((ref, args) {
      final accounts =
          ref.watch(balanceAccountsProvider).valueOrNull ?? const [];
      final txs = ref.watch(allTransactionsProvider).valueOrNull ?? const [];

      final matching = accounts.where((a) => a.type == args.type).toList();
      final ownIds = {for (final a in matching) a.id};
      final opening = matching.fold(
        const Money.zero(),
        (sum, a) => sum + a.openingBalance,
      );

      final now = DateTime.now();
      final out = <({DateTime month, Money value})>[];

      for (var i = args.months - 1; i >= 0; i--) {
        final end = DateTime(
          now.year,
          now.month - i + 1,
        ).subtract(const Duration(milliseconds: 1));
        var total = opening;

        for (final t in txs) {
          if (t.date.isAfter(end)) continue;
          if (t.type == TxType.transfer) {
            final fromIn = ownIds.contains(t.accountId);
            final toIn =
                t.toAccountId != null && ownIds.contains(t.toAccountId);
            if (fromIn == toIn) continue;
            total += fromIn ? -t.amount : t.amount;
          } else if (ownIds.contains(t.accountId)) {
            total += (t.type == TxType.income || t.type == TxType.personIn)
                ? t.amount
                : -t.amount;
          }
        }
        out.add((month: DateTime(end.year, end.month), value: total));
      }
      return out;
    });

/// Income and expense per month for the last N months, oldest first.
final monthlyTotalsProvider =
    Provider.family<List<({DateTime month, Money income, Money expense})>, int>(
      (ref, months) {
        final txs = ref.watch(allTransactionsProvider).valueOrNull ?? const [];
        final now = DateTime.now();

        return List.generate(months, (i) {
          final m = DateTime(now.year, now.month - (months - 1 - i));
          var income = const Money.zero();
          var expense = const Money.zero();
          for (final t in txs) {
            if (t.date.year != m.year || t.date.month != m.month) continue;
            if (t.type == TxType.income) income += t.amount;
            if (t.type == TxType.expense) expense += t.amount;
          }
          return (month: m, income: income, expense: expense);
        });
      },
    );
