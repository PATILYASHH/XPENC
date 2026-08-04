import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/branding/app_info.dart';
import '../../core/money.dart';
import '../../data/database.dart';

/// Income & Expense Report: a summary PDF for whatever period the Stats
/// screen is showing (a month or a calendar year) — category breakdown plus
/// the same headline numbers Stats shows on screen. Distinct from the
/// per-account and per-budget statements in `statement_pdf.dart`.
///
/// Same constraints as those: bare numbers (no currency symbol — see the
/// note in `statement_pdf.dart`), plain ASCII throughout.
Future<Uint8List> buildIncomeExpenseReportPdf({
  required String periodLabel,
  required Money income,
  required Money expense,
  required Map<int, Money> expenseByCategory,
  required Map<int, CategoryRow> categories,
}) async {
  final doc = pw.Document(title: 'Income and expense report - $periodLabel');
  final net = income - expense;

  final rows =
      expenseByCategory.entries
          .map((e) => (category: categories[e.key], amount: e.value))
          .where((e) => e.category != null)
          .toList()
        ..sort((a, b) => b.amount.paise.compareTo(a.amount.paise));

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => _pageHeader('Income and Expense Report'),
      footer: _pageFooter,
      build: (context) => [
        _kv('Period', periodLabel),
        _kv('Currency', MoneyFormat.currency.code),
        pw.SizedBox(height: 12),
        _kv('Total income', MoneyFormat.bare(income)),
        _kv('Total expense', MoneyFormat.bare(expense)),
        _kv(
          'Net',
          net.isNegative
              ? '-${MoneyFormat.bare(net.abs)}'
              : MoneyFormat.bare(net),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'EXPENSE BY CATEGORY',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 6),
        if (rows.isEmpty)
          pw.Text(
            'No expenses in this period.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Category', 'Amount', '% of expense'],
            data: [
              for (final r in rows)
                [
                  r.category!.name,
                  MoneyFormat.bare(r.amount),
                  expense.isZero
                      ? '-'
                      : '${(r.amount.paise / expense.paise * 100).toStringAsFixed(1)}%',
                ],
            ],
            cellAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
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
        pw.SizedBox(height: 12),
        pw.Text(
          'Transfers between your own accounts are never counted as income '
          'or expense.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    ),
  );

  return doc.save();
}

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

String _dateLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
