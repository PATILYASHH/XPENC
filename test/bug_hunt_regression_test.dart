import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/message_capture/parser/bank_message.dart';
import 'package:xpenc/features/message_capture/parser/message_parser.dart';

/// One test per defect found by the adversarial audit. Each fails on the old
/// code and passes on the fixed code.
void main() {
  late AppDatabase db;
  const parser = MessageParser();

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;
  Future<int> catId(CategoryKind k, String name) async =>
      (await db.watchCategories(k).first).firstWhere((c) => c.name == name).id;

  Future<int?> ingest(String body,
      {String sender = 'AD-IPPBNK', DateTime? at}) async {
    final m = RawMessage(
      body: body,
      sender: sender,
      receivedAt: at ?? DateTime(2026, 7, 9, 10, 0),
    );
    final r = parser.parse(m);
    if (r is! ParsedMessage) return null;
    return db.ingestMessage(m, r);
  }

  group('Auto-Approve must never fire from a near-miss merchant', () {
    test('a rule for "OLA" does not match "GOLA SNACKS"', () async {
      await db.upsertMerchantRule(
        pattern: 'OLA',
        categoryId: await catId(CategoryKind.expense, 'Transport'),
      );

      expect(await db.findMerchantRule('GOLA SNACKS'), isNull,
          reason: 'substring matching would auto-book an unrelated purchase');
      expect(await db.findMerchantRule('OLA'), isNotNull);
    });

    test('exact match is case- and whitespace-insensitive', () async {
      await db.upsertMerchantRule(
        pattern: 'Swiggy',
        categoryId: await catId(CategoryKind.expense, 'Food'),
      );
      expect(await db.findMerchantRule('  SWIGGY '), isNotNull);
      expect(await db.findMerchantRule('SWIGGY INSTAMART'), isNull);
    });

    test('the fuzzy suggester respects word boundaries and min length',
        () async {
      await db.upsertMerchantRule(
        pattern: 'OLA',
        categoryId: await catId(CategoryKind.expense, 'Transport'),
      );
      await db.upsertMerchantRule(
        pattern: 'SWIGGY',
        categoryId: await catId(CategoryKind.expense, 'Food'),
      );

      // Too short to fuzzy-match anything.
      expect(await db.suggestMerchantRule('GOLA SNACKS'), isNull);
      // Word boundary hit.
      expect(await db.suggestMerchantRule('SWIGGY INSTAMART'), isNotNull);
    });
  });

  group('budget alerts', () {
    test('claim is atomic: two concurrent claims, only one wins', () async {
      final food = await catId(CategoryKind.expense, 'Food');
      final results = await Future.wait([
        db.claimBudgetAlert(
            categoryId: food, periodKey: '2026-07', level: AlertLevel.threshold),
        db.claimBudgetAlert(
            categoryId: food, periodKey: '2026-07', level: AlertLevel.threshold),
        db.claimBudgetAlert(
            categoryId: food, periodKey: '2026-07', level: AlertLevel.threshold),
      ]);
      expect(results.where((x) => x).length, 1,
          reason: 'the alert must buzz exactly once');
    });

    test('a released claim can be re-claimed (alert not lost for the period)',
        () async {
      final food = await catId(CategoryKind.expense, 'Food');
      const key = '2026-07';

      expect(
          await db.claimBudgetAlert(
              categoryId: food, periodKey: key, level: AlertLevel.overspent),
          isTrue);
      expect(
          await db.claimBudgetAlert(
              categoryId: food, periodKey: key, level: AlertLevel.overspent),
          isFalse);

      // The notification failed to show -> give the claim back.
      await db.releaseBudgetAlert(
          categoryId: food, periodKey: key, level: AlertLevel.overspent);

      expect(
          await db.claimBudgetAlert(
              categoryId: food, periodKey: key, level: AlertLevel.overspent),
          isTrue,
          reason: 'an undelivered alert must not be silenced all month');
    });
  });

  group('dedupe: one payment, two senders', () {
    test('a wallet SMS with no account hint is flagged against the bank SMS',
        () async {
      final bankAt = DateTime(2026, 7, 9, 10, 0);
      await ingest(
        'Rs.200.00 debited from A/c XXXX1234 to VPA shop@upi (UPI Ref no 123456789012)',
        at: bankAt,
      );
      // PhonePe: no A/c, and a different reference format entirely.
      await ingest(
        'Rs.200 paid to Merchant via PhonePe. UPI transaction ID T2407091234567890',
        sender: 'AD-PHONPE',
        at: bankAt.add(const Duration(minutes: 1)),
      );

      final all = await db.watchAllPendingTxns().first;
      expect(all, hasLength(2));
      expect(all.where((p) => p.status == PendingStatus.duplicate), hasLength(1),
          reason: 'the same ₹200 must not be bookable twice');

      // Only one card is offered for review.
      expect(await db.watchPendingCards().first, hasLength(1));
    });

    test('different amounts are never deduped', () async {
      final t = DateTime(2026, 7, 9, 10, 0);
      await ingest('Rs.200.00 debited from A/c XXXX1234', at: t);
      await ingest('Rs.350 paid via PhonePe',
          sender: 'AD-PHONPE', at: t.add(const Duration(minutes: 1)));

      final cards = await db.watchPendingCards().first;
      expect(cards, hasLength(2), reason: 'dedupe must not eat real spending');
    });

    test('a duplicate-flagged card can never be auto-approved', () async {
      final t = DateTime(2026, 7, 9, 10, 0);
      await ingest('Rs.200.00 debited from A/c XXXX1234', at: t);
      final id = await ingest('Rs.200 paid via PhonePe',
          sender: 'AD-PHONPE', at: t.add(const Duration(minutes: 1)));

      final card = await db.pendingById(id!);
      expect(card!.status, PendingStatus.duplicate);
    });
  });

  group('backup is a faithful round-trip', () {
    test('restore preserves the review inbox and the budget-alert claims',
        () async {
      final cash = await cashId();
      final food = await catId(CategoryKind.expense, 'Food');

      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(100),
        accountId: cash,
        categoryId: food,
        date: DateTime(2026, 7, 1),
      );
      await ingest('Rs.500.00 debited from A/c XX9999 at SHOP');
      await db.claimBudgetAlert(
          categoryId: food, periodKey: '2026-07', level: AlertLevel.threshold);

      final pendingBefore = await db.watchAllPendingTxns().first;
      expect(pendingBefore, hasLength(1));

      final dump =
          jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;

      // Both tables must be IN the backup, because importAll clears them.
      expect(dump['pendingTxns'], hasLength(1));
      expect(dump['budgetAlerts'], hasLength(1));

      await db.importAll(dump);

      expect(await db.watchAllPendingTxns().first, hasLength(1),
          reason: 'restoring the app\'s own backup must not wipe review cards');
      expect(
          await db.claimBudgetAlert(
              categoryId: food,
              periodKey: '2026-07',
              level: AlertLevel.threshold),
          isFalse,
          reason: 'a restored backup must not re-fire alerts already seen');
    });

    test('an older backup without the new tables still restores', () async {
      final cash = await cashId();
      await db.addTransaction(
        type: TxType.income,
        amount: Money.fromRupees(1000),
        accountId: cash,
        categoryId: await catId(CategoryKind.income, 'Salary'),
        date: DateTime(2026, 7, 1),
      );

      final dump =
          jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;
      dump.remove('pendingTxns');
      dump.remove('budgetAlerts');

      await db.importAll(dump);
      expect(await db.watchNetWorth().first, Money.fromRupees(1000));
    });
  });
}
