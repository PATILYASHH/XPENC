import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../core/notifications/notification_service.dart';
import '../core/theme/theme_preset.dart';
import '../features/data_export/backup_service.dart';
import '../features/message_capture/capture_service.dart';
import '../features/message_capture/message_source.dart';
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
  final income = ref.watch(categoriesProvider(CategoryKind.income)).valueOrNull ?? [];
  final expense = ref.watch(categoriesProvider(CategoryKind.expense)).valueOrNull ?? [];
  return {for (final c in [...income, ...expense]) c.id: c};
});

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

final monthTotalsProvider =
    StreamProvider<({Money income, Money expense})>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref.watch(dbProvider).watchMonthTotals(month);
});

final spendByCategoryProvider = StreamProvider<Map<int, Money>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1)
      .subtract(const Duration(milliseconds: 1));
  return ref.watch(dbProvider).watchSpendByCategory(start, end);
});

// ── Budgets ─────────────────────────────────────────────────────────────────

final budgetsProvider = StreamProvider<List<BudgetRow>>(
  (ref) => ref.watch(dbProvider).watchBudgets(),
);

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
    final spent = spend[b.categoryId] ?? const Money.zero();
    final fraction =
        b.amount.isZero ? 0.0 : spent.paise / b.amount.paise;
    out.add((
      budget: b,
      category: cat,
      spent: spent,
      fraction: fraction,
      overspent: fraction > 1.0,
      nearingLimit:
          fraction >= b.alertThresholdPct / 100 && fraction <= 1.0,
    ));
  }
  out.sort((a, b) => b.fraction.compareTo(a.fraction));
  return out;
});

// ── Persons ─────────────────────────────────────────────────────────────────

final personsProvider = StreamProvider<List<PersonRow>>(
  (ref) => ref.watch(dbProvider).watchPersons(),
);

final personBalancesProvider = StreamProvider<Map<int, Money>>(
  (ref) => ref.watch(dbProvider).watchAllPersonBalances(),
);

/// For naming the person on a `personOut` / `personIn` ledger row.
final personMapProvider = Provider<Map<int, PersonRow>>((ref) {
  final people = ref.watch(personsProvider).valueOrNull ?? const [];
  return {for (final p in people) p.id: p};
});

final personEntriesProvider =
    StreamProvider.family<List<PersonEntryRow>, int>(
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

// ── Reminders ───────────────────────────────────────────────────────────────

final remindersProvider = StreamProvider<List<ReminderRow>>(
  (ref) => ref.watch(dbProvider).watchReminders(),
);

final openRemindersProvider = Provider<List<ReminderRow>>((ref) {
  final all = ref.watch(remindersProvider).valueOrNull ?? [];
  return all.where((r) => r.status == ReminderStatus.open).toList();
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

// ── Message auto-capture ────────────────────────────────────────────────────

/// SMS reading only exists on Android. Everywhere else capture no-ops.
final messageSourceProvider = Provider<MessageSource>((ref) {
  if (Platform.isAndroid) return const SmsSource();
  return const NullMessageSource();
});

final captureServiceProvider = Provider<CaptureService>(
  (ref) => CaptureService(
    db: ref.watch(dbProvider),
    source: ref.watch(messageSourceProvider),
  ),
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

// ── Export / Backup ─────────────────────────────────────────────────────────

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(dbProvider)),
);

final backupListProvider = FutureProvider<List<BackupFile>>(
  (ref) => ref.watch(backupServiceProvider).listBackups(),
);

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
    Provider.family<List<({DateTime month, Money value})>, int>(
  (ref, months) {
    final accounts = ref.watch(balanceAccountsProvider).valueOrNull ?? const [];
    final txs = ref.watch(allTransactionsProvider).valueOrNull ?? const [];
    final entries = ref.watch(allPersonEntriesProvider).valueOrNull ?? const [];

    final opening = accounts.fold(
      const Money.zero(),
      (sum, a) => sum + a.openingBalance,
    );

    final now = DateTime.now();
    final out = <({DateTime month, Money value})>[];

    for (var i = months - 1; i >= 0; i--) {
      // Last millisecond of the month `i` months back. DateTime normalises the
      // month overflow/underflow, so December and January need no special case.
      final end = DateTime(now.year, now.month - i + 1)
          .subtract(const Duration(milliseconds: 1));
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
        total += e.direction == PersonDirection.theyOwe ? -e.amount : e.amount;
      }
      out.add((month: DateTime(end.year, end.month), value: total));
    }
    return out;
  },
);

/// Income and expense per month for the last N months, oldest first.
final monthlyTotalsProvider = Provider.family<
    List<({DateTime month, Money income, Money expense})>, int>(
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
