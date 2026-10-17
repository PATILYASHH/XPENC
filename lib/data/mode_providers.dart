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
