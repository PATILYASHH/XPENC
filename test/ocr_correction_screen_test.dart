import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/message_capture/ocr_feedback/ocr_correction_screen.dart';

/// See test/smoke_test.dart for the three rules that keep Drift-backed
/// widget tests from tripping the `!timersPending` assertion: database work
/// inside `runAsync`, never `pumpAndSettle`, and unmounting before the test
/// ends.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    // Test at a real phone size (360 x 800 dp), not the 800x600 default —
    // otherwise layout overflows that ship to the device go unnoticed.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const OcrCorrectionScreen(),
        ),
      ),
    );
    // Let Drift's real async queries resolve, then render the result.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('shows an empty state with no corrections', (tester) async {
    await pumpScreen(tester);

    expect(find.text('No corrections yet'), findsOneWidget);
    expect(find.textContaining('Send'), findsNothing);

    await unmount(tester);
  });

  testWidgets('lists a pending correction and offers Send', (tester) async {
    await tester.runAsync(
      () => db.addOcrCorrection(
        appLabel: 'PhonePe',
        country: 'India',
        rawOcrText: 'Payment successful\n₹500\nTo John Doe',
        wasCorrect: false,
        extractedAmount: '500',
        extractedPayee: 'John Doe',
        correctedPayee: 'John D.',
      ),
    );

    await pumpScreen(tester);

    expect(find.text('PhonePe'), findsOneWidget);
    expect(find.textContaining('Send 1 correction'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('a sent correction is listed separately and not resendable', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final id = await db.addOcrCorrection(
        appLabel: 'Google Pay',
        rawOcrText: 'x',
        wasCorrect: true,
      );
      await db.markOcrCorrectionsSent([id]);
    });

    await pumpScreen(tester);

    expect(find.text('SENT'), findsOneWidget);
    expect(find.textContaining('Send'), findsNothing);

    await unmount(tester);
  });
}
