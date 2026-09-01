import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'csv_import.dart';

/// Preset colours assigned round-robin to categories the importer creates
/// on the fly — same palette `CategoriesScreen` offers by hand.
const _presetColors = <int>[
  0xFF16A34A,
  0xFF2563EB,
  0xFFDC2626,
  0xFFA855F7,
  0xFFF97316,
  0xFF0EA5E9,
  0xFF78716C,
  0xFFEC4899,
];

/// Import transactions from a bank-exported CSV statement. See
/// `csv_import.dart` for the parsing/mapping logic this screen is a thin
/// wrapper around, and GitHub #17.
class CsvImportScreen extends ConsumerStatefulWidget {
  const CsvImportScreen({super.key});

  @override
  ConsumerState<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends ConsumerState<CsvImportScreen> {
  String? _fileName;
  List<dynamic>? _headers;
  List<List<dynamic>>? _dataRows;

  int? _dateColumn;
  int? _noteColumn;
  int? _categoryColumn;
  bool _twoColumnMode = false;
  int? _amountColumn;
  int? _debitColumn;
  int? _creditColumn;

  int? _accountId;
  bool _busy = false;
  _ImportSummary? _summary;

  CsvColumnMapping? get _mapping {
    final dateColumn = _dateColumn;
    if (dateColumn == null) return null;
    if (_twoColumnMode) {
      if (_debitColumn == null && _creditColumn == null) return null;
      return CsvColumnMapping(
        dateColumn: dateColumn,
        noteColumn: _noteColumn,
        categoryColumn: _categoryColumn,
        debitColumn: _debitColumn,
        creditColumn: _creditColumn,
      );
    }
    if (_amountColumn == null) return null;
    return CsvColumnMapping(
      dateColumn: dateColumn,
      noteColumn: _noteColumn,
      categoryColumn: _categoryColumn,
      amountColumn: _amountColumn,
    );
  }

  Future<void> _pickFile() async {
    final messenger = ScaffoldMessenger.of(context);
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't open a file: $e")));
      return;
    }
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.single;
    String content;
    try {
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        throw const FormatException('empty selection');
      }
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text("Couldn't read that file.")),
        );
      return;
    }

    final rows = Csv().decode(content);
    if (rows.length < 2) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('That file has no data rows below the header.'),
          ),
        );
      return;
    }

    final headers = rows.first;
    final guess = guessMapping(headers);
    setState(() {
      _fileName = file.name;
      _headers = headers;
      _dataRows = rows.skip(1).toList();
      _summary = null;
      _dateColumn = guess?.dateColumn;
      _noteColumn = guess?.noteColumn;
      _categoryColumn = guess?.categoryColumn;
      _twoColumnMode = guess?.isTwoColumn ?? false;
      _amountColumn = guess?.amountColumn;
      _debitColumn = guess?.debitColumn;
      _creditColumn = guess?.creditColumn;
    });
  }

  Future<void> _import() async {
    final mapping = _mapping;
    final accountId = _accountId;
    final rows = _dataRows;
    if (mapping == null || accountId == null || rows == null) return;

    setState(() => _busy = true);
    final db = ref.read(dbProvider);
    var imported = 0;
    var skippedNoDate = 0;
    var skippedNoAmount = 0;
    var skippedOther = 0;
    var categoriesCreated = 0;

    // Seeded once from the current categories and grown in place as unmapped
    // names turn up, so repeats of the same name within one file share a
    // single new category instead of creating a duplicate per row.
    final categoryIdsByKind = {
      TxType.expense: {
        for (final c in await db.watchCategories(CategoryKind.expense).first)
          c.name.trim().toLowerCase(): c.id,
      },
      TxType.income: {
        for (final c in await db.watchCategories(CategoryKind.income).first)
          c.name.trim().toLowerCase(): c.id,
      },
    };

    for (final raw in rows) {
      final row = parseCsvRow(raw, mapping);
      if (row.date == null) {
        skippedNoDate++;
        continue;
      }
      final amount = row.amount;
      if (amount == null) {
        skippedNoAmount++;
        continue;
      }
      final type = amount.isNegative ? TxType.expense : TxType.income;

      int? categoryId;
      final categoryName = row.category;
      if (categoryName != null) {
        final categoryIds = categoryIdsByKind[type]!;
        final key = categoryName.toLowerCase();
        categoryId = categoryIds[key];
        if (categoryId == null) {
          categoryId = await db.addCategory(
            name: categoryName,
            kind: type == TxType.expense
                ? CategoryKind.expense
                : CategoryKind.income,
            colorValue: _presetColors[categoriesCreated % _presetColors.length],
            iconKey: AppIcons.allKeys.first,
          );
          categoryIds[key] = categoryId;
          categoriesCreated++;
        }
      }

      try {
        await db.addTransaction(
          type: type,
          amount: amount.abs,
          accountId: accountId,
          categoryId: categoryId,
          date: row.date!,
          note: row.note,
        );
        imported++;
      } on ArgumentError {
        skippedOther++;
      }
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _summary = _ImportSummary(
        imported: imported,
        skippedNoDate: skippedNoDate,
        skippedNoAmount: skippedNoAmount,
        skippedOther: skippedOther,
        categoriesCreated: categoriesCreated,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final headers = _headers;
    final summary = _summary;

    return Scaffold(
      appBar: AppBar(title: const Text('Import CSV')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (summary != null)
            _SummaryCard(summary: summary, fileName: _fileName!)
          else if (headers == null)
            _PickFileCard(busy: _busy, onPick: _pickFile)
          else
            _MappingForm(
              fileName: _fileName!,
              headers: headers,
              rowCount: _dataRows!.length,
              dateColumn: _dateColumn,
              noteColumn: _noteColumn,
              categoryColumn: _categoryColumn,
              twoColumnMode: _twoColumnMode,
              amountColumn: _amountColumn,
              debitColumn: _debitColumn,
              creditColumn: _creditColumn,
              accountId: _accountId,
              busy: _busy,
              canImport: _mapping != null && _accountId != null,
              previewRows: switch (_mapping) {
                null => const <CsvImportRow>[],
                final mapping =>
                  _dataRows!
                      .take(3)
                      .map((r) => parseCsvRow(r, mapping))
                      .toList(),
              },
              onDateColumnChanged: (v) => setState(() => _dateColumn = v),
              onNoteColumnChanged: (v) => setState(() => _noteColumn = v),
              onCategoryColumnChanged: (v) =>
                  setState(() => _categoryColumn = v),
              onTwoColumnModeChanged: (v) => setState(() => _twoColumnMode = v),
              onAmountColumnChanged: (v) => setState(() => _amountColumn = v),
              onDebitColumnChanged: (v) => setState(() => _debitColumn = v),
              onCreditColumnChanged: (v) => setState(() => _creditColumn = v),
              onAccountChanged: (v) => setState(() => _accountId = v),
              onImport: _import,
              onPickDifferentFile: _pickFile,
            ),
        ],
      ),
    );
  }
}

class _ImportSummary {
  const _ImportSummary({
    required this.imported,
    required this.skippedNoDate,
    required this.skippedNoAmount,
    required this.skippedOther,
    required this.categoriesCreated,
  });

  final int imported;
  final int skippedNoDate;
  final int skippedNoAmount;
  final int skippedOther;
  final int categoriesCreated;

  int get skipped => skippedNoDate + skippedNoAmount + skippedOther;
}

class _PickFileCard extends StatelessWidget {
  const _PickFileCard({required this.busy, required this.onPick});

  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.table_chart_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Pick a bank-exported .csv statement. Most banks\' formats '
              '(a signed Amount column, or separate Withdrawal/Deposit '
              "columns) are detected automatically — you'll get a chance to "
              'check the mapping before anything is imported.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: busy ? null : onPick,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Choose CSV file'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MappingForm extends StatelessWidget {
  const _MappingForm({
    required this.fileName,
    required this.headers,
    required this.rowCount,
    required this.dateColumn,
    required this.noteColumn,
    required this.categoryColumn,
    required this.twoColumnMode,
    required this.amountColumn,
    required this.debitColumn,
    required this.creditColumn,
    required this.accountId,
    required this.busy,
    required this.canImport,
    required this.previewRows,
    required this.onDateColumnChanged,
    required this.onNoteColumnChanged,
    required this.onCategoryColumnChanged,
    required this.onTwoColumnModeChanged,
    required this.onAmountColumnChanged,
    required this.onDebitColumnChanged,
    required this.onCreditColumnChanged,
    required this.onAccountChanged,
    required this.onImport,
    required this.onPickDifferentFile,
  });

  final String fileName;
  final List<dynamic> headers;
  final int rowCount;
  final int? dateColumn;
  final int? noteColumn;
  final int? categoryColumn;
  final bool twoColumnMode;
  final int? amountColumn;
  final int? debitColumn;
  final int? creditColumn;
  final int? accountId;
  final bool busy;
  final bool canImport;
  final List<CsvImportRow> previewRows;
  final ValueChanged<int?> onDateColumnChanged;
  final ValueChanged<int?> onNoteColumnChanged;
  final ValueChanged<int?> onCategoryColumnChanged;
  final ValueChanged<bool> onTwoColumnModeChanged;
  final ValueChanged<int?> onAmountColumnChanged;
  final ValueChanged<int?> onDebitColumnChanged;
  final ValueChanged<int?> onCreditColumnChanged;
  final ValueChanged<int?> onAccountChanged;
  final VoidCallback onImport;
  final VoidCallback onPickDifferentFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer(
      builder: (context, ref, _) {
        final accounts =
            (ref.watch(balanceAccountsProvider).valueOrNull ?? const [])
                .where((a) => a.type != AccountType.goal)
                .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$fileName · $rowCount rows',
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : onPickDifferentFile,
                  child: const Text('Change file'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: accountId,
              decoration: const InputDecoration(
                labelText: 'Import into account',
              ),
              items: [
                for (final a in accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: busy ? null : onAccountChanged,
            ),
            const SizedBox(height: 20),
            Text('Columns', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _ColumnDropdown(
              label: 'Date',
              headers: headers,
              value: dateColumn,
              allowNone: false,
              onChanged: busy ? null : onDateColumnChanged,
            ),
            const SizedBox(height: 12),
            _ColumnDropdown(
              label: 'Note / description (optional)',
              headers: headers,
              value: noteColumn,
              allowNone: true,
              onChanged: busy ? null : onNoteColumnChanged,
            ),
            const SizedBox(height: 12),
            _ColumnDropdown(
              label: 'Category (optional)',
              headers: headers,
              value: categoryColumn,
              allowNone: true,
              onChanged: busy ? null : onCategoryColumnChanged,
            ),
            const SizedBox(height: 4),
            Text(
              "Matched against your existing categories by name — anything "
              "that doesn't match is created automatically.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Signed amount')),
                ButtonSegment(value: true, label: Text('Debit & credit')),
              ],
              selected: {twoColumnMode},
              showSelectedIcon: false,
              onSelectionChanged: busy
                  ? null
                  : (s) => onTwoColumnModeChanged(s.first),
            ),
            const SizedBox(height: 12),
            if (twoColumnMode) ...[
              _ColumnDropdown(
                label: 'Debit / withdrawal',
                headers: headers,
                value: debitColumn,
                allowNone: true,
                onChanged: busy ? null : onDebitColumnChanged,
              ),
              const SizedBox(height: 12),
              _ColumnDropdown(
                label: 'Credit / deposit',
                headers: headers,
                value: creditColumn,
                allowNone: true,
                onChanged: busy ? null : onCreditColumnChanged,
              ),
            ] else
              _ColumnDropdown(
                label: 'Amount (negative = expense, positive = income)',
                headers: headers,
                value: amountColumn,
                allowNone: false,
                onChanged: busy ? null : onAmountColumnChanged,
              ),
            if (previewRows.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Preview', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < previewRows.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _PreviewRow(row: previewRows[i]),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy || !canImport ? null : onImport,
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Import $rowCount rows'),
            ),
          ],
        );
      },
    );
  }
}

class _ColumnDropdown extends StatelessWidget {
  const _ColumnDropdown({
    required this.label,
    required this.headers,
    required this.value,
    required this.allowNone,
    required this.onChanged,
  });

  final String label;
  final List<dynamic> headers;
  final int? value;
  final bool allowNone;
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        if (allowNone) const DropdownMenuItem(value: null, child: Text('None')),
        for (var i = 0; i < headers.length; i++)
          DropdownMenuItem(value: i, child: Text('${headers[i]}')),
      ],
      onChanged: onChanged,
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.row});

  final CsvImportRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = row.date != null && row.amount != null;
    final subtitle = [
      if (row.note != null) row.note!,
      if (row.category != null) '#${row.category}',
    ].join(' · ');
    return ListTile(
      dense: true,
      leading: Icon(
        ok ? Icons.check_circle_outline : Icons.error_outline,
        color: ok ? theme.colorScheme.primary : theme.colorScheme.error,
        size: 20,
      ),
      title: Text(
        row.date == null
            ? 'Unrecognised date'
            : row.date!.toIso8601String().split('T').first,
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Text(
        row.amount == null ? '—' : MoneyFormat.symbol(row.amount!),
        style: TextStyle(
          color: row.amount == null
              ? theme.colorScheme.error
              : (row.amount!.isNegative
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.fileName});

  final _ImportSummary summary;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '${summary.imported} transaction'
              '${summary.imported == 1 ? '' : 's'} imported from $fileName',
              style: theme.textTheme.titleMedium,
            ),
            if (summary.categoriesCreated > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${summary.categoriesCreated} new categor'
                '${summary.categoriesCreated == 1 ? 'y' : 'ies'} created from '
                "the file's category column.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (summary.skipped > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${summary.skipped} row${summary.skipped == 1 ? '' : 's'} '
                'skipped'
                '${summary.skippedNoDate > 0 ? ' — ${summary.skippedNoDate} with no readable date' : ''}'
                '${summary.skippedNoAmount > 0 ? ' — ${summary.skippedNoAmount} with no readable amount' : ''}'
                '${summary.skippedOther > 0 ? ' — ${summary.skippedOther} rejected' : ''}.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
