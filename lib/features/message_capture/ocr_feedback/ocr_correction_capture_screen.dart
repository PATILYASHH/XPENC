import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../data/tables.dart';
import '../ocr_service.dart';
import '../parser/bank_message.dart';
import '../parser/screenshot_parser.dart';

const ocrCorrectionAppLabels = [
  'Google Pay',
  'PhonePe',
  'Samsung Pay',
  'WhatsApp Pay',
  'Other',
];

/// Lets a user test a payment-app screenshot against the real OCR+parser
/// pipeline and, if it got something wrong, record the correct values as a
/// labeled example. See Settings > Message Capture > OCR corrections and
/// docs/superpowers/specs/2026-08-14-ocr-corrections-design.md.
class OcrCorrectionCaptureScreen extends ConsumerStatefulWidget {
  const OcrCorrectionCaptureScreen({super.key, this.ocr = const OcrService()});

  final OcrService ocr;

  @override
  ConsumerState<OcrCorrectionCaptureScreen> createState() =>
      _OcrCorrectionCaptureScreenState();
}

class _OcrCorrectionCaptureScreenState
    extends ConsumerState<OcrCorrectionCaptureScreen> {
  static const _screenshotParser = ScreenshotParser();

  bool _loading = false;
  String? _rawText;
  String _appLabel = ocrCorrectionAppLabels.first;

  String? _extractedAmount;
  String? _extractedDirection;
  String? _extractedPayee;
  String? _extractedReference;

  final _countryController = TextEditingController();
  final _amountController = TextEditingController();
  final _directionController = TextEditingController();
  final _payeeController = TextEditingController();
  final _referenceController = TextEditingController();
  bool _showCorrectionFields = false;

  @override
  void dispose() {
    _countryController.dispose();
    _amountController.dispose();
    _directionController.dispose();
    _payeeController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickAndRecognize() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() => _loading = true);
    final String text;
    final ParseResult parsed;
    try {
      text = await widget.ocr.recognizeText(path);
      parsed = _screenshotParser.parse(
        RawMessage(
          body: text,
          sender: 'Screenshot',
          receivedAt: DateTime.now(),
          source: MessageSourceKind.screenshot,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text("Couldn't read that image")),
        );
      return;
    }
    final amount = parsed is ParsedMessage
        ? parsed.amount.rupees.toStringAsFixed(2)
        : null;
    final direction = parsed is ParsedMessage ? parsed.direction.name : null;
    final payee = parsed is ParsedMessage ? parsed.merchant : null;
    final reference = parsed is ParsedMessage ? parsed.reference : null;

    if (!mounted) return;
    setState(() {
      _loading = false;
      _rawText = text;
      _showCorrectionFields = false;
      _extractedAmount = amount;
      _extractedDirection = direction;
      _extractedPayee = payee;
      _extractedReference = reference;
      _amountController.text = amount ?? '';
      _directionController.text = direction ?? '';
      _payeeController.text = payee ?? '';
      _referenceController.text = reference ?? '';
    });
  }

  String? _textOrNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save({required bool wasCorrect}) async {
    final rawText = _rawText;
    if (rawText == null) return;

    await ref
        .read(dbProvider)
        .addOcrCorrection(
          appLabel: _appLabel,
          country: _textOrNull(_countryController),
          rawOcrText: rawText,
          wasCorrect: wasCorrect,
          extractedAmount: _extractedAmount,
          extractedDirection: _extractedDirection,
          extractedPayee: _extractedPayee,
          extractedReference: _extractedReference,
          correctedAmount: wasCorrect ? null : _textOrNull(_amountController),
          correctedDirection: wasCorrect
              ? null
              : _textOrNull(_directionController),
          correctedPayee: wasCorrect ? null : _textOrNull(_payeeController),
          correctedReference: wasCorrect
              ? null
              : _textOrNull(_referenceController),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Test a screenshot')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_rawText == null) ...[
                  Text(
                    "Pick a screenshot of a payment app's confirmation "
                    'screen. It is read on-device, entirely offline.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _pickAndRecognize,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Choose screenshot'),
                  ),
                ] else ...[
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final label in ocrCorrectionAppLabels)
                        ChoiceChip(
                          label: Text(label),
                          selected: _appLabel == label,
                          onSelected: (_) => setState(() => _appLabel = label),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _countryController,
                    decoration: const InputDecoration(labelText: 'Country'),
                  ),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    title: const Text('Raw OCR text'),
                    initiallyExpanded: _rawText!.isEmpty,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          _rawText!.isEmpty
                              ? '(nothing recognised)'
                              : _rawText!,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    enabled: _showCorrectionFields,
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _directionController,
                    enabled: _showCorrectionFields,
                    decoration: const InputDecoration(
                      labelText: 'Direction (debit/credit)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _payeeController,
                    enabled: _showCorrectionFields,
                    decoration: const InputDecoration(labelText: 'Payee'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _referenceController,
                    enabled: _showCorrectionFields,
                    decoration: const InputDecoration(labelText: 'Reference'),
                  ),
                  const SizedBox(height: 20),
                  if (!_showCorrectionFields) ...[
                    FilledButton(
                      onPressed: () => _save(wasCorrect: true),
                      child: const Text('This is correct'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          setState(() => _showCorrectionFields = true),
                      child: const Text("This is wrong — let me fix it"),
                    ),
                  ] else
                    FilledButton(
                      onPressed: () => _save(wasCorrect: false),
                      child: const Text('Save correction'),
                    ),
                ],
              ],
            ),
    );
  }
}
