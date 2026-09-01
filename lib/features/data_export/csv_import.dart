import 'package:intl/intl.dart';

import '../../core/money.dart';

/// Which CSV column feeds which field, and how the amount is split across
/// columns. Two shapes cover the large majority of Indian bank exports:
/// a single signed column, or separate Withdrawal/Deposit columns (what
/// SBI, HDFC, ICICI and most others actually export) — see GitHub #17.
class CsvColumnMapping {
  const CsvColumnMapping({
    required this.dateColumn,
    this.noteColumn,
    this.categoryColumn,
    this.amountColumn,
    this.debitColumn,
    this.creditColumn,
  }) : assert(
         amountColumn != null || debitColumn != null || creditColumn != null,
         'Need either a signed amount column, or a debit/credit column.',
       );

  final int dateColumn;
  final int? noteColumn;

  /// Free-text category name — matched case-insensitively against the
  /// app's existing categories (of whichever kind the row's amount sign
  /// implies), or created fresh when nothing matches. See GitHub #96.
  final int? categoryColumn;

  /// Single-column mode: negative = expense, positive = income.
  final int? amountColumn;

  /// Two-column mode: money out / money in. Either may be present alone —
  /// a statement missing one of the two just never produces that direction.
  final int? debitColumn;
  final int? creditColumn;

  bool get isTwoColumn => amountColumn == null;
}

/// One row, mapped but not yet validated — `date`/`amount` are null when
/// that cell couldn't be read, which the caller treats as a skipped row.
class CsvImportRow {
  const CsvImportRow({this.date, this.amount, this.note, this.category});

  final DateTime? date;

  /// Signed: negative = expense, positive = income. Never zero — a row
  /// whose debit and credit cells are both blank/zero parses as null.
  final Money? amount;
  final String? note;

  /// Raw category text from the file, unresolved — the importer still has
  /// to match/create an actual category against it.
  final String? category;
}

/// Header names this app's own CSV export uses (`transactionsCsv`), plus
/// the common variants real bank statements use for the same idea. Matched
/// case-insensitively against the file's actual header row.
const _dateHeaders = ['date', 'txn date', 'transaction date', 'value date'];
const _noteHeaders = [
  'note',
  'narration',
  'description',
  'particulars',
  'details',
  'remarks',
];
const _categoryHeaders = ['category', 'category name', 'tag', 'tags', 'label'];
const _amountHeaders = ['amount', 'transaction amount', 'amt'];
const _debitHeaders = [
  'debit',
  'withdrawal',
  'withdrawal amt',
  'withdrawal amt.',
  'withdrawal amount',
  'dr',
];
const _creditHeaders = [
  'credit',
  'deposit',
  'deposit amt',
  'deposit amt.',
  'deposit amount',
  'cr',
];

int? _findColumn(List<dynamic> headers, List<String> candidates) {
  for (var i = 0; i < headers.length; i++) {
    final h = headers[i]?.toString().trim().toLowerCase() ?? '';
    if (candidates.contains(h)) return i;
  }
  return null;
}

/// A best-effort starting mapping from the file's own header row — always
/// editable afterward, never trusted blindly. Null when no date column (the
/// one field every shape needs) could be found at all.
CsvColumnMapping? guessMapping(List<dynamic> headers) {
  final dateCol = _findColumn(headers, _dateHeaders);
  if (dateCol == null) return null;

  final debitCol = _findColumn(headers, _debitHeaders);
  final creditCol = _findColumn(headers, _creditHeaders);
  final amountCol = (debitCol == null && creditCol == null)
      ? _findColumn(headers, _amountHeaders)
      : null;
  if (debitCol == null && creditCol == null && amountCol == null) return null;

  return CsvColumnMapping(
    dateColumn: dateCol,
    noteColumn: _findColumn(headers, _noteHeaders),
    categoryColumn: _findColumn(headers, _categoryHeaders),
    amountColumn: amountCol,
    debitColumn: debitCol,
    creditColumn: creditCol,
  );
}

/// Bank statements spell dates a dozen different ways — this tries the
/// shapes actually seen in the wild before giving up. `parseStrict` so
/// `"9"` never silently becomes a date via a partial pattern match.
final _dateFormats = [
  DateFormat('dd/MM/yyyy'),
  DateFormat('dd-MM-yyyy'),
  DateFormat('dd/MM/yy'),
  DateFormat('dd-MM-yy'),
  DateFormat('yyyy-MM-dd'),
  DateFormat('yyyy/MM/dd'),
  DateFormat('MM/dd/yyyy'),
  DateFormat('dd MMM yyyy'),
  DateFormat('dd-MMM-yyyy'),
  DateFormat('d MMM yyyy'),
];

/// A `yy` pattern parses "26" as year 26 AD, not 2026 — `intl` applies no
/// pivot-century inference of its own. Same fix, same reasoning as
/// `BackupService.dateFromBackupFileName`: read 0-99 as 2000-2099, which
/// covers every plausible statement date and never collides with a real
/// 4-digit year (those are always >= 100 already).
DateTime _fixTwoDigitYear(DateTime d) =>
    d.year < 100 ? DateTime(d.year + 2000, d.month, d.day) : d;

DateTime? parseCsvDate(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  for (final format in _dateFormats) {
    try {
      return _fixTwoDigitYear(format.parseStrict(text));
    } on FormatException {
      continue;
    }
  }
  return DateTime.tryParse(text);
}

String? _cell(List<dynamic> row, int? column) {
  if (column == null || column >= row.length) return null;
  final value = row[column]?.toString().trim();
  return (value == null || value.isEmpty) ? null : value;
}

CsvImportRow parseCsvRow(List<dynamic> row, CsvColumnMapping mapping) {
  final dateText = _cell(row, mapping.dateColumn);
  final date = dateText == null ? null : parseCsvDate(dateText);

  Money? amount;
  if (mapping.isTwoColumn) {
    final debit = _cell(row, mapping.debitColumn);
    final credit = _cell(row, mapping.creditColumn);
    final debitAmount = debit == null ? null : Money.tryParse(debit)?.abs;
    final creditAmount = credit == null ? null : Money.tryParse(credit)?.abs;
    if (creditAmount != null && creditAmount.isPositive) {
      amount = creditAmount;
    } else if (debitAmount != null && debitAmount.isPositive) {
      amount = Money(-debitAmount.paise);
    }
  } else {
    final text = _cell(row, mapping.amountColumn);
    final parsed = text == null ? null : Money.tryParse(text);
    amount = (parsed == null || parsed.isZero) ? null : parsed;
  }

  return CsvImportRow(
    date: date,
    amount: amount,
    note: _cell(row, mapping.noteColumn),
    category: _cell(row, mapping.categoryColumn),
  );
}
