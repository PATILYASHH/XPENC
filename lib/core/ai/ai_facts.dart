import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/tables.dart';
import '../budget_cycle.dart';
import '../l10n/l10n.dart';
import '../money.dart';

/// One block of an [AiFactSheet], e.g. "This month".
class AiFactSection {
  const AiFactSection(this.title, this.lines);
  final String title;
  final List<String> lines;
}

/// Everything Local AI may know when it answers, worked out by XPENC itself
/// from the ledger — the same figures the app shows. The model only puts
/// these into words, and the sheet is shown under its answer ("Based on"),
/// so every number can be checked.
class AiFactSheet {
  const AiFactSheet(this.sections);
  final List<AiFactSection> sections;

  bool get isEmpty => sections.every((s) => s.lines.isEmpty);

  /// The sheet as the model reads it.
  String toPrompt() {
    final out = StringBuffer();
    for (final s in sections) {
      if (s.lines.isEmpty) continue;
      out.writeln('## ${s.title}');
      for (final line in s.lines) {
        out.writeln('- $line');
      }
    }
    return out.toString().trimRight();
  }
}

/// Builds the [AiFactSheet] for a question. Read-only: it never writes.
///
/// Always the month at a glance (this period against the last, the pace,
/// budgets, people, what's coming, money on hand, goals); plus detail for
/// any category, person or payee the question names.
class AiFacts {
  AiFacts(this.db, {required this.budgetStartDay, DateTime? now})
    : now = now ?? DateTime.now();

  final AppDatabase db;
  final int budgetStartDay;
  final DateTime now;

  static String _m(Money m) => MoneyFormat.symbol(m);
  static String _day(DateTime d) => DateFormat('d MMM').format(d);

  static String _pct(int now, int before) {
    if (before == 0) return '';
    final p = ((now - before) * 100 / before).round();
    return p >= 0 ? '+$p%' : '$p%';
  }

  Future<AiFactSheet> build(String question) async {
    final q = question.toLowerCase();
    final categories = {
      for (final c in await db.select(db.categories).get()) c.id: c,
    };
    String catName(int id) => categories[id]?.name ?? tr('Other');

    final thisPeriod = budgetPeriodFor(
      budgetPeriodAnchorFor(now, budgetStartDay),
      budgetStartDay,
    );
    final lastAnchor = DateTime(
      thisPeriod.start.year,
      thisPeriod.start.month,
      thisPeriod.start.day - 1,
    );
    final lastPeriod = budgetPeriodFor(
      budgetPeriodAnchorFor(lastAnchor, budgetStartDay),
      budgetStartDay,
    );
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final thisTotals = await db.reportTotals(thisPeriod.start, today);
    final lastTotals = await db.reportTotals(lastPeriod.start, lastPeriod.end);
    final elapsed = today.difference(thisPeriod.start);
    final lastToDate = await db.reportTotals(
      lastPeriod.start,
      lastPeriod.start.add(elapsed),
    );
    final yearTotals = await db.reportTotals(DateTime(now.year), today);
    final thisTxs = await db
        .watchTransactionsBetween(thisPeriod.start, today)
        .first;

    List<MapEntry<int, Money>> top(Map<int, Money> spend, int n) {
      final list = spend.entries.where((e) => e.value.isPositive).toList()
        ..sort((a, b) => b.value.paise.compareTo(a.value.paise));
      return list.take(n).toList();
    }

    final sections = <AiFactSection>[];

    // ── This period ──
    final left = thisTotals.income - thisTotals.expense;
    final month = <String>[
      tr('Dates: {0} to {1} (today is {2})', [
        _day(thisPeriod.start),
        _day(thisPeriod.end),
        _day(now),
      ]),
      tr('Money in {0}, money out {1}, left {2}', [
        _m(thisTotals.income),
        _m(thisTotals.expense),
        _m(left),
      ]),
      if (thisTotals.income.isPositive)
        tr('Saved {0}% of money in', [
          (left.paise * 100 / thisTotals.income.paise).round(),
        ]),
      for (final e in top(thisTotals.expenseByCategory, 5))
        tr('Spent on {0}: {1}', [catName(e.key), _m(e.value)]),
    ];
    final biggest = thisTxs.where((t) => t.type == TxType.expense).toList()
      ..sort((a, b) => b.amount.paise.compareTo(a.amount.paise));
    for (final t in biggest.take(3)) {
      final what = [
        if (t.payee != null && t.payee!.trim().isNotEmpty) t.payee!.trim(),
        if (t.categoryId != null) catName(t.categoryId!),
      ].join(', ');
      month.add(
        tr('Big spend: {0} on {1} ({2})', [
          _m(t.amount),
          _day(t.date),
          what.isEmpty ? tr('no category') : what,
        ]),
      );
    }
    sections.add(AiFactSection(tr('This month'), month));

    // ── Last period, and how this one compares ──
    sections.add(
      AiFactSection(tr('Last month'), [
        tr('Money in {0}, money out {1}', [
          _m(lastTotals.income),
          _m(lastTotals.expense),
        ]),
        for (final e in top(lastTotals.expenseByCategory, 5))
          tr('Spent on {0}: {1}', [catName(e.key), _m(e.value)]),
      ]),
    );

    final changes = <String>[
      tr('By this day last month money out was {0}; this month it is {1} {2}', [
        _m(lastToDate.expense),
        _m(thisTotals.expense),
        _pct(thisTotals.expense.paise, lastToDate.expense.paise),
      ]).trim(),
    ];
    final delta = <int, int>{};
    for (final id in {
      ...thisTotals.expenseByCategory.keys,
      ...lastToDate.expenseByCategory.keys,
    }) {
      delta[id] =
          (thisTotals.expenseByCategory[id]?.paise ?? 0) -
          (lastToDate.expenseByCategory[id]?.paise ?? 0);
    }
    final ups = delta.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final downs = delta.entries.where((e) => e.value < 0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final e in ups.take(3)) {
      changes.add(
        tr('{0} up {1} against the same days last month', [
          catName(e.key),
          _m(Money.fromPaise(e.value)),
        ]),
      );
    }
    for (final e in downs.take(2)) {
      changes.add(
        tr('{0} down {1} against the same days last month', [
          catName(e.key),
          _m(Money.fromPaise(-e.value)),
        ]),
      );
    }
    sections.add(AiFactSection(tr('Compared with last month'), changes));

    sections.add(
      AiFactSection(tr('This year'), [
        tr('Money in {0}, money out {1}', [
          _m(yearTotals.income),
          _m(yearTotals.expense),
        ]),
      ]),
    );

    // ── Budgets, this period (base amounts; rollover not included) ──
    final budgets = await db.select(db.budgets).get();
    final budgetLines = <(double, String)>[];
    for (final b in budgets) {
      final cat = categories[b.categoryId];
      // Weekly and yearly budgets measure a different stretch of time than
      // the month these figures cover; leaving them out beats a wrong %.
      if (cat == null || b.amount.isZero) continue;
      if (b.period != BudgetPeriod.monthly) continue;
      var spent =
          thisTotals.expenseByCategory[b.categoryId] ?? const Money.zero();
      for (final c in categories.values) {
        if (c.parentId == b.categoryId) {
          spent += thisTotals.expenseByCategory[c.id] ?? const Money.zero();
        }
      }
      final fraction = spent.paise / b.amount.paise;
      final status = fraction > 1
          ? tr('over by {0}', [_m(spent - b.amount)])
          : tr('{0} left', [_m(b.amount - spent)]);
      budgetLines.add((
        fraction,
        tr('{0}: {1} of {2} ({3}%), {4}', [
          cat.name,
          _m(spent),
          _m(b.amount),
          (fraction * 100).round(),
          status,
        ]),
      ));
    }
    budgetLines.sort((a, b) => b.$1.compareTo(a.$1));
    sections.add(
      AiFactSection(tr('Budgets this month'), [
        for (final l in budgetLines.take(6)) l.$2,
      ]),
    );

    // ── People ──
    final persons = {
      for (final p in await db.select(db.persons).get())
        if (!p.isArchived) p.id: p,
    };
    final balances = await db.watchAllPersonBalances().first;
    final owed =
        balances.entries
            .where((e) => persons.containsKey(e.key) && !e.value.isZero)
            .toList()
          ..sort((a, b) => b.value.abs.paise.compareTo(a.value.abs.paise));
    var youGet = const Money.zero();
    var youPay = const Money.zero();
    for (final e in owed) {
      if (e.value.isPositive) {
        youGet += e.value;
      } else {
        youPay += e.value.abs;
      }
    }
    String personLine(PersonRow p, Money b) => b.isPositive
        ? tr('{0} owes you {1}', [p.name, _m(b)])
        : tr('You owe {0} {1}', [p.name, _m(b.abs)]);
    final named = {
      for (final p in persons.values)
        if (p.name.length >= 3 && q.contains(p.name.toLowerCase())) p.id,
    };
    sections.add(
      AiFactSection(tr('People'), [
        if (owed.isNotEmpty)
          tr('Others owe you {0} in total; you owe {1}', [
            _m(youGet),
            _m(youPay),
          ]),
        for (final e in owed.take(5)) personLine(persons[e.key]!, e.value),
        for (final id in named)
          if (!owed.take(5).any((e) => e.key == id))
            balances[id] == null || balances[id]!.isZero
                ? tr('{0} and you are settled', [persons[id]!.name])
                : personLine(persons[id]!, balances[id]!),
      ]),
    );

    // ── Coming up ──
    final horizon = today.add(const Duration(days: 14));
    final upcoming = <(DateTime, String)>[];
    for (final r in await db.select(db.reminders).get()) {
      if (r.status != ReminderStatus.open || r.dueDate.isAfter(horizon)) {
        continue;
      }
      upcoming.add((
        r.dueDate,
        tr('{0}: {1}{2} ({3})', [
          _day(r.dueDate),
          r.title,
          r.amount == null ? '' : ' ${_m(r.amount!)}',
          r.direction == ReminderDirection.pay ? tr('to pay') : tr('to get'),
        ]),
      ));
    }
    for (final r in await db.select(db.recurringRules).get()) {
      if (!r.isActive || r.nextDueDate.isAfter(horizon)) continue;
      upcoming.add((
        r.nextDueDate,
        tr('{0}: {1} {2} (Auto)', [_day(r.nextDueDate), r.name, _m(r.amount)]),
      ));
    }
    upcoming.sort((a, b) => a.$1.compareTo(b.$1));
    sections.add(
      AiFactSection(tr('Next 14 days'), [
        for (final u in upcoming.take(8)) u.$2,
      ]),
    );

    // ── Money on hand, goals, loans ──
    final accounts = await db.watchAccounts().first;
    final accountById = {for (final a in accounts) a.id: a};
    final total = await db.watchNetWorth().first;
    final everyday = accounts
        .where((a) => a.type != AccountType.goal && a.type != AccountType.loan)
        .toList();
    sections.add(
      AiFactSection(tr('Accounts'), [
        tr('Total money {0}', [_m(total)]),
        for (final a in everyday.take(8))
          tr('{0}: {1}', [a.name, _m(a.currentBalance)]),
      ]),
    );
    final goalLines = <String>[];
    for (final g in await db.select(db.goalDetails).get()) {
      final a = accountById[g.accountId];
      if (a == null) continue;
      final pct = g.targetAmount.isZero
          ? 0
          : (a.currentBalance.paise * 100 / g.targetAmount.paise).round();
      goalLines.add(
        tr('Goal {0}: {1} of {2} ({3}%)', [
          a.name,
          _m(a.currentBalance),
          _m(g.targetAmount),
          pct,
        ]),
      );
    }
    for (final l in await db.select(db.loanDetails).get()) {
      final a = accountById[l.accountId];
      if (a == null) continue;
      final left = a.currentBalance.isNegative
          ? a.currentBalance.abs
          : const Money.zero();
      goalLines.add(tr('Loan {0}: {1} left to pay', [a.name, _m(left)]));
    }
    sections.add(AiFactSection(tr('Goals and loans'), goalLines));

    // ── What the question names ──
    final detail = <String>[];
    for (final c in categories.values) {
      if (c.isArchived || c.name.length < 3) continue;
      if (!q.contains(c.name.toLowerCase())) continue;
      final txs = thisTxs.where((t) => t.categoryId == c.id).toList();
      detail.add(
        tr('{0}: {1} this month over {2} entries, {3} last month', [
          c.name,
          _m(thisTotals.expenseByCategory[c.id] ?? const Money.zero()),
          txs.length,
          _m(lastTotals.expenseByCategory[c.id] ?? const Money.zero()),
        ]),
      );
    }
    final payees = <String, List<TransactionRow>>{};
    for (final t
        in await db.watchTransactionsBetween(lastPeriod.start, today).first) {
      final p = t.payee?.trim();
      if (p == null || p.length < 3 || !q.contains(p.toLowerCase())) continue;
      (payees[p] ??= []).add(t);
    }
    for (final e in payees.entries.take(3)) {
      var sum = const Money.zero();
      for (final t in e.value) {
        if (t.type == TxType.expense) sum += t.amount;
      }
      detail.add(
        tr('{0}: {1} spent over {2} entries since {3}', [
          e.key,
          _m(sum),
          e.value.length,
          _day(lastPeriod.start),
        ]),
      );
    }
    if (detail.isNotEmpty) {
      sections.add(AiFactSection(tr('About your question'), detail));
    }

    return AiFactSheet(sections);
  }
}
