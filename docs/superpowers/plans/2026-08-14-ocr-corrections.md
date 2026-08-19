# OCR Corrections Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user test a payment-app screenshot against XPENC's on-device OCR+parser pipeline, mark whether it read correctly, and optionally hand the correction (text only, never the image) to their own email/share sheet so the developer can manually improve `screenshot_parser.dart` over time.

**Architecture:** A new Drift table (`OcrCorrections`, schema v29→v30) queues corrections locally. A new feature module (`lib/features/message_capture/ocr_feedback/`) reuses the existing `OcrService` and `ScreenshotParser` unchanged. Sending is `mailto:` with an OS-share-sheet fallback — the app's own code never makes a network call, matching the existing backup-export pattern and leaving the "no INTERNET permission" privacy claim untouched.

**Tech Stack:** Flutter/Dart, Drift ORM, Riverpod, `file_picker` (already a dependency), `url_launcher` (already a dependency), `share_plus` (already a dependency). No new packages.

**Spec:** `docs/superpowers/specs/2026-08-14-ocr-corrections-design.md` — read it for the full rationale before starting; this plan assumes it.

---

### Task 1: `OcrCorrections` table, migration, and `AppDatabase` CRUD methods

**Files:**
- Modify: `lib/data/tables.dart`
- Modify: `lib/data/database.dart`
- Test: `test/ocr_corrections_db_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/ocr_corrections_db_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ocr_corrections_db_test.dart`
Expected: FAIL to compile — `addOcrCorrection`, `watchPendingOcrCorrections`, `watchSentOcrCorrections` and `markOcrCorrectionsSent` aren't defined on `AppDatabase` yet.

- [ ] **Step 3: Add the table to `lib/data/tables.dart`**

Add this class after `TransactionSplits` (or any other table — position doesn't matter, but keep it near `PendingTxns` for readability since it's part of the same capture family):

```dart
/// A user-submitted example of what XPENC's on-device OCR read from a
/// payment-app screenshot, and whether the parser's extraction was right —
/// see Settings > Message Capture > OCR corrections and
/// docs/superpowers/specs/2026-08-14-ocr-corrections-design.md. Never holds
/// the source image, only text. [sentAt] is set once the user has fired a
/// send intent (mailto/share sheet) for this row — the app itself never
/// transmits it.
@DataClassName('OcrCorrectionRow')
class OcrCorrections extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get appLabel => text()();
  TextColumn get country => text().nullable()();
  TextColumn get rawOcrText => text()();
  BoolColumn get wasCorrect => boolean()();

  /// What `ScreenshotParser` actually produced — kept as display strings,
  /// not typed `Money`/`TxDirection`, since these are export-only and never
  /// feed back into the ledger.
  TextColumn get extractedAmount => text().nullable()();
  TextColumn get extractedDirection => text().nullable()();
  TextColumn get extractedPayee => text().nullable()();
  TextColumn get extractedReference => text().nullable()();

  /// Only set when [wasCorrect] is false.
  TextColumn get correctedAmount => text().nullable()();
  TextColumn get correctedDirection => text().nullable()();
  TextColumn get correctedPayee => text().nullable()();
  TextColumn get correctedReference => text().nullable()();

  DateTimeColumn get sentAt => dateTime().nullable()();
}
```

- [ ] **Step 4: Register the table, bump the schema version, and add the migration in `lib/data/database.dart`**

In the `@DriftDatabase(tables: [...])` list (around line 115), add `OcrCorrections,` as the last entry:

```dart
@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    Budgets,
    Persons,
    PersonEntries,
    Reminders,
    Settings,
    PendingTxns,
    MerchantRules,
    SenderRules,
    BudgetAlerts,
    RecurringRules,
    Tags,
    TransactionTags,
    TransactionSplits,
    GoalDetails,
    ShoppingLists,
    ShoppingItems,
    BackupRecords,
    Allocations,
    OcrCorrections,
  ],
)
```

Bump the schema version (around line 163):

```dart
  @override
  int get schemaVersion => 30;
```

Add a migration block right after the existing `if (from < 29) { ... }` block (around line 316):

```dart
      if (from < 30) {
        await m.createTable(ocrCorrections);
      }
```

- [ ] **Step 5: Add the CRUD methods to `AppDatabase`**

Add this section anywhere among the other feature-grouped methods in `lib/data/database.dart` (e.g. right after the `watchAllPendingTxns` / `PendingTxns` methods):

```dart
  // ── OCR corrections ────────────────────────────────────────────────────

  Future<int> addOcrCorrection({
    required String appLabel,
    String? country,
    required String rawOcrText,
    required bool wasCorrect,
    String? extractedAmount,
    String? extractedDirection,
    String? extractedPayee,
    String? extractedReference,
    String? correctedAmount,
    String? correctedDirection,
    String? correctedPayee,
    String? correctedReference,
  }) => into(ocrCorrections).insert(
    OcrCorrectionsCompanion.insert(
      appLabel: appLabel,
      country: Value(country),
      rawOcrText: rawOcrText,
      wasCorrect: wasCorrect,
      extractedAmount: Value(extractedAmount),
      extractedDirection: Value(extractedDirection),
      extractedPayee: Value(extractedPayee),
      extractedReference: Value(extractedReference),
      correctedAmount: Value(correctedAmount),
      correctedDirection: Value(correctedDirection),
      correctedPayee: Value(correctedPayee),
      correctedReference: Value(correctedReference),
    ),
  );

  Stream<List<OcrCorrectionRow>> watchPendingOcrCorrections() =>
      (select(ocrCorrections)
            ..where((t) => t.sentAt.isNull())
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
            ]))
          .watch();

  Stream<List<OcrCorrectionRow>> watchSentOcrCorrections() =>
      (select(ocrCorrections)
            ..where((t) => t.sentAt.isNotNull())
            ..orderBy([
              (t) => OrderingTerm(expression: t.sentAt, mode: OrderingMode.desc),
            ]))
          .watch();

  Future<void> markOcrCorrectionsSent(List<int> ids) async {
    if (ids.isEmpty) return;
    await (update(
      ocrCorrections,
    )..where((t) => t.id.isIn(ids))).write(
      OcrCorrectionsCompanion(sentAt: Value(DateTime.now())),
    );
  }

  Future<void> deleteOcrCorrection(int id) =>
      (delete(ocrCorrections)..where((t) => t.id.equals(id))).go();
```

- [ ] **Step 6: Regenerate Drift's generated code**

Run: `dart run build_runner build --force-jit --delete-conflicting-outputs`
Expected: completes with `Succeeded after ...` and no errors. `lib/data/database.g.dart` will have new generated code for `OcrCorrections`/`OcrCorrectionRow`/`OcrCorrectionsCompanion`.

- [ ] **Step 7: Run the test to verify it passes**

Run: `flutter test test/ocr_corrections_db_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 8: Commit**

```bash
git add lib/data/tables.dart lib/data/database.dart lib/data/database.g.dart test/ocr_corrections_db_test.dart
git commit -m "feat: add OcrCorrections table and AppDatabase CRUD methods"
```

---

### Task 2: Riverpod providers

**Files:**
- Modify: `lib/data/providers.dart`

- [ ] **Step 1: Add the stream providers**

Add near `allPendingProvider` (around line 611):

```dart
final pendingOcrCorrectionsProvider = StreamProvider<List<OcrCorrectionRow>>(
  (ref) => ref.watch(dbProvider).watchPendingOcrCorrections(),
);

final sentOcrCorrectionsProvider = StreamProvider<List<OcrCorrectionRow>>(
  (ref) => ref.watch(dbProvider).watchSentOcrCorrections(),
);
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/data/providers.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/data/providers.dart
git commit -m "feat: add providers for pending/sent OCR corrections"
```

---

### Task 3: Export/transport helper

**Files:**
- Create: `lib/features/message_capture/ocr_feedback/ocr_correction_export.dart`
- Test: `test/ocr_correction_export_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/ocr_correction_export_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ocr_correction_export_test.dart`
Expected: FAIL to compile — `ocr_correction_export.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `lib/features/message_capture/ocr_feedback/ocr_correction_export.dart`:

```dart
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
/// the OS share sheet when the body is unsafely long for a `mailto:` URL or
/// no mail app answers. XPENC's own code never makes a network call either
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ocr_correction_export_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/message_capture/ocr_feedback/ocr_correction_export.dart test/ocr_correction_export_test.dart
git commit -m "feat: build and send the OCR corrections JSON payload"
```

---

### Task 4: Capture screen (test a screenshot, correct the fields)

**Files:**
- Create: `lib/features/message_capture/ocr_feedback/ocr_correction_capture_screen.dart`

- [ ] **Step 1: Write the implementation**

Create `lib/features/message_capture/ocr_feedback/ocr_correction_capture_screen.dart`:

```dart
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
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/message_capture/ocr_feedback/ocr_correction_capture_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/message_capture/ocr_feedback/ocr_correction_capture_screen.dart
git commit -m "feat: add the OCR correction capture screen"
```

---

### Task 5: List screen (pending/sent corrections, delete, send)

**Files:**
- Create: `lib/features/message_capture/ocr_feedback/ocr_correction_screen.dart`

- [ ] **Step 1: Write the implementation**

Create `lib/features/message_capture/ocr_feedback/ocr_correction_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/app_info.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import 'ocr_correction_export.dart';

/// Settings > Message Capture > OCR corrections. See
/// docs/superpowers/specs/2026-08-14-ocr-corrections-design.md.
class OcrCorrectionScreen extends ConsumerWidget {
  const OcrCorrectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pending =
        ref.watch(pendingOcrCorrectionsProvider).valueOrNull ?? const [];
    final sent = ref.watch(sentOcrCorrectionsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('OCR corrections')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/more/capture/ocr-feedback/new'),
        icon: const Icon(Icons.add),
        label: const Text('Test a screenshot'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Optional and entirely on-device. Pick a screenshot to see '
                "what OCR reads and mark whether it's right. Sharing a "
                'correction hands over only the extracted text — never the '
                'image — to ${AppInfo.feedbackEmail}, and only if you tap '
                'the button below.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (pending.isEmpty && sent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No corrections yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          for (final row in pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Slidable(
                key: ValueKey(row.id),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (_) =>
                          ref.read(dbProvider).deleteOcrCorrection(row.id),
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: Colors.white,
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                    ),
                  ],
                ),
                child: _CorrectionTile(row: row),
              ),
            ),
          if (sent.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
              child: Text(
                'SENT',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            for (final row in sent)
              Opacity(
                opacity: 0.6,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CorrectionTile(row: row),
                ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: pending.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ids = pending.map((r) => r.id).toList();
                    try {
                      await sendOcrCorrections(pending);
                    } catch (_) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Couldn't open anything to send this — your "
                              'corrections are still saved, try again later.',
                            ),
                          ),
                        );
                      return;
                    }
                    await ref.read(dbProvider).markOcrCorrectionsSent(ids);
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(content: Text('Opened for sending')),
                      );
                  },
                  child: Text(
                    'Send ${pending.length} correction'
                    '${pending.length == 1 ? '' : 's'}',
                  ),
                ),
              ),
            ),
    );
  }
}

class _CorrectionTile extends StatelessWidget {
  const _CorrectionTile({required this.row});

  final OcrCorrectionRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(
          row.wasCorrect ? Icons.check_circle_outline : Icons.error_outline,
          color: row.wasCorrect
              ? theme.colorScheme.primary
              : theme.colorScheme.error,
        ),
        title: Text(row.appLabel),
        subtitle: Text(
          row.rawOcrText.split('\n').first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/message_capture/ocr_feedback/ocr_correction_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/message_capture/ocr_feedback/ocr_correction_screen.dart
git commit -m "feat: add the OCR corrections list screen"
```

---

### Task 6: Settings entry point and routing

**Files:**
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/core/routing/app_router.dart`

- [ ] **Step 1: Add the Settings row**

In `lib/features/settings/settings_screen.dart`, inside the "Message Capture" section's `Card` (around line 309-324), change:

```dart
          _sectionLabel(context, 'Message Capture'),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.sms_outlined),
              title: const Text('Bank-SMS auto-capture'),
              subtitle: Text(
                'Coming soon — removed for now so the app installs without a '
                'Play Protect block.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/more/capture'),
            ),
          ),
```

to:

```dart
          _sectionLabel(context, 'Message Capture'),
          Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.sms_outlined),
                  title: const Text('Bank-SMS auto-capture'),
                  subtitle: Text(
                    'Coming soon — removed for now so the app installs '
                    'without a Play Protect block.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/more/capture'),
                ),
                Divider(height: 1, indent: 60, color: cs.outline),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.rate_review_outlined),
                  title: const Text('OCR corrections'),
                  subtitle: Text(
                    'Optional — test a payment screenshot and help improve '
                    'OCR by sharing what you find, entirely on your terms.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/more/capture/ocr-feedback'),
                ),
              ],
            ),
          ),
```

- [ ] **Step 2: Add the routes**

In `lib/core/routing/app_router.dart`, add the imports near the other `message_capture` imports (around line 19-20):

```dart
import '../../features/message_capture/message_capture_screen.dart';
import '../../features/message_capture/ocr_feedback/ocr_correction_capture_screen.dart';
import '../../features/message_capture/ocr_feedback/ocr_correction_screen.dart';
import '../../features/message_capture/review_inbox_screen.dart';
```

Change the `capture` route (around line 168-172) from:

```dart
                GoRoute(
                  path: 'capture',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const MessageCaptureScreen(),
                ),
```

to:

```dart
                GoRoute(
                  path: 'capture',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const MessageCaptureScreen(),
                  routes: [
                    GoRoute(
                      path: 'ocr-feedback',
                      parentNavigatorKey: _rootKey,
                      builder: (_, _) => const OcrCorrectionScreen(),
                      routes: [
                        GoRoute(
                          path: 'new',
                          parentNavigatorKey: _rootKey,
                          builder: (_, _) => const OcrCorrectionCaptureScreen(),
                        ),
                      ],
                    ),
                  ],
                ),
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/features/settings/settings_screen.dart lib/core/routing/app_router.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/settings_screen.dart lib/core/routing/app_router.dart
git commit -m "feat: wire up the OCR corrections entry point and routes"
```

---

### Task 7: Widget test for the list screen

**Files:**
- Test: `test/ocr_correction_screen_test.dart`

- [ ] **Step 1: Write the test**

Create `test/ocr_correction_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/message_capture/ocr_feedback/ocr_correction_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: const MaterialApp(home: OcrCorrectionScreen()),
    ),
  );

  testWidgets('shows an empty state with no corrections', (tester) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('No corrections yet'), findsOneWidget);
    expect(find.textContaining('Send'), findsNothing);
  });

  testWidgets('lists a pending correction and offers Send', (tester) async {
    await db.addOcrCorrection(
      appLabel: 'PhonePe',
      country: 'India',
      rawOcrText: 'Payment successful\n₹500\nTo John Doe',
      wasCorrect: false,
      extractedAmount: '500',
      extractedPayee: 'John Doe',
      correctedPayee: 'John D.',
    );

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('PhonePe'), findsOneWidget);
    expect(find.textContaining('Send 1 correction'), findsOneWidget);
  });

  testWidgets('a sent correction is listed separately and not resendable', (
    tester,
  ) async {
    final id = await db.addOcrCorrection(
      appLabel: 'Google Pay',
      rawOcrText: 'x',
      wasCorrect: true,
    );
    await db.markOcrCorrectionsSent([id]);

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('SENT'), findsOneWidget);
    expect(find.textContaining('Send'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test**

Run: `flutter test test/ocr_correction_screen_test.dart`
Expected: PASS, 3 tests. (No mock is needed for `file_picker`/`url_launcher`/`share_plus` here — this codebase's existing tests don't mock those platform channels either, since that boundary isn't unit-testable; the capture screen's pick step and the send button's actual transport stay a manual, on-device check, same as `ReceiptStorage.pickAndStore` today.)

- [ ] **Step 3: Commit**

```bash
git add test/ocr_correction_screen_test.dart
git commit -m "test: cover the OCR corrections list screen"
```

---

### Task 8: Documentation — privacy policy and changelog

**Files:**
- Modify: `website/privacy.html`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update the privacy policy effective date**

In `website/privacy.html`, change:

```html
        <b>Effective date:</b> 12 July 2026 &nbsp;·&nbsp;
```

to:

```html
        <b>Effective date:</b> 14 August 2026 &nbsp;·&nbsp;
```

- [ ] **Step 2: Add the new disclosure section**

In `website/privacy.html`, insert a new `<h2>` section right after the closing `</ul>` of the "Backups and exports" section and before `<h2>Data retention and deletion</h2>`:

```html
      <h2>OCR corrections (optional)</h2>
      <p>
        Settings → Message Capture → OCR corrections lets you test a payment-app
        screenshot against XPENC's on-device OCR and mark whether it read
        correctly. This does nothing unless you open that screen yourself.
      </p>
      <ul>
        <li>
          Screenshots are processed on-device only — the image itself is never
          stored or included in anything you send, only the correction you
          choose to keep.
        </li>
        <li>
          Tapping "Send" hands the extracted text — never the image — to your
          own email app or the Android share sheet, the same mechanism used
          for backup exports above. XPENC's own code makes no network call;
          you choose where the text goes, the same way you choose where an
          exported backup goes.
        </li>
        <li>
          What's sent is a small JSON snippet: the payment app and country you
          labeled it with, the raw recognised text, the amount/direction/payee/
          reference XPENC's parser guessed from it, and what (if anything) you
          corrected. No account balances, transaction history or other
          financial records are included.
        </li>
      </ul>
```

- [ ] **Step 3: Add the changelog entries**

In `CHANGELOG.md`, insert a new section above `## [1.4.2] — 2026-08-13`:

```markdown
## [Unreleased]

### Added
- **OCR corrections** — Settings → Message Capture → OCR corrections lets you
  test a payment-app screenshot against the real on-device OCR+parser
  pipeline, mark whether it read correctly, and optionally send the
  correction (extracted text only, never the image) to help improve parsing
  for more apps and countries over time.

### Changed
- Screenshot OCR now uses Tesseract instead of Google ML Kit — ML Kit's
  trained-model blobs are proprietary even in the bundled, no-Play-Services
  form, which blocked F-Droid distribution (#57). Fully on-device either way;
  no behavior change for existing users beyond OCR accuracy.

```

- [ ] **Step 4: Commit**

```bash
git add website/privacy.html CHANGELOG.md
git commit -m "docs: disclose the OCR corrections flow and changelog it"
```

---

## Final verification

- [ ] Run the full test suite: `flutter test`
  Expected: all tests pass (395 pre-existing + 5 new = 400).
- [ ] Run the full analyzer: `flutter analyze`
  Expected: `No issues found!`
- [ ] Manually, on a device: Settings → Message Capture → OCR corrections →
  Test a screenshot → confirm a real payment screenshot round-trips through
  OCR, the fields are editable, saving works, and the Send button opens an
  email/share sheet with the expected JSON. This step cannot be automated —
  no Android device is available in a plain CI/dev-container environment.
