import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/message_capture/ocr_service.dart';
import 'package:xpenc/features/message_capture/share_intake.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// Stands in for the real ML Kit recognizer — a platform channel with no
/// implementation under `flutter test` — so the rest of [ShareIntakeService
/// .ingestImage] can be exercised without a device.
class _FakeOcr extends OcrService {
  const _FakeOcr(this.text);
  final String text;

  @override
  Future<String> recognizeText(String imagePath) async => text;
}

/// GitHub #25: a user can Share a payment-app screenshot (PhonePe/GPay/
/// Paytm "payment successful") straight into XPENC, the same way #26 let
/// them share a bank SMS. [ShareIntakeService.ingestImage] is the
/// non-platform half of that path.
void main() {
  late Directory tempDir;
  late AppDatabase db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('xpenc_screenshot_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Future<File> fakeSharedImage(String name) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes([0]);
    return file;
  }

  ShareIntakeService serviceWithOcrText(String text) =>
      ShareIntakeService(db: db, ocr: _FakeOcr(text));

  test('a payment-successful screenshot is recognised and queued', () async {
    final shared = await fakeSharedImage('phonepe.jpg');
    final service = serviceWithOcrText(
      'Payment Successful\n₹500\nPaid to\nSwiggy\n'
      'UPI Transaction ID\n123456789012',
    );

    final result = await service.ingestImage(shared.path);

    expect(result, isA<ShareIntakeIngested>());
    final pending = await db.watchAllPendingTxns().first;
    expect(pending, hasLength(1));
    expect(pending.single.source, MessageSourceKind.screenshot);
    expect(pending.single.parsedMerchant, 'Swiggy');
    // Copied into permanent storage, not left pointing at the plugin's temp
    // cache file — see the doc on ShareIntakeService.ingestImage.
    expect(pending.single.sourceImagePath, isNot(shared.path));
    expect(await File(pending.single.sourceImagePath!).exists(), isTrue);
  });

  test(
    "a screenshot with nothing recognisable is rejected, and its stored "
    "copy doesn't linger",
    () async {
      final shared = await fakeSharedImage('random.jpg');
      final service = serviceWithOcrText('just a photo of a cat');

      final result = await service.ingestImage(shared.path);

      expect(result, isA<ShareIntakeRejected>());
      expect(
        (result as ShareIntakeRejected).recognizedText,
        'just a photo of a cat',
        reason: 'a rejected screenshot never reaches PendingTxns, so this is '
            'the only place left to see what OCR actually read',
      );
      expect(await db.watchAllPendingTxns().first, isEmpty);
      // The original shared file is untouched — only XPENC's own copy of it
      // is ever deleted.
      expect(await shared.exists(), isTrue);
      // Nothing references XPENC's copy — the best-effort cleanup must have
      // removed it from the receipts directory it was stored into.
      final receiptsDir = Directory('${tempDir.path}/receipts');
      if (await receiptsDir.exists()) {
        expect(
          receiptsDir.listSync(),
          isEmpty,
          reason: 'the copy nothing references should have been deleted',
        );
      }
    },
  );

  test(
    'sharing the same screenshot content twice is reported as a duplicate',
    () async {
      final first = await fakeSharedImage('a.jpg');
      final second = await fakeSharedImage('b.jpg');
      final service =
          serviceWithOcrText('Payment Successful\n₹250\nPaid to\nSwiggy');

      final r1 = await service.ingestImage(first.path);
      final r2 = await service.ingestImage(second.path);

      expect(r1, isA<ShareIntakeIngested>());
      expect(r2, isA<ShareIntakeDuplicate>());
      expect(await db.watchAllPendingTxns().first, hasLength(1));
    },
  );
}
