import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/budget_cycle.dart';
import '../core/money.dart';
import 'database.dart';
import 'modes_db.dart';
import 'providers.dart';
import 'tables.dart';

// Modes — see `Modes` in tables.dart and `modes_db.dart`.

/// A mode's limits and auto-tags. An empty [accountIds] or [categoryIds]
/// means no limit; [tagIds] are added to every new transaction in it.
typedef ModeConfig = ({
  Set<int> accountIds,
  Set<int> categoryIds,
  Set<int> tagIds,
});

/// What a mode came to. [spent] counts money out (expenses) only; transfers
/// and lending in the mode show on its page but don't add to it.
typedef ModeSummary = ({
  Money spent,
  int count,
  DateTime? first,
  DateTime? last,
  Map<int, Money> byCategory,
  Map<int, Money> byAccount,
});

final modesProvider = StreamProvider<List<ModeRow>>(
  (ref) => ref.watch(dbProvider).watchModes(),
);

final modeMapProvider = Provider<Map<int, ModeRow>>((ref) {
  final modes = ref.watch(modesProvider).valueOrNull ?? const [];
  return {for (final m in modes) m.id: m};
});

/// The mode that's ON, if any.
final activeModeProvider = Provider<ModeRow?>((ref) {
  final id = ref.watch(settingsProvider).valueOrNull?.activeModeId;
  if (id == null) return null;
  return ref.watch(modeMapProvider)[id];
});

/// "Exit to full app": the mode stays ON (new spends still join it) but the
/// everyday app comes back. Per session — a relaunch goes back to the trip.
final modeFullAppProvider = StateProvider<bool>((ref) => false);

/// The mode the app is focused on — the active one, unless the person
/// stepped out to the full app.
final focusedModeProvider = Provider<ModeRow?>((ref) {
  if (ref.watch(modeFullAppProvider)) return null;
  return ref.watch(activeModeProvider);
});

final _modeAccountLinksProvider = StreamProvider<List<ModeAccountRow>>(
  (ref) => ref.watch(dbProvider).watchModeAccounts(),
);
final _modeCategoryLinksProvider = StreamProvider<List<ModeCategoryRow>>(
  (ref) => ref.watch(dbProvider).watchModeCategories(),
);
final _modeTagLinksProvider = StreamProvider<List<ModeTagRow>>(
  (ref) => ref.watch(dbProvider).watchModeTags(),
);

final modeConfigProvider = Provider.family<ModeConfig, int>((ref, modeId) {
  final accounts = ref.watch(_modeAccountLinksProvider).valueOrNull ?? const [];
  final cats = ref.watch(_modeCategoryLinksProvider).valueOrNull ?? const [];
  final tags = ref.watch(_modeTagLinksProvider).valueOrNull ?? const [];
  return (
    accountIds: {
      for (final l in accounts)
        if (l.modeId == modeId) l.accountId,
    },
    categoryIds: {
      for (final l in cats)
        if (l.modeId == modeId) l.categoryId,
    },
    tagIds: {
      for (final l in tags)
        if (l.modeId == modeId) l.tagId,
    },
  );
});

/// Every transaction in a mode, newest first.
final modeTransactionsProvider = Provider.family<List<TransactionRow>, int>((
  ref,
  modeId,
) {
  final txs = ref.watch(allTransactionsProvider).valueOrNull ?? const [];
  return [
    for (final t in txs)
      if (t.modeId == modeId) t,
  ];
});

final modeSummaryProvider = Provider.family<ModeSummary, int>((ref, modeId) {
  final txs = ref.watch(modeTransactionsProvider(modeId));
  final splitsByTx = ref.watch(transactionSplitsByTxProvider);
  return summarizeMode(txs, splitsByTx);
});

/// [ModeSummary] of [txs] — every one already in the mode.
ModeSummary summarizeMode(
  List<TransactionRow> txs,
  Map<int, List<TransactionSplitRow>> splitsByTx,
) {
  var spent = const Money.zero();
  DateTime? first;
  DateTime? last;
  final byCategory = <int, Money>{};
  final byAccount = <int, Money>{};
  for (final t in txs) {
    if (first == null || t.date.isBefore(first)) first = t.date;
    if (last == null || t.date.isAfter(last)) last = t.date;
    if (t.type != TxType.expense) continue;
    spent += t.amount;
    byAccount[t.accountId] =
        (byAccount[t.accountId] ?? const Money.zero()) + t.amount;
    if (t.categoryId != null) {
      byCategory[t.categoryId!] =
          (byCategory[t.categoryId!] ?? const Money.zero()) + t.amount;
    } else {
      for (final s in splitsByTx[t.id] ?? const <TransactionSplitRow>[]) {
        byCategory[s.categoryId] =
            (byCategory[s.categoryId] ?? const Money.zero()) + s.amount;
      }
    }
  }
  return (
    spent: spent,
    count: txs.length,
    first: first,
    last: last,
    byCategory: byCategory,
    byAccount: byAccount,
  );
}

/// Each mode's spending in the selected month — the one slice per mode that
/// category breakdowns show in place of its transactions.
final modeSpendForPeriodProvider = Provider<Map<int, Money>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final period = budgetPeriodFor(month, ref.watch(budgetStartDayProvider));
  return _modeSpend(
    ref.watch(allTransactionsProvider).valueOrNull ?? const [],
    (d) => !d.isBefore(period.start) && !d.isAfter(period.end),
  );
});

/// [modeSpendForPeriodProvider] for a whole calendar year.
final yearModeSpendProvider = Provider.family<Map<int, Money>, int>((
  ref,
  year,
) {
  return _modeSpend(
    ref.watch(allTransactionsProvider).valueOrNull ?? const [],
    (d) => d.year == year,
  );
});

Map<int, Money> _modeSpend(
  List<TransactionRow> txs,
  bool Function(DateTime) inRange,
) {
  final out = <int, Money>{};
  for (final t in txs) {
    final mode = t.modeId;
    if (mode == null || t.type != TxType.expense || !inRange(t.date)) continue;
    out[mode] = (out[mode] ?? const Money.zero()) + t.amount;
  }
  return out;
}

/// The categories of [kind] a picker offers for a transaction in mode
/// [modeId] (null = not in a mode): everyday ones — only the allowed ones if
/// the mode limits them — plus the mode's own.
final pickerCategoriesProvider =
    Provider.family<List<CategoryRow>, (CategoryKind, int?)>((ref, args) {
      final (kind, modeId) = args;
      final everyday =
          ref.watch(categoriesProvider(kind)).valueOrNull ?? const [];
      if (modeId == null) return everyday;
      final allowed = ref.watch(modeConfigProvider(modeId)).categoryIds;
      final own = ref.watch(modeOwnCategoriesProvider).valueOrNull ?? const [];
      return [
        for (final c in own)
          if (c.modeId == modeId && c.kind == kind) c,
        for (final c in everyday)
          if (allowed.isEmpty ||
              allowed.contains(c.id) ||
              (c.parentId != null && allowed.contains(c.parentId)))
            c,
      ];
    });

/// The tags a picker offers in mode [modeId]: everyday ones plus the mode's
/// own.
final pickerTagsProvider = Provider.family<List<TagRow>, int?>((ref, modeId) {
  final tags = ref.watch(tagsProvider).valueOrNull ?? const [];
  return [
    for (final t in tags)
      if (t.modeId == null || (modeId != null && t.modeId == modeId)) t,
  ];
});

/// The accounts a picker offers in mode [modeId]: the allowed ones, or all
/// of them when the mode sets no limit.
final pickerAccountsProvider = Provider.family<List<AccountRow>, int?>((
  ref,
  modeId,
) {
  final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
  if (modeId == null) return accounts;
  final allowed = ref.watch(modeConfigProvider(modeId)).accountIds;
  if (allowed.isEmpty) return accounts;
  return [
    for (final a in accounts)
      if (allowed.contains(a.id)) a,
  ];
});

/// Which day of the mode [now] is (1 on its first day), or null before it
/// started.
int? modeDayNumber(ModeRow mode, DateTime now) {
  final start = mode.startedAt ?? mode.startDate;
  if (start == null) return null;
  final from = DateTime(start.year, start.month, start.day);
  final today = DateTime(now.year, now.month, now.day);
  if (today.isBefore(from)) return null;
  return today.difference(from).inDays + 1;
}

/// How many days the mode covers so far (at least 1) — the divisor of its
/// per-day average. An ended mode stops counting on its last day.
int modeDaysElapsed(ModeRow mode, DateTime now) {
  final start = mode.startedAt ?? mode.startDate;
  if (start == null) return 1;
  final stop = mode.status == ModeStatus.ended
      ? (mode.endedAt ?? mode.endDate ?? now)
      : now;
  final from = DateTime(start.year, start.month, start.day);
  final to = DateTime(stop.year, stop.month, stop.day);
  final days = to.difference(from).inDays + 1;
  return days < 1 ? 1 : days;
}

// ── v2: allocations, limits, people, planned costs, templates, sandbox ─────

final _modeCategoryLimitRowsProvider =
    StreamProvider<List<ModeCategoryLimitRow>>(
      (ref) => ref.watch(dbProvider).watchModeCategoryLimits(),
    );
final _modePlannedCostRowsProvider = StreamProvider<List<ModePlannedCostRow>>(
  (ref) => ref.watch(dbProvider).watchModePlannedCosts(),
);
final _modePersonEntryRowsProvider = StreamProvider<List<PersonEntryRow>>(
  (ref) => ref.watch(dbProvider).watchModePersonEntries(),
);

/// Each of a mode's accounts and what it was allocated (null = none).
final modeAllocationsProvider = Provider.family<Map<int, Money?>, int>((
  ref,
  modeId,
) {
  final links = ref.watch(_modeAccountLinksProvider).valueOrNull ?? const [];
  return {
    for (final l in links)
      if (l.modeId == modeId) l.accountId: l.allocation,
  };
});

/// A mode's planned costs, in their order.
final modePlannedCostsProvider = Provider.family<List<ModePlannedCostRow>, int>(
  (ref, modeId) {
    final rows =
        ref.watch(_modePlannedCostRowsProvider).valueOrNull ?? const [];
    return [
      for (final c in rows)
        if (c.modeId == modeId) c,
    ];
  },
);

/// One category cap in a mode, and what's gone against it (a parent's cap
/// counts its subcategories).
typedef ModeLimitLine = ({int categoryId, Money limit, Money spent});

final modeCategoryLimitsProvider = Provider.family<List<ModeLimitLine>, int>((
  ref,
  modeId,
) {
  final rows =
      ref.watch(_modeCategoryLimitRowsProvider).valueOrNull ?? const [];
  final cats = ref.watch(categoryMapProvider);
  final spentBy = ref.watch(modeSummaryProvider(modeId)).byCategory;
  return [
    for (final l in rows)
      if (l.modeId == modeId)
        (
          categoryId: l.categoryId,
          limit: l.amount,
          spent: spentBy.entries
              .where(
                (e) =>
                    e.key == l.categoryId ||
                    cats[e.key]?.parentId == l.categoryId,
              )
              .fold(const Money.zero(), (a, e) => a + e.value),
        ),
  ];
});

/// Where a mode stands against its money: [budget] (its own, or its
/// allocations' total), [spent], unpaid [planned] costs, what's [left]
/// (budget − spent − planned), and — with an end date — [daysLeft] and the
/// [perDayLeft] that keeps it in budget. [today] is today's spend.
typedef ModeBudgetView = ({
  Money? budget,
  Money spent,
  Money planned,
  Money? left,
  int? daysLeft,
  Money? perDayLeft,
  Money today,
});

final modeBudgetProvider = Provider.family<ModeBudgetView, int>((ref, modeId) {
  final mode = ref.watch(modeMapProvider)[modeId];
  final summary = ref.watch(modeSummaryProvider(modeId));
  final budget = effectiveModeBudget(
    mode?.budget,
    ref.watch(modeAllocationsProvider(modeId)).values,
  );
  final planned = ref
      .watch(modePlannedCostsProvider(modeId))
      .where((c) => c.transactionId == null)
      .fold(const Money.zero(), (a, c) => a + c.amount);
  final now = DateTime.now();
  final today = ref
      .watch(modeTransactionsProvider(modeId))
      .where(
        (t) =>
            t.type == TxType.expense &&
            t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day,
      )
      .fold(const Money.zero(), (a, t) => a + t.amount);
  final left = budget == null ? null : budget - summary.spent - planned;
  final end = mode?.endDate;
  int? daysLeft;
  if (end != null) {
    final d = DateTime(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    daysLeft = d < 0 ? 0 : d + 1;
  }
  return (
    budget: budget,
    spent: summary.spent,
    planned: planned,
    left: left,
    daysLeft: daysLeft,
    perDayLeft: left == null || daysLeft == null || daysLeft == 0
        ? null
        : Money(left.paise ~/ daysLeft),
    today: today,
  );
});

/// A mode account as the mode sees it: [allocation] (null = none) and its
/// [balance] — what's left of the allocation, or the real balance.
typedef ModeAccountBalance = ({Money? allocation, Money balance});

final modeAccountBalancesProvider =
    Provider.family<Map<int, ModeAccountBalance>, int>((ref, modeId) {
      final allocations = ref.watch(modeAllocationsProvider(modeId));
      final accounts = ref.watch(accountMapProvider);
      final txs = ref.watch(modeTransactionsProvider(modeId));
      return {
        for (final e in allocations.entries)
          if (accounts[e.key] != null)
            e.key: (
              allocation: e.value,
              balance: e.value == null
                  ? accounts[e.key]!.currentBalance
                  : allocatedBalance(e.value!, e.key, txs),
            ),
      };
    });

/// The people on a mode — its group's members.
final modePeopleProvider = Provider.family<List<PersonRow>, int>((ref, modeId) {
  final groupId = ref.watch(modeMapProvider)[modeId]?.groupId;
  if (groupId == null) return const [];
  return ref.watch(groupMembersProvider(groupId)).valueOrNull ?? const [];
});

/// Each person's balance inside a mode only — `+` they owe you, `-` you owe
/// them — from the entries made in it. Their real balance is untouched.
final tripBalancesProvider = Provider.family<Map<int, Money>, int>((
  ref,
  modeId,
) {
  final rows = ref.watch(_modePersonEntryRowsProvider).valueOrNull ?? const [];
  final out = <int, Money>{};
  for (final e in rows) {
    if (e.modeId != modeId) continue;
    final signed = e.direction == PersonDirection.theyOwe
        ? e.amount
        : -e.amount;
    out[e.personId] = (out[e.personId] ?? const Money.zero()) + signed;
  }
  return out;
});

/// Every person entry made in a mode.
final modePersonEntriesProvider = Provider.family<List<PersonEntryRow>, int>((
  ref,
  modeId,
) {
  final rows = ref.watch(_modePersonEntryRowsProvider).valueOrNull ?? const [];
  return [
    for (final e in rows)
      if (e.modeId == modeId) e,
  ];
});

/// A mode's own templates.
final modeTemplatesProvider =
    StreamProvider.family<List<TransactionTemplateRow>, int>(
      (ref, modeId) => ref.watch(dbProvider).watchModeTemplates(modeId),
    );

/// The ➕ templates to offer right now: the focused mode's own, or the
/// everyday ones.
final shownTemplatesProvider = Provider<List<TransactionTemplateRow>>((ref) {
  final mode = ref.watch(focusedModeProvider);
  if (mode != null) {
    return ref.watch(modeTemplatesProvider(mode.id)).valueOrNull ?? const [];
  }
  return ref.watch(transactionTemplatesProvider).valueOrNull ?? const [];
});

/// The ledger as the app shows it right now — a focused mode's sandbox
/// (only its transactions), or everything. For views only: anything that
/// walks balances needs the whole ledger ([allTransactionsProvider]).
final viewTransactionsProvider = Provider<AsyncValue<List<TransactionRow>>>((
  ref,
) {
  final all = ref.watch(allTransactionsProvider);
  final mode = ref.watch(focusedModeProvider);
  if (mode == null) return all;
  return all.whenData(
    (txs) => [
      for (final t in txs)
        if (t.modeId == mode.id) t,
    ],
  );
});
