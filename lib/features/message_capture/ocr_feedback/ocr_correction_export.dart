import 'dart:convert';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/branding/app_info.dart';
import '../../../data/database.dart';

/// How large the fully percent-encoded `mailto:` URI can get before it
/// risks being truncated or rejected by the receiving mail app. Measured
/// against the *encoded* URI, not the raw JSON body — percent-encoding
/// (every newline, brace, quote, and non-ASCII character like `₹` becomes a
/// multi-byte `%XX` sequence) reliably inflates a JSON body by 1.5x or
/// more, so checking the raw body length alone under-protects against the
/// exact failure this guards against.
const mailtoSafeUriLength = 1800;

/// Builds the JSON payload a batch of corrections is sent as. Only text —
/// the source screenshot is never included. See
/// docs/superpowers/specs/2026-08-14-ocr-corrections-design.md.
String buildOcrCorrectionsJson(List<OcrCorrectionRow> rows) {
  final payload = {
    'appVersion': AppInfo.version,
    'corrections': [
      for (final row in rows)
        {
          'appLabel': row.appLabel,
          'country': row.country,
          'rawOcrText': row.rawOcrText,
          'wasCorrect': row.wasCorrect,
          'extracted': {
            'amount': row.extractedAmount,
            'direction': row.extractedDirection,
            'payee': row.extractedPayee,
            'reference': row.extractedReference,
          },
          'corrected': {
            'amount': row.correctedAmount,
            'direction': row.correctedDirection,
            'payee': row.correctedPayee,
            'reference': row.correctedReference,
          },
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(payload);
}

/// Opens an external app to send [rows] as OCR-correction feedback. Tries a
/// pre-addressed `mailto:` first (same try/launch/fallback shape
/// `about_screen.dart` already uses for external links — `canLaunchUrl`
/// isn't reliable without extra `<queries>` manifest entries); falls back to
/// the OS share sheet when the encoded `mailto:` URI is unsafely long or no
/// mail app answers. XPENC's own code never makes a network call either
/// way — see the privacy note in the design spec.
Future<void> sendOcrCorrections(List<OcrCorrectionRow> rows) async {
  if (rows.isEmpty) return;
  final body = buildOcrCorrectionsJson(rows);
  final subject = 'XPENC OCR corrections (${rows.length})';
  final mailUri = Uri(
    scheme: 'mailto',
    path: AppInfo.feedbackEmail,
    queryParameters: {'subject': subject, 'body': body},
  );

  if (mailUri.toString().length <= mailtoSafeUriLength) {
    var opened = false;
    try {
      opened = await launchUrl(mailUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (opened) return;
  }

  await SharePlus.instance.share(
    ShareParams(
      text: 'Send to ${AppInfo.feedbackEmail}\n\n$subject\n\n$body',
      subject: subject,
    ),
  );
}
