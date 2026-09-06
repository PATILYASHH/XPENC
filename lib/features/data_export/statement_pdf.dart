import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/branding/app_info.dart';
import '../../core/currency.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/tables.dart';

/// Builds the two statement PDFs — an account/cash statement and a budget
/// statement.
///
/// Every amount renders as a bare number (see [MoneyFormat.bare]) with the
/// currency code spelled out once at the top, rather than a symbol. PDF's
/// built-in fonts don't reliably carry currency-symbol glyphs (₹ included),
/// and fixing that would mean either a network font fetch or a bundled font
/// asset — neither fits an app that is otherwise fully offline. For the same
/// reason, every string here sticks to plain ASCII (a hyphen, not an
/// em-dash).

Future<Uint8List> buildAccountStatementPdf({
  required AccountRow account,
  required AccountStatement statement,
  required DateTime start,
  required DateTime end,
}) async {
  final doc = pw.Document(title: '${account.name} statement');
  // This account's own currency, not the app-wide parent one — a foreign-
  // currency account's statement must state (and format) figures in the
  // currency they actually happened in. Null means the parent currency,
  // same convention as [Accounts.currencyCode] itself.
  final currency = account.currencyCode == null
      ? MoneyFormat.currency
      : currencyForCode(account.currencyCode!);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => _pageHeader('Account Statement'),
      footer: _pageFooter,
      build: (context) => [
        _kv('Account', account.name),
        _kv('Type', _accountTypeLabel(account.type)),
        if (_bankLine(account) case final line?) _kv('Bank', line),
        _kv('Period', '${_dateLabel(start)} to ${_dateLabel(end)}'),
        _kv('Currency', currency.code),
        pw.SizedBox(height: 12),
        _kv(
          'Opening balance',
          MoneyFormat.bareIn(statement.openingBalance, currency),
        ),
        pw.SizedBox(height: 12),
        if (statement.lines.isEmpty)
          pw.Text(
            'No transactions in this period.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const [
              'Date',
              'Description',
              'Debit',
              'Credit',
              'Balance',
            ],
            data: [
              for (final line in statement.lines)
                [
                  _dateLabel(line.date),
                  line.description,
                  line.debit.isZero
                      ? ''
                      : MoneyFormat.bareIn(line.debit, currency),
                  line.credit.isZero
                      ? ''
                      : MoneyFormat.bareIn(line.credit, currency),
                  MoneyFormat.bareIn(line.balance, currency),
                ],
            ],
            cellAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          ),
        pw.SizedBox(height: 12),
        _kv(
          'Closing balance',
          MoneyFormat.bareIn(statement.closingBalance, currency),
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> buildBudgetStatementPdf({
  required DateTime month,
  required List<BudgetStatementLine> lines,
}) async {
  final doc = pw.Document(title: 'Budget statement ${_monthLabel(month)}');

  // A child's budget is a sub-allocation within its parent's cap, and a
  // budgeted parent's `spent` already rolls up every child's — when the
  // parent is budgeted too, counting the child's line again would double
  // both totals (Food 2000 + Junk food 1000 + Dinner 1000 must read as
  // 2000, not 4000).
  final budgetedCategoryIds = {for (final l in lines) l.category.id};
  var totalBudgeted = const Money.zero();
  var totalSpent = const Money.zero();
  for (final l in lines) {
    final parentId = l.category.parentId;
    if (parentId != null && budgetedCategoryIds.contains(parentId)) continue;
    totalBudgeted += l.budgeted;
    totalSpent += l.spent;
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => _pageHeader('Budget Statement'),
      footer: _pageFooter,
      build: (context) => [
        _kv('Month', _monthLabel(month)),
        _kv('Currency', MoneyFormat.currency.code),
        pw.SizedBox(height: 12),
        if (lines.isEmpty)
          pw.Text(
            'No budgets set for this month.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Category', 'Budgeted', 'Spent', 'Remaining'],
            data: [
              for (final l in lines)
                [
                  l.category.name,
                  MoneyFormat.bare(l.budgeted),
                  MoneyFormat.bare(l.spent),
                  _remainingLabel(l.budgeted - l.spent),
                ],
            ],
            cellAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          ),
        pw.SizedBox(height: 16),
        pw.Divider(color: PdfColors.grey400),
        _kv('Total budgeted', MoneyFormat.bare(totalBudgeted)),
        _kv('Total spent', MoneyFormat.bare(totalSpent)),
        _kv('Overall', _remainingLabel(totalBudgeted - totalSpent)),
        pw.SizedBox(height: 12),
        pw.Text(
          'Budgets only count expenses. Transfers between your own accounts '
          'are never counted.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    ),
  );

  return doc.save();
}

/// One category's budget line plus every expense in it for a month — the PDF
/// behind the Budget Detail page's download action.
Future<Uint8List> buildCategoryStatementPdf({
  required DateTime month,
  required CategoryStatement statement,
}) async {
  final category = statement.category;
  final remaining = statement.budgeted - statement.spent;
  final doc = pw.Document(title: '${category.name} statement');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => _pageHeader('Budget Statement'),
      footer: _pageFooter,
      build: (context) => [
        _kv('Category', category.name),
        _kv('Period', _monthLabel(month)),
        _kv('Currency', MoneyFormat.currency.code),
        pw.SizedBox(height: 12),
        _kv(
          'Budgeted',
          statement.budgeted.isZero
              ? 'No budget set'
              : MoneyFormat.bare(statement.budgeted),
        ),
        _kv('Spent', MoneyFormat.bare(statement.spent)),
        if (!statement.budgeted.isZero)
          _kv('Remaining', _remainingLabel(remaining)),
        pw.SizedBox(height: 12),
        if (statement.lines.isEmpty)
          pw.Text(
            'No transactions in this period.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Description', 'Amount'],
            data: [
              for (final l in statement.lines)
                [
                  _dateLabel(l.date),
                  l.isSplit ? '${l.description} (split)' : l.description,
                  MoneyFormat.bare(l.amount),
                ],
            ],
            cellAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
            },
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          ),
      ],
    ),
  );

  return doc.save();
}

/// Every account's transactions for a period, merged date-wise rather than
/// grouped by account — a real bank-style combined statement. No running
/// total: a single balance across accounts of different kinds (cash owed vs.
/// credit owed) would be misleading, so each row stands on its own.
Future<Uint8List> buildCombinedStatementPdf({
  required DateTime start,
  required DateTime end,
  required List<CombinedStatementLine> lines,
}) async {
  final doc = pw.Document(title: 'Combined statement');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => _pageHeader('Combined Statement'),
      footer: _pageFooter,
      build: (context) => [
        _kv('Period', '${_dateLabel(start)} to ${_dateLabel(end)}'),
        _kv('Currency', MoneyFormat.currency.code),
        pw.SizedBox(height: 12),
        if (lines.isEmpty)
          pw.Text(
            'No transactions in this period.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const [
              'Date',
              'Account',
              'Type',
              'Category / Note',
              'Amount',
            ],
            data: [
              for (final l in lines)
                [
                  _dateLabel(l.date),
                  l.accountName,
                  l.type,
                  l.description,
                  MoneyFormat.bare(l.amount),
                ],
            ],
            cellAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerRight,
            },
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Transfers move money between your own accounts and are never '
          'counted as income or expense.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    ),
  );

  return doc.save();
}

// ── Shared layout helpers ────────────────────────────────────────────────────

pw.Widget _pageHeader(String title) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(
      AppInfo.name,
      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 2),
    pw.Text(
      title,
      style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700),
    ),
    pw.SizedBox(height: 4),
    pw.Text(
      'Generated ${_dateLabel(DateTime.now())}',
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
    ),
    pw.SizedBox(height: 14),
  ],
);

pw.Widget _pageFooter(pw.Context context) => pw.Align(
  alignment: pw.Alignment.centerRight,
  child: pw.Text(
    'Page ${context.pageNumber} of ${context.pagesCount}',
    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
  ),
);

pw.Widget _kv(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 2),
  child: pw.Row(
    children: [
      pw.SizedBox(
        width: 110,
        child: pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ),
      pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
    ],
  ),
);

String _remainingLabel(Money remaining) => remaining.isNegative
    ? 'Over by ${MoneyFormat.bare(remaining.abs)}'
    : MoneyFormat.bare(remaining);

String _dateLabel(DateTime d) => DateFormat('d MMM yyyy').format(d);

String _monthLabel(DateTime d) => DateFormat('MMMM yyyy').format(d);

String _accountTypeLabel(AccountType type) => switch (type) {
  AccountType.cash => 'Cash',
  AccountType.bank => 'Bank',
  AccountType.card => 'Card',
  AccountType.payLater => 'Pay later',
  AccountType.prepaidBalance => 'Prepaid Balance',
  AccountType.goal => 'Goal',
  AccountType.loan => 'Loan',
};

/// "HDFC ...1234" — whichever parts the account carries.
String? _bankLine(AccountRow a) {
  final parts = <String>[];
  if (a.bankName != null && a.bankName!.isNotEmpty) parts.add(a.bankName!);
  if (a.last4 != null && a.last4!.isNotEmpty) parts.add('...${a.last4}');
  return parts.isEmpty ? null : parts.join(' ');
}
