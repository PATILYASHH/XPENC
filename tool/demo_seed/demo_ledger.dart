// A realistic demo ledger for screenshots — the website's, and the iOS
// listing's (integration_test/ios_screenshots_test.dart). demo_seed_test.dart
// writes it to a SQLite file for the Android emulator.
//
// Everything goes through AppDatabase's own write APIs, so balances, person
// ledgers, goal and loan accounts come out exactly the way the app itself
// would create them. Deterministic: the same `now` always produces the same
// ledger.

import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// When the website's screenshots were taken. The ledger is three months
/// ending at `now` — the two before it and its own month up to `now` — so
/// this default reproduces that ledger exactly.
final demoLedgerNow = DateTime(2026, 9, 30, 23, 59);

Money _rs(num v) => Money.fromRupees(v);

/// Seeds the demo ledger into a fresh [db]: accounts, goals, a loan, three
/// months of transactions ending at [now], people and a group, budgets, and
/// future-dated recurring rules and reminders. [theme] is a
/// `Settings.themeName`.
Future<void> seedDemoLedger(
  AppDatabase db, {
  required String theme,
  DateTime? now,
}) async {
  final today = now ?? demoLedgerNow;
  final rnd = Random(20260930);

  // [month] months after [today]'s month (negative: before it), on [day],
  // clamped to that month's length. Nothing in the past — every month up to
  // and including [today]'s — lands after [today], so nothing reads as
  // scheduled for later: in [today]'s month the days are squeezed into the
  // days so far, and on [today] itself the hours into the hours so far, both
  // in proportion, so the ledger keeps its rhythm instead of piling up on
  // one moment. With the default [demoLedgerNow] nothing moves.
  DateTime at(int month, int day, [int hour = 13, int minute = 0]) {
    final first = DateTime(today.year, today.month + month);
    final last = DateTime(first.year, first.month + 1, 0).day;
    var d = min(day, last);
    if (month == 0 && d > today.day) d = (d * today.day / last).ceil();
    var date = DateTime(first.year, first.month, d, hour, minute);
    if (month <= 0 && date.isAfter(today)) {
      final sofar = today.hour * 60 + today.minute;
      final minutes = (hour * 60 + minute) * sofar ~/ (24 * 60);
      date = DateTime(first.year, first.month, d, minutes ~/ 60, minutes % 60);
      if (date.isAfter(today)) date = today.subtract(const Duration(minutes: 1));
    }
    return date;
  }

  // A date with no time of day, for due dates, targets and start dates.
  DateTime on(int month, int day) {
    final d = at(month, day);
    return DateTime(d.year, d.month, d.day);
  }

  // A fresh AppDatabase seeds settings, one Cash account and the default
  // categories. Make it look like a set-up, onboarded install.
  await db.markOnboarded();
  await db.setCurrencyCode('INR');
  await db.setThemeName(theme);
  await db.setAppMode(AppMode.pro);
  // So a person's Request / Pay buttons show as usable.
  await db.update(db.settings).write(
    const SettingsCompanion(
      myUpiId: Value('aarav.sharma@okbank'),
      myUpiName: Value('Aarav Sharma'),
    ),
  );

  final accs = await db.select(db.accounts).get();
  final cash = accs.firstWhere((a) => a.type == AccountType.cash).id;

  Future<int> cat(String name, CategoryKind kind) async {
    final all = await db.select(db.categories).get();
    return all.firstWhere((c) => c.name == name && c.kind == kind).id;
  }

  final exp = CategoryKind.expense, inc = CategoryKind.income;
  final salary = await cat('Salary', inc);
  final interest = await cat('Interest', inc);
  final refund = await cat('Refund', inc);
  final rent = await cat('Rent', exp);
  final food = await cat('Food', exp);
  final groceries = await cat('Groceries', exp);
  final transport = await cat('Transport', exp);
  final bills = await cat('Bills', exp);
  final shopping = await cat('Shopping', exp);
  final health = await cat('Health', exp);
  final entertainment = await cat('Entertainment', exp);
  final emi = await cat('EMI', exp);
  final freelance = await db.addCategory(
    name: 'Freelance', kind: inc, colorValue: 0xFF6366F1, iconKey: 'laptop');
  final fuel = await db.addCategory(
    name: 'Fuel', kind: exp, colorValue: 0xFFEAB308, iconKey: 'fuel');
  final subs = await db.addCategory(
    name: 'Subscriptions', kind: exp, colorValue: 0xFFE11D48, iconKey: 'streaming');
  final coffee = await db.addCategory(
    name: 'Coffee', kind: exp, colorValue: 0xFF92400E, iconKey: 'coffee');
  final travel = await db.addCategory(
    name: 'Travel', kind: exp, colorValue: 0xFF0EA5E9, iconKey: 'travel');
  final fitness = await db.addCategory(
    name: 'Fitness', kind: exp, colorValue: 0xFF10B981, iconKey: 'fitness');

  // ── Accounts ──────────────────────────────────────────────────────────────
  await (db.update(db.accounts)..where((a) => a.id.equals(cash))).write(
    AccountsCompanion(openingBalance: Value(_rs(2800))),
  );
  final hdfc = await db.addAccount(
    name: 'HDFC Salary', type: AccountType.bank, bankName: 'HDFC Bank',
    last4: '4821', colorValue: 0xFF1D4ED8, iconKey: 'bank',
    openingBalance: _rs(68450));
  final sbi = await db.addAccount(
    name: 'SBI Savings', type: AccountType.bank, bankName: 'State Bank of India',
    last4: '0937', colorValue: 0xFF0891B2, iconKey: 'bank',
    openingBalance: _rs(196500));
  await db.addAccount(
    name: 'HDFC Debit', type: AccountType.card, cardKind: CardKind.debit,
    linkedAccountId: hdfc, last4: '4821', colorValue: 0xFF1D4ED8,
    iconKey: 'card', openingBalance: const Money.zero());
  final card = await db.addAccount(
    name: 'ICICI Credit Card', type: AccountType.card, cardKind: CardKind.credit,
    bankName: 'ICICI Bank', last4: '7730', colorValue: 0xFFEA580C,
    iconKey: 'card', openingBalance: _rs(-6240));
  await db.upsertCreditCardDetails(accountId: card, statementDay: 18, dueDay: 5);
  final wallet = await db.addAccount(
    name: 'Paytm Wallet', type: AccountType.prepaidBalance,
    colorValue: 0xFF0EA5E9, iconKey: 'prepaid_balance', openingBalance: _rs(650));

  // Goals & loan (the app makes the backing accounts itself).
  final goa = await db.addGoal(
    name: 'Goa Trip', targetAmount: _rs(45000), targetDate: on(3, 20),
    colorValue: 0xFFF97316, iconKey: 'beach');
  final emergency = await db.addGoal(
    name: 'Emergency Fund', targetAmount: _rs(300000),
    colorValue: 0xFF16A34A, iconKey: 'savings');
  final mac = await db.addGoal(
    name: 'New MacBook', targetAmount: _rs(140000), targetDate: on(6, 31),
    colorValue: 0xFF64748B, iconKey: 'laptop');
  await db.correctGoalOpeningBalance(accountId: emergency, openingBalance: _rs(208000));
  await db.correctGoalOpeningBalance(accountId: goa, openingBalance: _rs(12000));
  await db.correctGoalOpeningBalance(accountId: mac, openingBalance: _rs(31000));
  await db.addLoan(
    name: 'Car Loan', principal: _rs(418000), colorValue: 0xFF7C3AED,
    iconKey: 'car', categoryId: emi, interestRatePct: 9.1, tenureMonths: 60,
    startDate: on(-10, 5), autoPayFromAccountId: hdfc,
    autoPayStartsOn: on(1, 5));

  // ── Tags ──────────────────────────────────────────────────────────────────
  final tWork = await db.addTag(name: 'Work', colorValue: 0xFF2563EB);
  final tWeekend = await db.addTag(name: 'Weekend', colorValue: 0xFFF97316);
  final tTrip = await db.addTag(name: 'Lonavala Trip', colorValue: 0xFF0EA5E9);
  final tReimb = await db.addTag(name: 'Reimbursable', colorValue: 0xFF16A34A);

  Future<int> tx(
    TxType type,
    num rupees,
    int account,
    DateTime date, {
    int? category,
    int? to,
    String? note,
    String? payee,
    Set<int> tags = const {},
  }) async {
    final id = await db.addTransaction(
      type: type, amount: _rs(rupees), accountId: account, toAccountId: to,
      categoryId: category, date: date, note: note, payee: payee);
    if (tags.isNotEmpty) await db.setTransactionTags(id, tags);
    return id;
  }

  Future<void> spend(int category, num rupees, int account, DateTime date,
          {String? note, String? payee, Set<int> tags = const {}}) =>
      tx(TxType.expense, rupees, account, date,
          category: category, note: note, payee: payee, tags: tags);

  int pick(List<int> xs) => xs[rnd.nextInt(xs.length)];
  num around(num base, num spread) =>
      (base + (rnd.nextDouble() * 2 - 1) * spread).roundToDouble();
  bool isWeekend(DateTime d) =>
      d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

  // ── Three months of real-looking life ─────────────────────────────────────
  for (final m in [-2, -1, 0]) {
    final first = on(m, 1);
    final lastDay =
        m == 0 ? today.day : DateTime(first.year, first.month + 1, 0).day;

    await tx(TxType.income, 118500, hdfc, at(m, 1, 9, 20),
        category: salary, payee: 'Nimbus Labs Pvt Ltd', note: 'Salary');
    await tx(TxType.transfer, 10000, hdfc, at(m, 2, 10), to: emergency,
        note: 'Monthly saving');
    await tx(TxType.transfer, m == 0 ? 8000 : 6000, hdfc, at(m, 2, 10, 5),
        to: goa, note: 'Goa fund');
    await tx(TxType.transfer, 5000, hdfc, at(m, 2, 10, 10), to: mac);
    await spend(rent, 24000, hdfc, at(m, 3, 11), payee: 'Mr. Kulkarni',
        note: 'Flat rent');
    await tx(TxType.transfer, {-2: 18400, -1: 19600, 0: 24300}[m]!, hdfc,
        at(m, 5, 19), to: card, note: 'Credit card bill');
    await tx(TxType.transfer, 3000, hdfc, at(m, 6, 18, 40), to: cash,
        note: 'ATM withdrawal');
    await tx(TxType.transfer, 2000, hdfc, at(m, 20, 18, 10), to: cash,
        note: 'ATM withdrawal');
    await tx(TxType.transfer, 3000, hdfc, at(m, 8, 12), to: wallet,
        note: 'Wallet top-up');
    await tx(TxType.transfer, 3000, hdfc, at(m, 21, 12), to: wallet,
        note: 'Wallet top-up');
    await spend(bills, around(1480, 220), hdfc, at(m, 9, 20),
        payee: 'MSEDCL', note: 'Electricity');
    await spend(bills, 799, hdfc, at(m, 10, 9), payee: 'FiberNet', note: 'Broadband');
    await spend(bills, 399, wallet, at(m, 11, 21), note: 'Mobile recharge');
    await spend(subs, 649, card, at(m, 12, 8), payee: 'Streamflix');
    await spend(subs, 119, card, at(m, 14, 8), payee: 'Tunes Premium');
    await spend(fitness, 1800, hdfc, at(m, 7, 7, 30), payee: 'IronHouse Gym');

    for (var d = 1; d <= lastDay; d++) {
      final date = on(m, d);
      final we = isWeekend(date);
      if (d % 6 == 2 || (we && d % 2 == 0)) {
        await spend(groceries, around(we ? 2100 : 1150, 450), pick([card, hdfc]),
            at(m, d, 18, 30), payee: 'Fresh Mart', note: we ? 'Weekly groceries' : null,
            tags: we ? {tWeekend} : const {});
      }
      if (rnd.nextDouble() < (we ? 0.75 : 0.35)) {
        await spend(food, around(we ? 820 : 360, we ? 280 : 140), pick([card, card, cash, wallet]),
            at(m, d, we ? 20 : 13, 30),
            payee: pick([0, 1, 2, 3]) == 0 ? 'Corner Café' : null,
            note: we ? 'Dinner out' : 'Lunch',
            tags: we ? {tWeekend} : const {});
      }
      if (!we && rnd.nextDouble() < 0.45) {
        await spend(coffee, around(210, 50), cash, at(m, d, 10, 15), note: 'Coffee');
      }
      if (!we && rnd.nextDouble() < 0.4) {
        await spend(transport, around(260, 110), wallet, at(m, d, 9, 5),
            payee: 'City Cabs', note: 'Cab to office', tags: {tWork});
      }
      if (d == 4 || d == 19) {
        await spend(fuel, around(1900, 250), card, at(m, d, 8, 40), payee: 'HP Petrol Pump');
      }
    }

    // A few bigger, one-off purchases per month.
    await spend(shopping, around(2200, 700), card, at(m, 13, 17),
        payee: 'UrbanWear', note: 'Clothes');
    await spend(shopping, around(1400, 500), card, at(m, 22, 16), note: 'Home essentials');
    await spend(entertainment, around(780, 150), card, at(m, 16, 21), note: 'Movie night',
        tags: {tWeekend});
    await spend(health, around(420, 140), cash, at(m, 17, 19), payee: 'Wellness Pharmacy');
  }

  // Month-specific moments.
  await tx(TxType.income, 18000, sbi, at(-1, 21, 11), category: freelance,
      payee: 'Studio Kite', note: 'Landing page design');
  await tx(TxType.income, 26500, sbi, at(0, 24, 15), category: freelance,
      payee: 'Studio Kite', note: 'App UI redesign');
  await tx(TxType.income, 342, sbi, at(0, 30, 9), category: interest,
      note: 'Quarterly interest');
  await tx(TxType.income, 1299, card, at(0, 18, 12), category: refund,
      payee: 'UrbanWear', note: 'Returned jacket');
  await spend(travel, 6400, card, at(-1, 15, 14), payee: 'Hilltop Resort',
      note: 'Lonavala stay, 2 nights', tags: {tTrip, tWeekend});
  await spend(travel, 1280, hdfc, at(-1, 15, 7, 30), note: 'Train tickets',
      tags: {tTrip});
  await spend(food, 2150, card, at(-1, 16, 20), note: 'Lonavala dinner',
      tags: {tTrip, tWeekend});
  await spend(shopping, 4899, card, at(0, 26, 18), payee: 'GadgetHub',
      note: 'Noise-cancelling headphones');
  await spend(transport, 1850, card, at(0, 11, 9), note: 'Client visit cab',
      tags: {tWork, tReimb});
  await spend(health, 1200, hdfc, at(0, 20, 11), note: 'Dentist');

  // ── People & dues ─────────────────────────────────────────────────────────
  final rohan = await db.addPerson('Rohan Mehta', upiId: 'rohan.m@okbank', phone: '98200 11223');
  final priya = await db.addPerson('Priya Nair', upiId: 'priyanair@okbank');
  final kabir = await db.addPerson('Kabir Singh');
  final ananya = await db.addPerson('Ananya Iyer');
  await db.addPersonEntry(personId: rohan, direction: PersonDirection.theyOwe,
      amount: _rs(5000), date: at(-1, 12), accountId: hdfc, note: 'Bike repair');
  await db.addPersonEntry(personId: rohan, direction: PersonDirection.iOwe,
      amount: _rs(2000), date: at(0, 5), accountId: hdfc, note: 'Paid back part');
  await db.addPersonEntry(personId: priya, direction: PersonDirection.iOwe,
      amount: _rs(6500), date: at(0, 14), accountId: cash, note: 'Flight tickets',
      dueDate: on(1, 10));
  await db.addPersonEntry(personId: ananya, direction: PersonDirection.theyOwe,
      amount: _rs(1200), date: at(0, 22), accountId: wallet, note: 'Cab share');

  final squad = await db.addGroup('Goa Squad', note: 'December trip');
  await db.setGroupMembers(squad, {rohan, priya, kabir});
  await db.addGroupExpense(groupId: squad, amount: _rs(18000),
      splitMethod: GroupSplitMethod.equal, date: at(0, 8, 21),
      note: 'Villa booking advance', accountId: hdfc, categoryId: travel,
      participantIds: {null, rohan, priya, kabir});
  await db.addGroupExpense(groupId: squad, amount: _rs(3600),
      splitMethod: GroupSplitMethod.equal, date: at(0, 21, 20),
      note: 'Planning dinner', payerId: kabir, categoryId: food,
      participantIds: {null, rohan, priya, kabir});

  // ── Budgets ───────────────────────────────────────────────────────────────
  for (final (c, amt) in [
    (food, 9000), (groceries, 12500), (transport, 4500), (shopping, 7500),
    (entertainment, 2000), (bills, 3500), (fuel, 4500), (coffee, 3500),
    (subs, 1000),
  ]) {
    await db.upsertBudget(categoryId: c, amount: _rs(amt));
  }

  // ── Recurring rules & reminders (future-dated so nothing auto-posts) ─────
  await db.addRecurringRule(name: 'Salary', kind: inc, amount: _rs(118500),
      accountId: hdfc, categoryId: salary, payee: 'Nimbus Labs Pvt Ltd',
      frequency: RecurringFrequency.monthly, startsOn: on(1, 1));
  await db.addRecurringRule(name: 'Flat rent', kind: exp, amount: _rs(24000),
      accountId: hdfc, categoryId: rent, payee: 'Mr. Kulkarni',
      frequency: RecurringFrequency.monthly, startsOn: on(1, 3));
  await db.addRecurringRule(name: 'Streamflix', kind: exp, amount: _rs(649),
      accountId: card, categoryId: subs, payee: 'Streamflix',
      frequency: RecurringFrequency.monthly, startsOn: on(1, 12));
  await db.addRecurringRule(name: 'Gym membership', kind: exp, amount: _rs(1800),
      accountId: hdfc, categoryId: fitness, payee: 'IronHouse Gym',
      frequency: RecurringFrequency.monthly, startsOn: on(1, 7));
  await db.addReminder(title: 'Health insurance premium', amount: _rs(12400),
      direction: ReminderDirection.pay, dueDate: on(1, 15),
      accountId: hdfc, notifyDaysBefore: 3, repeat: ReminderRepeat.yearly);
  await db.addReminder(title: 'Pay Priya back', amount: _rs(2000),
      direction: ReminderDirection.pay, dueDate: on(1, 10),
      personId: priya);

  // ── Shopping list ─────────────────────────────────────────────────────────
  final list = await db.addShoppingList(name: 'Weekend groceries', colorValue: 0xFF16A34A);
  for (final (name, amt) in [
    ('Basmati rice 5 kg', 620), ('Toor dal 1 kg', 165), ('Paneer 400 g', 180),
    ('Olive oil', 540), ('Bananas', 60), ('Greek yogurt', 140),
  ]) {
    await db.addShoppingItem(listId: list, name: name, estimatedAmount: _rs(amt));
  }

  await db.recalculateBalances();
}
