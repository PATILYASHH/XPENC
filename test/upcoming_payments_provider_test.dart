import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// GitHub #94: the dashboard's Upcoming strip quoted an Auto rule's base
/// amount even while a promo was active, disagreeing with the Auto tab
/// (which already applied `_RuleTile._onPromo`) about what the next
/// occurrence actually costs.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<void> warmUp() async {
    await container.read(remindersProvider.future);
    await container.read(recurringRulesProvider.future);
  }

  test('an active promo quotes the promo amount, not the base amount', () async {
    final accountId = (await db.watchAccounts().first).single.id;
    final subscriptions = (await db.watchCategories(CategoryKind.expense).first)
        .first
        .id;

    await db.addRecurringRule(
      name: 'Streaming service',
      kind: CategoryKind.expense,
      amount: Money.fromRupees(11.99),
      accountId: accountId,
      categoryId: subscriptions,
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime.now().add(const Duration(days: 1)),
      promoAmount: const Money.zero(),
      promoOccurrences: 1,
    );

    await warmUp();
    final upcoming = container.read(upcomingPaymentsProvider(7));
    expect(upcoming, hasLength(1));
    expect(upcoming.single.amount, const Money.zero());
  });

  test('a rule with no promo quotes its base amount', () async {
    final accountId = (await db.watchAccounts().first).single.id;
    final subscriptions = (await db.watchCategories(CategoryKind.expense).first)
        .first
        .id;

    await db.addRecurringRule(
      name: 'Rent',
      kind: CategoryKind.expense,
      amount: Money.fromRupees(15000),
      accountId: accountId,
      categoryId: subscriptions,
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime.now().add(const Duration(days: 1)),
    );

    await warmUp();
    final upcoming = container.read(upcomingPaymentsProvider(7));
    expect(upcoming, hasLength(1));
    expect(upcoming.single.amount, Money.fromRupees(15000));
  });

  test('once a single-occurrence promo is used up, the next quote is the base amount', () async {
    final accountId = (await db.watchAccounts().first).single.id;
    final subscriptions = (await db.watchCategories(CategoryKind.expense).first)
        .first
        .id;

    final ruleId = await db.addRecurringRule(
      name: 'Streaming service',
      kind: CategoryKind.expense,
      amount: Money.fromRupees(11.99),
      accountId: accountId,
      categoryId: subscriptions,
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime.now().add(const Duration(days: 1)),
      promoAmount: const Money.zero(),
      promoOccurrences: 1,
    );

    // Consumes the one promo occurrence and clears promoAmount/
    // promoOccurrencesLeft together — see `_postRecurringOccurrence`.
    await db.payRecurringRuleNow(ruleId);

    await warmUp();
    final upcoming = container.read(upcomingPaymentsProvider(45));
    expect(upcoming, hasLength(1));
    expect(upcoming.single.amount, Money.fromRupees(11.99));
  });
}
