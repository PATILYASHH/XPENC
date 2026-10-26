import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/currency.dart';
import '../../core/group_split_math.dart';
import '../../core/money.dart';
import '../../core/payments/cashapp_launcher.dart';
import '../../core/payments/paypal_launcher.dart';
import '../../core/payments/revolut_launcher.dart';
import '../../core/payments/upi_launcher.dart';
import '../../core/payments/venmo_launcher.dart';
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

/// A scan-to-pay code on a shared statement: the user's own payment ID
/// with what's owed filled in, so whoever it's sent to can settle up from
/// the card itself.
class PaymentQr {
  const PaymentQr({
    required this.method,
    required this.id,
    required this.link,
    required this.amount,
    required this.hint,
    this.payTo,
  });

  /// "UPI", "PayPal"...
  final String method;

  /// The ID as the user typed it — shown under the code.
  final String id;

  /// What the code encodes: a `upi://pay` link, a paypal.me link...
  final String link;
  final Money amount;

  /// How to scan it — "Scan with any UPI app".
  final String hint;

  /// The user's name, when set.
  final String? payTo;

  /// One per payment method that's on and has the user's own ID, UPI first.
  /// Empty unless [owed] is positive — there's nothing to pay otherwise.
  static List<PaymentQr> optionsFor(ProviderContainer ref, Money owed) {
    if (!owed.isPositive) return const [];
    String? own(String? v) => (v?.trim().isEmpty ?? true) ? null : v!.trim();
    final name = own(ref.read(myUpiNameProvider));
    const camera = 'Scan with your phone camera';
    final upi = own(ref.read(myUpiIdProvider));
    final paypal = own(ref.read(myPaypalProvider));
    final venmo = own(ref.read(myVenmoProvider));
    final cashapp = own(ref.read(myCashappProvider));
    final revolut = own(ref.read(myRevolutProvider));
    return [
      if (upi != null && ref.read(upiEnabledProvider))
        PaymentQr(
          method: 'UPI',
          id: upi,
          link: UpiLauncher.buildUri(
            action: UpiAction.pay,
            payeeUpiId: upi,
            payeeName: name ?? '',
            amount: owed,
            note: 'Settlement via XPENC',
          ).toString(),
          amount: owed,
          hint: 'Scan with any UPI app',
          payTo: name,
        ),
      if (paypal != null && ref.read(paypalEnabledProvider))
        PaymentQr(
          method: 'PayPal',
          id: 'paypal.me/${PaypalLauncher.normalizeId(paypal)}',
          link: PaypalLauncher.buildUri(
            paypalId: paypal,
            amount: owed,
            currencyCode: ref.read(currencyProvider).code,
          ).toString(),
          amount: owed,
          hint: camera,
          payTo: name,
        ),
      if (venmo != null && ref.read(venmoEnabledProvider))
        PaymentQr(
          method: 'Venmo',
          id: '@${VenmoLauncher.normalizeUsername(venmo)}',
          link: VenmoLauncher.buildUri(
            username: venmo,
            amount: owed,
          ).toString(),
          amount: owed,
          hint: camera,
          payTo: name,
        ),
      if (cashapp != null && ref.read(cashappEnabledProvider))
        PaymentQr(
          method: 'Cash App',
          id: CashAppLauncher.normalizeCashtag(cashapp),
          link: CashAppLauncher.buildUri(
            cashtag: cashapp,
            amount: owed,
          ).toString(),
          amount: owed,
          hint: camera,
          payTo: name,
        ),
      if (revolut != null && ref.read(revolutEnabledProvider))
        PaymentQr(
          method: 'Revolut',
          id: '@${RevolutLauncher.normalizeUsername(revolut)}',
          link: RevolutLauncher.buildUri(
            username: revolut,
            amount: owed,
          ).toString(),
          amount: owed,
          hint: camera,
          payTo: name,
        ),
    ];
  }
}

/// [phone] as WhatsApp's chat id: international digits, no `+`. Null when
/// the country can't be told — WhatsApp then lets the user pick the chat,
/// which beats opening a stranger's. A bare 10-digit number counts as
/// Indian when the app runs in rupees.
String? whatsappJid(String? phone, {required String currencyCode}) {
  final raw = phone?.trim() ?? '';
  if (raw.isEmpty) return null;
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  final String full;
  if (raw.startsWith('+')) {
    full = digits;
  } else if (digits.startsWith('00')) {
    full = digits.substring(2);
  } else {
    final local = digits.replaceFirst(RegExp(r'^0+'), '');
    if (currencyCode != 'INR' || local.length != 10) return null;
    full = '91$local';
  }
  // E.164 caps a number at 15 digits; anything under 8 isn't one.
  return full.length >= 8 && full.length <= 15 ? full : null;
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

  /// Dates the user picked — "3 Sep – 12 Oct", with the years where they
  /// aren't this one's.
  static SharePeriod custom(DateTimeRange r, [DateTime? now]) {
    final year = (now ?? DateTime.now()).year;
    final startYear = r.start.year != r.end.year || r.start.year != year;
    final start = DateFormat(startYear ? 'd MMM yyyy' : 'd MMM').format(r.start);
    final end = DateFormat(r.end.year != year ? 'd MMM yyyy' : 'd MMM')
        .format(r.end);
    return SharePeriod('$start – $end', r);
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

  /// The message that goes with the file into their chat — first person,
  /// since it comes from the user's own phone.
  String message({PaymentQr? qr}) {
    final amount = MoneyFormat.forCurrency(balance.abs, MoneyFormat.currency);
    final where = balance.isPositive
        ? 'you owe me $amount.'
        : balance.isNegative
        ? 'I owe you $amount.'
        : "we're all settled.";
    final pay = qr == null ? '' : ' Scan the QR to pay by ${qr.method}.';
    return "Hi ${person.name}, here's where we stand: $where$pay";
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

/// A mode (a trip) told back — the data behind its summary card and PDF.
/// Built by the mode's summary screen from what's on it.
class ModeShare {
  const ModeShare({
    required this.name,
    required this.colorValue,
    required this.dates,
    required this.spent,
    required this.budget,
    required this.planned,
    required this.days,
    required this.perDay,
    required this.count,
    required this.categories,
    required this.accounts,
    required this.people,
    required this.plannedCosts,
    required this.lines,
  });

  final String name;
  final int colorValue;

  /// "12–18 Oct", or null when it never had dates.
  final String? dates;
  final Money spent;
  final Money? budget;

  /// Planned costs not yet paid.
  final Money planned;
  final int days;
  final Money perDay;
  final int count;
  final List<({String name, int colorValue, Money amount})> categories;
  final List<({String name, Money amount})> accounts;

  /// Trip balances — `+` they owe you, `-` you owe them.
  final List<({String name, Money balance})> people;
  final List<({String name, Money amount, bool paid})> plannedCosts;

  /// Every transaction, newest first; [amount] signed from your side.
  final List<({DateTime date, String title, String detail, Money amount})>
  lines;
}
