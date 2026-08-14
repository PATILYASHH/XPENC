import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a new correction is pending until marked sent', () async {
    final id = await db.addOcrCorrection(
      appLabel: 'PhonePe',
      country: 'India',
      rawOcrText: 'Payment successful\n₹500\nTo John Doe',
      wasCorrect: false,
      extractedAmount: '500',
      extractedDirection: 'debit',
      extractedPayee: 'John Doe',
      correctedPayee: 'John D.',
    );

    final pending = await db.watchPendingOcrCorrections().first;
    expect(pending, hasLength(1));
    expect(pending.single.id, id);
    expect(pending.single.correctedPayee, 'John D.');
    expect(pending.single.sentAt, isNull);

    await db.markOcrCorrectionsSent([id]);

    expect(await db.watchPendingOcrCorrections().first, isEmpty);
    final sent = await db.watchSentOcrCorrections().first;
    expect(sent, hasLength(1));
    expect(sent.single.sentAt, isNotNull);
  });

  test('deleting a correction removes it', () async {
    final id = await db.addOcrCorrection(
      appLabel: 'Google Pay',
      rawOcrText: 'x',
      wasCorrect: true,
    );

    await db.deleteOcrCorrection(id);

    expect(await db.watchPendingOcrCorrections().first, isEmpty);
  });
}
