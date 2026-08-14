import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/features/message_capture/ocr_feedback/ocr_correction_export.dart';

OcrCorrectionRow _row({
  bool wasCorrect = false,
  String? correctedPayee = 'John D.',
}) => OcrCorrectionRow(
  id: 1,
  createdAt: DateTime(2026, 8, 14),
  appLabel: 'PhonePe',
  country: 'India',
  rawOcrText: 'Payment successful\n₹500\nTo John Doe',
  wasCorrect: wasCorrect,
  extractedAmount: '500',
  extractedDirection: 'debit',
  extractedPayee: 'John Doe',
  extractedReference: null,
  correctedAmount: '500',
  correctedDirection: 'debit',
  correctedPayee: correctedPayee,
  correctedReference: '123456789012',
  sentAt: null,
);

void main() {
  test('buildOcrCorrectionsJson includes only text, never a file path', () {
    final json = jsonDecode(buildOcrCorrectionsJson([_row()])) as Map;

    expect(json['corrections'], hasLength(1));
    final entry = (json['corrections'] as List).single as Map;
    expect(entry['appLabel'], 'PhonePe');
    expect(entry['country'], 'India');
    expect(entry['wasCorrect'], false);
    expect((entry['extracted'] as Map)['payee'], 'John Doe');
    expect((entry['corrected'] as Map)['payee'], 'John D.');
    expect(json.toString(), isNot(contains('.jpg')));
    expect(json.toString(), isNot(contains('.png')));
  });

  test('an empty batch produces no corrections entries', () {
    final json = jsonDecode(buildOcrCorrectionsJson([])) as Map;
    expect(json['corrections'], isEmpty);
  });
}
