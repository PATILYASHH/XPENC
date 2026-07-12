import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/message_capture/parser/bank_message.dart';
import 'package:xpenc/features/message_capture/parser/message_parser.dart';

void main() {
  late AppDatabase db;
  const parser = MessageParser();

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  RawMessage msg(String body, {DateTime? at, String sender = 'AD-IPPBNK'}) =>
      RawMessage(
        body: body,
        sender: sender,
        receivedAt: at ?? DateTime(2026, 7, 9, 10, 0),
      );

  Future<int?> ingest(RawMessage m) async {
    final r = parser.parse(m);
    if (r is! ParsedMessage) return null;
    return db.ingestMessage(m, r);
  }

  Future<int> cashId() async =>
      (await db.watchAccounts().first).firstWhere((a) => a.type == AccountType.cash).id;

  Future<int> foodId() async =>
      (await db.watchCategories(CategoryKind.expense).first)
          .firstWhere((c) => c.name == 'Food')
          .id;

  Future<Money> netWorth() => db.watchNetWorth().first;

  group('ingest is idempotent', () {
    test('re-scanning the same message does not create a second card', () async {
      final m = msg('Rs.500.00 debited from A/c XX1234 to VPA ram@upi');
      final first = await ingest(m);
      final second = await ingest(m);

      expect(first, isNotNull);
      expect(second, isNull, reason: 'the exact same SMS must be ignored');
      expect((await db.watchAllPendingTxns().first), hasLength(1));
    });
  });

  group('dedupe — UPI fires two messages for one payment', () {
    test('the second message is flagged duplicate, not booked twice', () async {
      await ingest(msg(
        'Rs.250.00 debited from A/c XX1234 to VPA cafe@upi (Ref no 111222333444)',
        at: DateTime(2026, 7, 9, 10, 0),
      ));
      // The UPI app's own SMS, two minutes later, same payment.
      await ingest(msg(
        'Payment of Rs.250.00 debited from A/c XX1234 to CAFE. Ref no 111222333444',
        at: DateTime(2026, 7, 9, 10, 2),
      ));

      final all = await db.watchAllPendingTxns().first;
      expect(all, hasLength(2));
      expect(
        all.where((p) => p.status == PendingStatus.duplicate),
        hasLength(1),
      );

      // Only the non-duplicate is offered to the user.
      final cards = await db.watchPendingCards().first;
      expect(cards, hasLength(1));
    });

    test('same amount + account minutes apart is treated as duplicate',
        () async {
      await ingest(msg('Rs.99.00 debited from A/c XX1234',
          at: DateTime(2026, 7, 9, 10, 0)));
      await ingest(msg('Rs.99.00 debited from A/c XX1234 at SHOP',
          at: DateTime(2026, 7, 9, 10, 3)));

      final cards = await db.watchPendingCards().first;
      expect(cards, hasLength(1));
    });

    test('a genuinely separate payment is NOT deduped', () async {
      await ingest(msg('Rs.99.00 debited from A/c XX1234',
          at: DateTime(2026, 7, 9, 10, 0)));
      // Different amount → a real second purchase.
      await ingest(msg('Rs.150.00 debited from A/c XX1234',
          at: DateTime(2026, 7, 9, 10, 2)));
      // Same amount but hours later → a real second purchase.
      await ingest(msg('Rs.99.00 debited from A/c XX1234',
          at: DateTime(2026, 7, 9, 18, 0)));

      final cards = await db.watchPendingCards().first;
      expect(cards, hasLength(3), reason: 'dedupe must not eat real spending');
    });
  });

  group('account matching by last 4', () {
    test('a message maps to the account with those digits', () async {
      await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        bankName: 'India Post Payments Bank',
        last4: '1234',
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(5000),
      );
      await ingest(msg('Rs.500.00 debited from A/c XX1234'));

      final card = (await db.watchPendingCards().first).single;
      expect(card.matchedAccountId, isNotNull);
      expect(card.parsedAccountHint, '1234');
    });

    test('unknown digits leave the account unmatched, card still shows',
        () async {
      await ingest(msg('Rs.500.00 debited from A/c XX9999'));
      final card = (await db.watchPendingCards().first).single;
      expect(card.matchedAccountId, isNull);
      expect(card.status, PendingStatus.pending);
    });
  });

  group('approve posts to the ledger', () {
    test('a debit becomes an expense', () async {
      await ingest(msg('Rs.320.00 debited from A/c XX1234 at SWIGGY'));
      final card = (await db.watchPendingCards().first).single;

      final txId = await db.approvePending(
        card.id,
        categoryId: await foodId(),
        accountId: await cashId(),
      );

      expect(txId, greaterThan(0));
      expect(await netWorth(), Money.fromRupees(-320));

      final after = (await db.watchAllPendingTxns().first).single;
      expect(after.status, PendingStatus.approved);
      expect(after.createdTransactionId, txId);
    });

    test('a credit becomes income', () async {
      await ingest(msg('Rs.2,000.00 credited to A/c XX1234'));
      final card = (await db.watchPendingCards().first).single;
      final salary = (await db.watchCategories(CategoryKind.income).first)
          .firstWhere((c) => c.name == 'Salary')
          .id;

      await db.approvePending(card.id,
          categoryId: salary, accountId: await cashId());
      expect(await netWorth(), Money.fromRupees(2000));
    });

    test('approving twice is refused', () async {
      await ingest(msg('Rs.10.00 debited from A/c XX1234'));
      final card = (await db.watchPendingCards().first).single;
      final food = await foodId();
      final cash = await cashId();

      await db.approvePending(card.id, categoryId: food, accountId: cash);

      expect(
        () => db.approvePending(card.id, categoryId: food, accountId: cash),
        throwsArgumentError,
      );
    });
  });

  group('Undo must reverse the transaction, not just hide the card', () {
    test('undo removes the posted transaction and restores the balance',
        () async {
      await ingest(msg('Rs.750.00 debited from A/c XX1234 at SHOP'));
      final card = (await db.watchPendingCards().first).single;

      await db.approvePending(
        card.id,
        categoryId: await foodId(),
        accountId: await cashId(),
        autoFilled: true,
      );
      expect(await netWorth(), Money.fromRupees(-750));
      expect((await db.watchTransactions().first), hasLength(1));

      await db.undoPending(card.id);

      expect(await netWorth(), const Money.zero(),
          reason: 'undo must reverse the money, not only the card');
      expect((await db.watchTransactions().first), isEmpty);

      final after = (await db.watchAllPendingTxns().first).single;
      expect(after.status, PendingStatus.pending);
      expect(after.createdTransactionId, isNull);
    });
  });

  group('merchant rules — what Auto-Approve may fire from', () {
    test('approving with learning creates a reusable rule', () async {
      await ingest(msg('Rs.320.00 debited from A/c XX1234 at SWIGGY on 09-07-26'));
      final card = (await db.watchPendingCards().first).single;
      expect(card.parsedMerchant, isNotNull);

      await db.approvePending(
        card.id,
        categoryId: await foodId(),
        accountId: await cashId(),
        learnMerchantRule: true,
      );

      final rule = await db.findMerchantRule(card.parsedMerchant);
      expect(rule, isNotNull);
      expect(rule!.categoryId, await foodId());
    });

    test('no rule exists for an unseen merchant — never a fresh guess',
        () async {
      expect(await db.findMerchantRule('SOME NEW SHOP'), isNull);
      expect(await db.findMerchantRule(null), isNull);
    });
  });

  group('budget alerts fire once per period', () {
    test('claim returns true once, then false', () async {
      final food = await foodId();
      const key = '2026-07';

      expect(
        await db.claimBudgetAlert(
            categoryId: food, periodKey: key, level: AlertLevel.threshold),
        isTrue,
      );
      expect(
        await db.claimBudgetAlert(
            categoryId: food, periodKey: key, level: AlertLevel.threshold),
        isFalse,
        reason: 'must not notify on every single purchase',
      );
      // A different level, and a different month, are separate claims.
      expect(
        await db.claimBudgetAlert(
            categoryId: food, periodKey: key, level: AlertLevel.overspent),
        isTrue,
      );
      expect(
        await db.claimBudgetAlert(
            categoryId: food, periodKey: '2026-08', level: AlertLevel.threshold),
        isTrue,
      );
    });
  });
}
