import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/message_capture/capture_service.dart';
import 'package:xpenc/features/message_capture/message_source.dart';
import 'package:xpenc/features/message_capture/parser/bank_message.dart';

/// Drives scan -> parse -> dedupe -> auto-approve without touching Android.
void main() {
  late AppDatabase db;
  final now = DateTime.now();

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  RawMessage m(String body, {String sender = 'AD-IPPBNK', int hoursAgo = 2}) =>
      RawMessage(
        body: body,
        sender: sender,
        receivedAt: now.subtract(Duration(hours: hoursAgo)),
      );

  CaptureService svc(List<RawMessage> messages, {bool granted = true}) =>
      CaptureService(
        db: db,
        source: FakeMessageSource(messages, granted: granted),
      );

  Future<int> bankWithLast4(String last4) => db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        bankName: 'India Post Payments Bank',
        last4: last4,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(10000),
      );

  Future<int> foodId() async =>
      (await db.watchCategories(CategoryKind.expense).first)
          .firstWhere((c) => c.name == 'Food')
          .id;

  const swiggy =
      'Rs.320.00 debited from A/c XX1234 at SWIGGY on 09-07-26. '
      'Ref no 998877665544. Avl Bal Rs.3,000.00';

  group('gates', () {
    test('does nothing while capture is off', () async {
      final r = await svc([m(swiggy)]).scan();
      expect(r.didRun, isFalse);
      expect(r.reason, contains('off'));
      expect(await db.watchAllPendingTxns().first, isEmpty);
    });

    test('does nothing without permission', () async {
      await db.setMessageCaptureEnabled(true);
      final r = await svc([m(swiggy)], granted: false).scan();
      expect(r.didRun, isFalse);
      expect(r.reason, contains('permission'));
    });
  });

  group('scanning', () {
    setUp(() => db.setMessageCaptureEnabled(true));

    test('ingests bank messages and ignores personal ones', () async {
      final r = await svc([
        m(swiggy),
        m('Hey, can you send me Rs.500?', sender: '9876543210'),
      ]).scan();

      expect(r.didRun, isTrue);
      expect(r.ingested, 1);
      expect(r.skippedSender, 1, reason: 'a person is not a bank');
      expect(await db.watchPendingCards().first, hasLength(1));
    });

    test('rejects OTP and declined messages', () async {
      final r = await svc([
        m('123456 is your OTP. Do not share.'),
        m('Txn of Rs.2000 on A/c XX1234 was declined.'),
      ]).scan();

      expect(r.ingested, 0);
      expect(r.rejected, 2);
      expect(await db.watchPendingCards().first, isEmpty);
    });

    test('the watermark makes a second scan a no-op', () async {
      final service = svc([m(swiggy)]);
      expect((await service.scan()).ingested, 1);
      expect((await service.scan()).ingested, 0,
          reason: 'already-scanned messages must not reappear');
      expect(await db.watchAllPendingTxns().first, hasLength(1));
    });

    test('the watermark advances to the last message, never to now', () async {
      final oldest = m(swiggy, hoursAgo: 5);
      await svc([oldest]).scan();

      final wm = (await db.getSettings()).lastMessageScanAt!;

      // Drift persists DateTime as unix *seconds*, so the watermark truncates
      // down — landing at or just before the message. That is the safe
      // direction: a re-scan may re-see it, and ingest is idempotent.
      expect(wm.difference(oldest.receivedAt).abs(),
          lessThan(const Duration(seconds: 1)));

      // The thing that actually matters: it did NOT jump to now.
      expect(wm.isBefore(DateTime.now().subtract(const Duration(hours: 4))),
          isTrue,
          reason: 'jumping to now would skip anything beyond a truncated batch');
    });

    test('a truncated batch is resumed, not lost or duplicated', () async {
      // Simulates the platform cap: scan #1 only sees the oldest message.
      final older = m('Rs.100.00 debited from A/c XX1111', hoursAgo: 5);
      final newer = m('Rs.200.00 debited from A/c XX2222', hoursAgo: 1);

      expect((await svc([older]).scan()).ingested, 1);

      // Scan #2 sees both. `older` may be re-read (second-truncated watermark)
      // but ingest is idempotent, so it is not booked twice. `newer` — the one
      // the cap cut off last time — is picked up.
      final r = await svc([older, newer]).scan();
      expect(r.ingested, 1, reason: 'only the previously cut-off message is new');
      expect(await db.watchPendingCards().first, hasLength(2),
          reason: 'nothing lost, nothing duplicated');
    });

    test('an empty scan leaves the watermark untouched', () async {
      await svc([m(swiggy, hoursAgo: 3)]).scan();
      final first = (await db.getSettings()).lastMessageScanAt;

      await svc(const []).scan();
      expect((await db.getSettings()).lastMessageScanAt, first);
    });

    test('nothing is posted to the ledger without the user', () async {
      await svc([m(swiggy)]).scan();
      expect(await db.watchTransactions().first, isEmpty);
      expect(await db.watchNetWorth().first, const Money.zero());
    });
  });

  group('Auto-Approve guardrails', () {
    setUp(() async {
      await db.setMessageCaptureEnabled(true);
      await db.setAutoApprove(true);
    });

    test('does nothing without a learned rule — never a fresh guess', () async {
      await bankWithLast4('1234');
      final r = await svc([m(swiggy)]).scan();

      expect(r.ingested, 1);
      expect(r.autoFilled, 0);
      expect(await db.watchTransactions().first, isEmpty);
      expect((await db.watchPendingCards().first).single.status,
          PendingStatus.pending);
    });

    test('fires from a learned rule and posts the transaction', () async {
      final bank = await bankWithLast4('1234');
      final food = await foodId();
      await db.upsertMerchantRule(
          pattern: 'SWIGGY', categoryId: food, accountId: bank);

      final r = await svc([m(swiggy)]).scan();

      expect(r.autoFilled, 1);
      final card = (await db.watchPendingCards().first).single;
      expect(card.status, PendingStatus.autoFilled);
      expect(card.createdTransactionId, isNotNull);

      // 10000 opening - 320 spent
      expect(await db.watchNetWorth().first, Money.fromRupees(9680));
    });

    test('an auto-filled card can be undone, reversing the money', () async {
      final bank = await bankWithLast4('1234');
      await db.upsertMerchantRule(
          pattern: 'SWIGGY', categoryId: await foodId(), accountId: bank);
      await svc([m(swiggy)]).scan();

      final card = (await db.watchPendingCards().first).single;
      await db.undoPending(card.id);

      expect(await db.watchNetWorth().first, Money.fromRupees(10000));
      expect(await db.watchTransactions().first, isEmpty);
    });

    test('refuses to fire on a low-confidence message', () async {
      final bank = await bankWithLast4('1234');
      await db.upsertMerchantRule(
          pattern: 'SWIGGY', categoryId: await foodId(), accountId: bank);

      // No account hint, no ref, personal-looking sender -> low confidence.
      final r = await svc([
        RawMessage(
          body: 'Rs.320 debited at SWIGGY',
          sender: 'AD-IPPBNK',
          receivedAt: now.subtract(const Duration(hours: 1)),
        ),
      ]).scan();

      expect(r.ingested, 1);
      expect(r.autoFilled, 0, reason: 'shaky parses must wait for the user');
    });

    test('refuses to fire when the rule category contradicts the direction',
        () async {
      final bank = await bankWithLast4('1234');
      // Rule says Food (an EXPENSE category) but the message is money IN.
      await db.upsertMerchantRule(
          pattern: 'ACME', categoryId: await foodId(), accountId: bank);

      final r = await svc([
        m('Rs.500.00 credited to A/c XX1234 at ACME on 09-07-26. Ref no 12345678'),
      ]).scan();

      expect(r.ingested, 1);
      expect(r.autoFilled, 0,
          reason: 'an income message must never post to an expense category');
      expect(await db.watchTransactions().first, isEmpty);
    });

    test('refuses to fire on a card flagged as a duplicate', () async {
      final bank = await bankWithLast4('1234');
      await db.upsertMerchantRule(
          pattern: 'SWIGGY', categoryId: await foodId(), accountId: bank);

      final r = await svc([
        m(swiggy, hoursAgo: 2),
        // The UPI app's own SMS for the same payment, one minute later.
        RawMessage(
          body: 'Rs.320.00 debited from A/c XX1234 at SWIGGY. Ref no 998877665544',
          sender: 'VM-IPPBNK',
          receivedAt: now.subtract(const Duration(hours: 2, minutes: -1)),
        ),
      ]).scan();

      expect(r.ingested, 2);
      expect(r.autoFilled, 1, reason: 'only the first one may post');
      expect(await db.watchTransactions().first, hasLength(1));
      expect(await db.watchNetWorth().first, Money.fromRupees(9680),
          reason: 'a UPI double-SMS must never be booked twice');
    });
  });
}
