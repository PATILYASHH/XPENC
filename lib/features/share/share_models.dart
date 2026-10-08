import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency.dart';
import '../../core/group_split_math.dart';
import '../../core/money.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

// What a share — PDF or image — says about a transaction, a person or a
// group, resolved once from the live providers. Both renderers read these
// plain snapshots, so each stays a pure function of its data (and testable
// without a ProviderScope).

/// Who "I" am on a shared page. A statement goes to the *other* person, so
/// "You owe Ram" would read backwards on their phone — with the user's own
/// name set (Settings → UPI name) it reads "Yash owes Ram" instead.
class ShareOwner {
  const ShareOwner(this.name);

  /// The user's own name, or null to fall back to "you".
  final String? name;

  static ShareOwner of(ProviderContainer ref) {
    final name = ref.read(myUpiNameProvider)?.trim();
    return ShareOwner(name == null || name.isEmpty ? null : name);
  }

  /// "You" / "Yash" — as a sentence's subject.
  String get subject => name ?? 'You';

  /// "you" / "Yash" — as its object.
  String get object => name ?? 'you';

  /// "You gave" / "Yash gave".
  String get gave => '$subject gave';

  /// The plain-language reading of a balance with [other]: `+` they owe me.
  String balanceLine(Money balance, String other) {
    if (balance.isPositive) return '$other owes $object';
    if (balance.isNegative) {
      return name == null ? 'You owe $other' : '$name owes $other';
    }
    return 'All settled';
  }
}

/// A transaction, with every id already turned into the name it stands for.
class TransactionShare {
  const TransactionShare({
    required this.tx,
    required this.headline,
    required this.typeLabel,
    required this.currency,
    required this.account,
    this.category,
    this.categoryIconKey,
    this.categoryColor,
    this.fundedFrom,
    this.payee,
    this.person,
    this.tags = const [],
    this.splits = const [],
    this.foreign,
    this.received,
    this.note,
    this.rule,
  });

  final TransactionRow tx;

  /// Who or what it was — the payee, the person, the category, the route of
  /// a transfer — the line under the amount.
  final String headline;

  /// "Expense", "Gave to Ram", "Transfer"...
  final String typeLabel;

  /// The currency the amount is in — the row's own, else the app's.
  final Currency currency;

  /// "Paid via HDFC", "HDFC → Cash"...
  final String account;

  /// "Food › Dining". Null for a transfer, a correction or a split.
  final String? category;
  final String? categoryIconKey;
  final int? categoryColor;

  /// A debit card's bank — where the money actually left from.
  final String? fundedFrom;
  final String? payee;
  final String? person;
  final List<TagRow> tags;
  final List<ShareSplit> splits;

  /// What was actually charged in a foreign currency (GitHub #85).
  final (Money, Currency)? foreign;

  /// A transfer into an account in another currency: what arrived there.
  final (Money, Currency)? received;
  final String? note;

  /// The Auto rule that posted it.
  final String? rule;

  bool get isTransfer => tx.type == TxType.transfer;

  /// Money that left reads negative; a transfer has no sign at all.
  Money get signedAmount => tx.type.takesFromAccount ? -tx.amount : tx.amount;

  Color get color => colorForTxType(tx.type);

  /// The date, plus the time when one was actually recorded.
  bool get hasTime => tx.date.hour != 0 || tx.date.minute != 0;

  static TransactionShare resolve(ProviderContainer ref, TransactionRow t) {
    final categories = ref.read(categoryMapProvider);
    final accounts = {
      for (final a in ref.read(archivedAccountsProvider).valueOrNull ?? [])
        a.id: a,
      ...ref.read(accountMapProvider),
    };
    final people = ref.read(allPersonsByIdProvider);
    final rules = ref.read(recurringRuleMapProvider);
    final tags = ref.read(transactionTagsByTxProvider)[t.id] ?? const [];
    final splits = ref.read(transactionSplitsByTxProvider)[t.id] ?? const [];

    String categoryPath(CategoryRow c) {
      final parent = c.parentId == null ? null : categories[c.parentId];
      return parent == null ? c.name : '${parent.name} › ${c.name}';
    }

    final category = t.categoryId == null ? null : categories[t.categoryId];
    final personName = t.personId == null ? null : people[t.personId]?.name;
    final account = accounts[t.accountId];
    final acct = account?.name ?? '—';
    final toAcct = accounts[t.toAccountId]?.name ?? '—';
    final linked = account?.linkedAccountId == null
        ? null
        : accounts[account!.linkedAccountId];
    final payee = t.payee?.trim();
    final note = t.note?.trim();
    final currency = t.currencyCode == null
        ? MoneyFormat.currency
        : currencyForCode(t.currencyCode);

    final typeLabel = switch (t.type) {
      TxType.correctionIn => 'Correction · added',
      TxType.correctionOut => 'Correction · removed',
      _ => labelForTxType(t.type, personName: personName),
    };

    final headline = switch (t.type) {
      TxType.transfer => '$acct → $toAcct',
      TxType.personOut || TxType.personIn => typeLabel,
      TxType.correctionIn || TxType.correctionOut => 'Balance correction',
      _ when payee != null && payee.isNotEmpty => payee,
      _ when splits.isNotEmpty => 'Split across ${splits.length} categories',
      _ => category?.name ?? typeLabel,
    };

    return TransactionShare(
      tx: t,
      headline: headline,
      typeLabel: typeLabel,
      currency: currency,
      account: switch (t.type) {
        TxType.income => 'Deposited to $acct',
        TxType.expense => 'Paid via $acct',
        TxType.transfer => '$acct → $toAcct',
        TxType.personOut => 'Given from $acct',
        TxType.personIn => 'Received into $acct',
        TxType.correctionIn => 'Added to $acct',
        TxType.correctionOut => 'Removed from $acct',
      },
      category: category == null || splits.isNotEmpty
          ? null
          : categoryPath(category),
      categoryIconKey: category?.iconKey,
      categoryColor: category?.colorValue,
      fundedFrom: linked?.name,
      payee: payee == null || payee.isEmpty ? null : payee,
      person: personName,
      tags: tags,
      splits: [
        for (final s in splits)
          ShareSplit(
            name: categories[s.categoryId] == null
                ? 'Uncategorised'
                : categoryPath(categories[s.categoryId]!),
            amount: s.amount,
            iconKey: categories[s.categoryId]?.iconKey,
            color: categories[s.categoryId]?.colorValue,
          ),
      ],
      foreign: t.foreignCurrencyCode != null && t.foreignAmount != null
          ? (t.foreignAmount!, currencyForCode(t.foreignCurrencyCode))
          : null,
      received:
          t.type == TxType.transfer &&
              t.toAmount != null &&
              t.toCurrencyCode != null &&
              t.toCurrencyCode != currency.code
          ? (t.toAmount!, currencyForCode(t.toCurrencyCode))
          : null,
      note: note == null || note.isEmpty ? null : note,
      rule: t.recurringRuleId == null ? null : rules[t.recurringRuleId]?.name,
    );
  }
}

class ShareSplit {
  const ShareSplit({
    required this.name,
    required this.amount,
    this.iconKey,
    this.color,
  });

  final String name;
  final Money amount;
  final String? iconKey;
  final int? color;
}

/// The period a ledger share covers. [range] null = everything.
class SharePeriod {
  const SharePeriod(this.label, this.range);

  static const allTime = SharePeriod('All time', null);

  final String label;
  final DateTimeRange? range;

  static SharePeriod thisMonth([DateTime? now]) {
    final n = now ?? DateTime.now();
    return SharePeriod(
      'This month',
      DateTimeRange(
        start: DateTime(n.year, n.month),
        end: DateTime(n.year, n.month + 1).subtract(const Duration(days: 1)),
      ),
    );
  }

  static SharePeriod lastMonth([DateTime? now]) {
    final n = now ?? DateTime.now();
    return SharePeriod(
      'Last month',
      DateTimeRange(
        start: DateTime(n.year, n.month - 1),
        end: DateTime(n.year, n.month).subtract(const Duration(days: 1)),
      ),
    );
  }

  bool contains(DateTime d) {
    final r = range;
    if (r == null) return true;
    return !d.isBefore(r.start) &&
        d.isBefore(DateTime(r.end.year, r.end.month, r.end.day + 1));
  }

  /// Strictly before the period — what its opening balance is made of.
  bool isBefore(DateTime d) => range != null && d.isBefore(range!.start);
}

/// One person's ledger — every entry, not just a period's, so a period's
/// opening balance can be worked out from what came before it.
class PersonShare {
  const PersonShare({
    required this.person,
    required this.owner,
    required this.entries,
    required this.balance,
    this.groupNames = const {},
  });

  final PersonRow person;
  final ShareOwner owner;
  final List<PersonEntryRow> entries;

  /// The live all-time balance (`+` they owe me).
  final Money balance;

  /// Entry id → the group whose split created it.
  final Map<int, String> groupNames;

  static Future<PersonShare> load(
    ProviderContainer ref,
    PersonRow person,
  ) async {
    final entries = await ref.read(personEntriesProvider(person.id).future);
    final groupIds = await ref.read(personEntryGroupIdsProvider.future);
    final groups = ref.read(allGroupsMapProvider);
    return PersonShare(
      person: person,
      owner: ShareOwner.of(ref),
      entries: entries,
      balance:
          ref.read(personBalancesProvider).valueOrNull?[person.id] ??
          entries.fold(const Money.zero(), (s, e) => s + signed(e)),
      groupNames: {
        for (final e in entries)
          if (groups[groupIds[e.id]] case final g?) e.id: g.name,
      },
    );
  }

  /// `+` = this entry adds to what they owe me.
  static Money signed(PersonEntryRow e) =>
      e.direction == PersonDirection.theyOwe ? e.amount : -e.amount;

  /// "Lunch money", else what happened in plain words.
  String titleOf(PersonEntryRow e) {
    final note = e.note?.trim();
    if (note != null && note.isNotEmpty) return note;
    if (e.categoryId != null) return '${person.name} repaid';
    return e.direction == PersonDirection.theyOwe
        ? owner.gave
        : '${person.name} gave';
  }

  DateTime? get firstDate => entries.isEmpty
      ? null
      : entries.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b);

  PersonLedger ledger(SharePeriod period) {
    final sorted = [...entries]
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
      });
    var opening = const Money.zero();
    var given = const Money.zero();
    var got = const Money.zero();
    final lines = <PersonLedgerLine>[];
    var running = const Money.zero();
    for (final e in sorted) {
      if (period.isBefore(e.date)) {
        opening += signed(e);
        running = opening;
        continue;
      }
      if (!period.contains(e.date)) continue;
      running += signed(e);
      if (e.direction == PersonDirection.theyOwe) {
        given += e.amount;
      } else {
        got += e.amount;
      }
      lines.add(PersonLedgerLine(entry: e, balance: running));
    }
    return PersonLedger(
      opening: opening,
      ownerGave: given,
      theyGave: got,
      closing: opening + given - got,
      lines: lines,
    );
  }
}

class PersonLedger {
  const PersonLedger({
    required this.opening,
    required this.ownerGave,
    required this.theyGave,
    required this.closing,
    required this.lines,
  });

  final Money opening;
  final Money ownerGave;
  final Money theyGave;
  final Money closing;

  /// Oldest first, each with the running balance after it.
  final List<PersonLedgerLine> lines;
}

class PersonLedgerLine {
  const PersonLedgerLine({required this.entry, required this.balance});

  final PersonEntryRow entry;
  final Money balance;
}

/// One group's expenses, members and who-owes-whom.
class GroupShare {
  const GroupShare({
    required this.group,
    required this.owner,
    required this.members,
    required this.expenses,
    required this.myShares,
    required this.names,
    required this.debts,
    required this.balance,
  });

  final GroupRow group;
  final ShareOwner owner;
  final List<PersonRow> members;
  final List<GroupExpenseRow> expenses;

  /// Expense id → my own share of it (absent when I had none).
  final Map<int, Money> myShares;

  /// Person id → name, archived people included.
  final Map<int, String> names;

  /// Today's who-owes-whom, largest first.
  final List<GroupDebt> debts;

  /// My aggregate balance in this group (`+` owed to me).
  final Money balance;

  static Future<GroupShare> load(ProviderContainer ref, GroupRow group) async {
    final members = await ref.read(groupMembersProvider(group.id).future);
    final expenses = await ref.read(groupExpensesProvider(group.id).future);
    final shares = await ref.read(groupExpenseSharesProvider(group.id).future);
    // The balances below are derived from these; make sure they're loaded.
    await ref.read(allPersonEntriesProvider.future);
    await ref.read(personEntryGroupIdsProvider.future);
    return GroupShare(
      group: group,
      owner: ShareOwner.of(ref),
      members: members,
      expenses: expenses,
      myShares: {
        for (final s in shares)
          if (s.personId == null) s.groupExpenseId: s.amount,
      },
      names: {
        for (final p in ref.read(allPersonsByIdProvider).values) p.id: p.name,
      },
      debts: ref.read(groupDebtsProvider(group.id)),
      balance: ref.read(groupBalanceProvider(group.id)),
    );
  }

  /// A person id, or null for me, as a name.
  String nameOf(int? id) =>
      id == null ? owner.subject : (names[id] ?? 'Someone');

  String titleOf(GroupExpenseRow e) {
    final note = e.note?.trim();
    return note == null || note.isEmpty ? 'Group expense' : note;
  }

  static String splitLabel(GroupSplitMethod m) => switch (m) {
    GroupSplitMethod.equal => 'Equal',
    GroupSplitMethod.percentage => 'By %',
    GroupSplitMethod.manual => 'Custom',
  };

  /// [period]'s expenses, newest first, with their totals.
  GroupPeriod slice(SharePeriod period) {
    final list = expenses.where((e) => period.contains(e.date)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    var total = const Money.zero();
    var mine = const Money.zero();
    for (final e in list) {
      total += e.amount;
      mine += myShares[e.id] ?? const Money.zero();
    }
    return GroupPeriod(expenses: list, total: total, myShare: mine);
  }
}

class GroupPeriod {
  const GroupPeriod({
    required this.expenses,
    required this.total,
    required this.myShare,
  });

  final List<GroupExpenseRow> expenses;
  final Money total;
  final Money myShare;
}
