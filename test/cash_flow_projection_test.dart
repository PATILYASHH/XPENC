import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/reports/cash_flow_projection.dart';

/// #177: Stats > Cash flow carries money on hand forward by auto rules on
/// their real dates, plus the usual month of everything else.
void main() {
  late AppDatabase db;
  late int cash;
  late int salary;
  late int food;
  final today = DateTime(2026, 10, 25);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    cash = (await db.watchAccounts().first).single.id;
    salary = (await db.watchCategories(CategoryKind.income).first).first.id;
    food = (await db.watchCategories(CategoryKind.expense).first).first.id;
  });
  tearDown(() => db.close());

  Future<CashFlowProjection> project({
    int months = 3,
    Map<int, ({Money outstanding, double? ratePct})> loans = const {},
  }) async => projectCashFlow(
    today: today,
    months: months,
    accounts: await db.select(db.accounts).get(),
    rules: await db.select(db.recurringRules).get(),
    transactions: await db.select(db.transactions).get(),
    loans: loans,
    rates: const {},
  );

  Future<int> rule(
    String name, {
    required int rupees,
    required RecurringFrequency frequency,
    required DateTime startsOn,
    CategoryKind kind = CategoryKind.expense,
    int? accountId,
    int? toAccountId,
    int? promoRupees,
    int? promoOccurrences,
  }) => db.addRecurringRule(
    name: name,
    kind: kind,
    amount: Money.fromRupees(rupees),
    accountId: accountId ?? cash,
    categoryId: toAccountId != null
        ? null
        : kind == CategoryKind.income
        ? salary
        : food,
    toAccountId: toAccountId,
    frequency: frequency,
    startsOn: startsOn,
    promoAmount: promoRupees == null ? null : Money.fromRupees(promoRupees),
    promoOccurrences: promoOccurrences,
  );

  List<int> rupeesOf(Iterable<Money> m) => [for (final v in m) v.paise ~/ 100];

  test('the issue: ₹1,000 a week in, minus the expense rules', () async {
    await rule(
      'Wages',
      kind: CategoryKind.income,
      rupees: 1000,
      frequency: RecurringFrequency.weekly,
      startsOn: DateTime(2026, 10, 26),
    );
    await rule(
      'Rent',
      rupees: 300,
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime(2026, 11, 1),
    );

    final p = await project();

    // Wages: 5 by 25 Nov, 9 by 25 Dec, 14 by 25 Jan. Rent: one a month.
    expect(rupeesOf(p.steps.map((s) => s.value)), [0, 4700, 8400, 13100]);
    expect(rupeesOf(p.steps.map((s) => s.rules)), [0, 4700, 3700, 4700]);
    expect(p.steps.map((s) => s.date), [
      DateTime(2026, 10, 25),
      DateTime(2026, 11, 25),
      DateTime(2026, 12, 25),
      DateTime(2027, 1, 25),
    ]);
    expect(p.ruleCount, 2);
    expect(p.usualMonthly, isNull, reason: 'no full month recorded');
  });

  test('usual money averages whole months only, and never a rule\'s own '
      'entries', () async {
    Future<void> spend(DateTime date, int rupees, {int? ruleId}) =>
        db.addTransaction(
          type: TxType.expense,
          amount: Money.fromRupees(rupees),
          accountId: cash,
          categoryId: food,
          date: date,
          recurringRuleId: ruleId,
        );
    // The ledger starts mid-August, so August isn't a whole month.
    await spend(DateTime(2026, 8, 10), 999);
    await spend(DateTime(2026, 9, 3), 3000);
    await db.addTransaction(
      type: TxType.income,
      amount: Money.fromRupees(1000),
      accountId: cash,
      categoryId: salary,
      date: DateTime(2026, 9, 20),
    );
    // Posted by a rule — the rule already projects it.
    final gym = await rule(
      'Gym',
      rupees: 5000,
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime(2027, 6, 1),
    );
    await spend(DateTime(2026, 9, 1), 5000, ruleId: gym);
    // This month isn't over, so it doesn't count either.
    await spend(DateTime(2026, 10, 5), 400);

    final p = await project();

    expect(p.usualMonths, 1);
    expect(p.usualMonthly, Money.fromRupees(-2000));
    // 92 days to 25 Jan, at ₹2,000 a month.
    expect((p.end - p.start).paise, closeTo(-200000 * 12 / 365 * 92, 1));
    expect(p.steps.last.usual, isNot(const Money.zero()));
  });

  test('money on hand: a card expense lowers it, paying the card is '
      'neutral, a SIP into a goal lowers it', () async {
    final card = await db.addAccount(
      name: 'Card',
      type: AccountType.card,
      cardKind: CardKind.credit,
      colorValue: 0,
      iconKey: 'card',
      openingBalance: const Money.zero(),
    );
    final goal = await db.addGoal(
      name: 'Bike',
      targetAmount: Money.fromRupees(50000),
      colorValue: 0,
      iconKey: 'goal',
    );
    await rule(
      'Netflix',
      rupees: 500,
      accountId: card,
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime(2026, 11, 1),
    );
    await rule(
      'Card bill',
      rupees: 500,
      toAccountId: card,
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime(2026, 11, 5),
    );
    await rule(
      'SIP',
      rupees: 2000,
      toAccountId: goal,
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime(2026, 11, 10),
    );

    final p = await project(months: 1);

    expect(p.end - p.start, Money.fromRupees(-2500));
    expect(p.ruleCount, 2, reason: 'the card bill moves nothing on hand');
  });

  test('a debit card rule draws on its bank', () async {
    final bank = await db.addAccount(
      name: 'Bank',
      type: AccountType.bank,
      colorValue: 0,
      iconKey: 'bank',
      openingBalance: Money.fromRupees(10000),
    );
    final debit = await db.addAccount(
      name: 'Debit',
      type: AccountType.card,
      cardKind: CardKind.debit,
      linkedAccountId: bank,
      colorValue: 0,
      iconKey: 'card',
      openingBalance: const Money.zero(),
    );
    await rule(
      'Phone',
      rupees: 700,
      accountId: debit,
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime(2026, 11, 1),
    );

    final p = await project(months: 1);

    expect(p.start, Money.fromRupees(10000));
    expect(p.end, Money.fromRupees(9300));
  });

  test('an EMI stops once its loan is paid off', () async {
    final loan = await db.addLoan(
      name: 'Phone loan',
      principal: Money.fromRupees(2500),
      colorValue: 0,
      iconKey: 'loan',
    );
    await rule(
      'EMI',
      rupees: 1000,
      toAccountId: loan,
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime(2026, 11, 1),
    );

    final p = await project(
      months: 6,
      loans: {loan: (outstanding: Money.fromRupees(2500), ratePct: null)},
    );

    expect(rupeesOf(p.steps.map((s) => s.rules)), [
      0,
      -1000,
      -1000,
      -500,
      0,
      0,
      0,
    ]);
  });

  test('a promo price runs its course, then the full price', () async {
    await rule(
      'Music',
      rupees: 500,
      promoRupees: 100,
      promoOccurrences: 2,
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime(2026, 11, 1),
    );

    final p = await project(months: 4);

    expect(rupeesOf(p.steps.map((s) => s.rules)), [0, -100, -100, -500, -500]);
  });

  test('the lowest point is the dip before payday, not a checkpoint', () async {
    await rule(
      'Rent',
      rupees: 5000,
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime(2026, 11, 1),
    );
    await rule(
      'Salary',
      kind: CategoryKind.income,
      rupees: 6000,
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime(2026, 11, 5),
    );

    final p = await project(months: 1);

    expect(p.lowest.value, Money.fromRupees(-5000));
    expect(p.lowest.date, DateTime(2026, 11, 1));
    expect(p.end, Money.fromRupees(1000));
  });

  test('a paused rule projects nothing', () async {
    final id = await rule(
      'Old gym',
      rupees: 900,
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime(2026, 11, 1),
    );
    await (db.update(db.recurringRules)..where((r) => r.id.equals(id))).write(
      const RecurringRulesCompanion(isActive: Value(false)),
    );

    final p = await project();

    expect(p.ruleCount, 0);
    expect(p.end, p.start);
  });

  test('the provider wires loans in from the ledger', () async {
    final loan = await db.addLoan(
      name: 'Phone loan',
      principal: Money.fromRupees(1500),
      colorValue: 0,
      iconKey: 'loan',
    );
    await rule(
      'EMI',
      rupees: 1000,
      toAccountId: loan,
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime.now().add(const Duration(days: 1)),
    );
    final c = ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    await c.read(accountsProvider.future);
    await c.read(recurringRulesProvider.future);
    await c.read(allTransactionsProvider.future);
    await c.read(loanDetailsProvider.future);
    await c.read(currencyRatesProvider.future);
    c.read(cashFlowHorizonProvider.notifier).state = 12;

    final p = c.read(cashFlowProjectionProvider);

    expect(p.steps, hasLength(13));
    expect(p.end - p.start, Money.fromRupees(-1500));
  });
}
