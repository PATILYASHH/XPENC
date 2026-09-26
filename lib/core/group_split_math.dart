import 'money.dart';
import '../data/tables.dart' show GroupSplitMethod;

/// Splits [amount] across [participantIds] (`null` = "me") for
/// [splitMethod], paisa-exact — the returned shares always sum to exactly
/// [amount], never a paisa off either way.
///
/// The *only* place this math is implemented — `AppDatabase.addGroupExpense`
/// and the Add Group Expense screen's live preview both call this, so what
/// a user sees while entering a split is always exactly what gets saved.
///
/// [participantIds]' order decides who gets a rounding remainder paisa
/// first (see [_distributeRemainder]) — pass a stable order (e.g.
/// `GroupMembers.id` order) so which participant gets the extra paisa is
/// deterministic and explainable, not arbitrary.
Map<int?, Money> computeGroupShares({
  required Money amount,
  required GroupSplitMethod splitMethod,
  required List<int?> participantIds,
  Map<int?, int>? percentBasisPoints,
  Map<int?, Money>? manualAmounts,
}) {
  if (participantIds.isEmpty) {
    throw ArgumentError('Need at least one participant.');
  }

  switch (splitMethod) {
    case GroupSplitMethod.equal:
      final base = amount.paise ~/ participantIds.length;
      return _distributeRemainder(amount, participantIds, (_) => base);

    case GroupSplitMethod.percentage:
      if (percentBasisPoints == null) {
        throw ArgumentError('Percentages are required for a percentage split.');
      }
      final totalBp = percentBasisPoints.values.fold(0, (a, b) => a + b);
      // ±0.5% (50 basis points) of slack for display rounding — a manual
      // amount split has no such tolerance (exact integer paise there).
      if ((totalBp - 10000).abs() > 50) {
        throw ArgumentError('Percentages must add up to 100%.');
      }
      return _distributeRemainder(
        amount,
        participantIds,
        (id) => (amount.paise * (percentBasisPoints[id] ?? 0)) ~/ 10000,
      );

    case GroupSplitMethod.manual:
      if (manualAmounts == null) {
        throw ArgumentError('Amounts are required for a manual split.');
      }
      final sum = manualAmounts.values.fold(
        const Money.zero(),
        (a, b) => a + b,
      );
      if (sum != amount) {
        throw ArgumentError('Amounts must add up to the total exactly.');
      }
      return Map.of(manualAmounts);
  }
}

/// Assigns each participant `baseFor(id)` paise, then hands out whatever's
/// left of [amount] one paisa at a time, in [participantIds] order — so the
/// result always sums to exactly [amount].
Map<int?, Money> _distributeRemainder(
  Money amount,
  List<int?> participantIds,
  int Function(int? id) baseFor,
) {
  final result = <int?, Money>{};
  var used = 0;
  for (final id in participantIds) {
    final base = baseFor(id);
    result[id] = Money.fromPaise(base);
    used += base;
  }
  var remainder = amount.paise - used;
  for (final id in participantIds) {
    if (remainder <= 0) break;
    result[id] = result[id]! + const Money(1);
    remainder--;
  }
  return result;
}

/// One person's ledger entry as [allocateGroupDues] sees it: [signed] is
/// `+` for "they owe me", `-` for "I owe them"; [groupId] is the group whose
/// expense created it, or null for an individual entry (a loan, a
/// repayment). [id] breaks ties between entries on the same date.
typedef PersonLedgerItem = ({
  int id,
  DateTime date,
  Money signed,
  int? groupId,
});

/// What one person still owes (`+`) or is owed (`-`) per group, once their
/// individual repayments are applied — keyed by group id.
///
/// Repayments are recorded on the person, not the group, so this decides
/// where each one goes. Walking [items] oldest first:
///
/// * a group share adds to that group's amount;
/// * an individual entry running the *opposite* way to a group's amount (a
///   repayment) settles open group amounts first, oldest group first, and
///   only what's left reaches the individual balance;
/// * a repayment only ever settles what was already owed on its date — an
///   old repayment never wipes out a group bill added after it.
///
/// Nothing is created or lost: the returned group amounts plus the
/// individual remainder always add up to the person's real total.
Map<int, Money> allocateGroupDues(Iterable<PersonLedgerItem> items) {
  final sorted = [...items]
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
  // Insertion-ordered, so iterating it visits the oldest group first.
  final groups = <int, Money>{};
  for (final item in sorted) {
    final groupId = item.groupId;
    if (groupId != null) {
      groups[groupId] = (groups[groupId] ?? const Money.zero()) + item.signed;
      continue;
    }
    var remaining = item.signed.paise;
    for (final id in groups.keys) {
      if (remaining == 0) break;
      final owed = groups[id]!.paise;
      // Only a payment running against the group's direction settles it.
      if (owed == 0 || (owed > 0) == (remaining > 0)) continue;
      final settled = owed.abs() < remaining.abs() ? owed.abs() : remaining.abs();
      final towardZero = owed > 0 ? -settled : settled;
      groups[id] = Money.fromPaise(owed + towardZero);
      remaining -= towardZero;
    }
  }
  return groups;
}

/// One member's share of one group expense, as [computeGroupDebts] sees
/// it. `null` ids mean "me", matching [GroupExpenses.payerId] and
/// [GroupExpenseShares.personId].
typedef GroupShareItem = ({int? payerId, int? memberId, Money amount});

/// [from] owes [to] [amount] (always positive). `null` = "me".
typedef GroupDebt = ({int? from, int? to, Money amount});

/// Every pairwise debt inside one group, netted per pair — the "who owes
/// whom" view.
///
/// Pairs involving me come from [myBalances] (person id → `+` they owe me,
/// `-` I owe them — `groupMemberBalancesProvider`), because that already has
/// my repayments applied. Every other pair comes from [shares] alone: a
/// member owes an expense's payer their share of it. Debts between two
/// other members can't be settled in the app, so those are gross.
///
/// Sorted largest first; zero pairs are dropped.
List<GroupDebt> computeGroupDebts({
  required Iterable<GroupShareItem> shares,
  required Map<int, Money> myBalances,
}) {
  // Keyed by (lower id, higher id); `+` = lower owes higher.
  final pairs = <(int, int), int>{};
  for (final s in shares) {
    final payer = s.payerId;
    final member = s.memberId;
    if (payer == null || member == null || payer == member) continue;
    final key = member < payer ? (member, payer) : (payer, member);
    final signed = member < payer ? s.amount.paise : -s.amount.paise;
    pairs[key] = (pairs[key] ?? 0) + signed;
  }

  final debts = <GroupDebt>[
    for (final MapEntry(key: (a, b), value: paise) in pairs.entries)
      if (paise > 0)
        (from: a, to: b, amount: Money.fromPaise(paise))
      else if (paise < 0)
        (from: b, to: a, amount: Money.fromPaise(-paise)),
    for (final MapEntry(key: id, value: b) in myBalances.entries)
      if (b.isPositive)
        (from: id, to: null, amount: b)
      else if (b.isNegative)
        (from: null, to: id, amount: b.abs),
  ];
  debts.sort((x, y) => y.amount.paise.compareTo(x.amount.paise));
  return debts;
}

/// Each person's net position across [debts]: `+` they get money back,
/// `-` they owe. Always sums to zero.
Map<int?, Money> groupNetBalances(Iterable<GroupDebt> debts) {
  final net = <int?, int>{};
  for (final d in debts) {
    net[d.from] = (net[d.from] ?? 0) - d.amount.paise;
    net[d.to] = (net[d.to] ?? 0) + d.amount.paise;
  }
  return {for (final e in net.entries) e.key: Money.fromPaise(e.value)};
}

/// The fewest payments that clear every [net] balance — the usual "simplify
/// debts" greedy: the biggest debtor pays the biggest creditor, repeat.
/// A suggested payment can be between two people who never owed each other
/// directly; only the totals are guaranteed to match.
///
/// Ties break on id (me first), so the plan is stable between rebuilds.
List<GroupDebt> simplifyGroupDebts(Map<int?, Money> net) {
  int byId(int? a, int? b) => (a ?? -1).compareTo(b ?? -1);
  List<(int?, int)> side(bool creditors) =>
      [
        for (final e in net.entries)
          if (creditors ? e.value.isPositive : e.value.isNegative)
            (e.key, e.value.paise.abs()),
      ]..sort((x, y) {
        final byAmount = y.$2.compareTo(x.$2);
        return byAmount != 0 ? byAmount : byId(x.$1, y.$1);
      });

  final creditors = side(true);
  final debtors = side(false);
  final plan = <GroupDebt>[];
  var c = 0;
  var d = 0;
  while (c < creditors.length && d < debtors.length) {
    final (to, owed) = creditors[c];
    final (from, owes) = debtors[d];
    final paid = owed < owes ? owed : owes;
    plan.add((from: from, to: to, amount: Money.fromPaise(paid)));
    creditors[c] = (to, owed - paid);
    debtors[d] = (from, owes - paid);
    if (creditors[c].$2 == 0) c++;
    if (debtors[d].$2 == 0) d++;
  }
  return plan;
}
