import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/message_capture/share_intake.dart';

/// GitHub #26: a user can Share a bank SMS from any app straight into
/// XPENC, without granting READ_SMS. [ShareIntakeService.ingest] is the
/// non-platform half of that path — the same parse-and-queue step the
/// Share-sheet intent handler in `app.dart` calls once Android hands it the
/// shared text.
void main() {
  late AppDatabase db;
  late ShareIntakeService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = ShareIntakeService(db: db);
  });
  tearDown(() => db.close());

  test(
    'a real bank message is parsed and queued in the Review Inbox',
    () async {
      final result = await service.ingest(
        'Rs.500.00 debited from A/c XX1234 at SWIGGY on 09-07-26. '
        'Avl Bal Rs.4,500.00',
      );

      expect(result, isA<ShareIntakeIngested>());
      final pending = await db.watchAllPendingTxns().first;
      expect(pending, hasLength(1));
      expect(pending.single.source, MessageSourceKind.shared);
      expect(pending.single.parsedAmount, Money.fromRupees(500));
      expect(pending.single.parsedDirection, TxDirection.debit);
    },
  );

  test('an OTP is rejected, not silently dropped as a success', () async {
    final result = await service.ingest(
      '123456 is your OTP to log in. Do not share it with anyone.',
    );

    expect(result, isA<ShareIntakeRejected>());
    expect(await db.watchAllPendingTxns().first, isEmpty);
  });

  test(
    'sharing the exact same message twice is reported as a duplicate',
    () async {
      const body = 'Rs.250.00 debited from A/c XX1234 at SWIGGY on 09-07-26.';

      final first = await service.ingest(body);
      final second = await service.ingest(body);

      expect(first, isA<ShareIntakeIngested>());
      expect(second, isA<ShareIntakeDuplicate>());
      expect(await db.watchAllPendingTxns().first, hasLength(1));
    },
  );

  test('an unparseable share never reaches the pending table', () async {
    await service.ingest('happy birthday!! hope your day is amazing');
    expect(await db.watchAllPendingTxns().first, isEmpty);
  });
}
