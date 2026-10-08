import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/currency.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/tables.dart';
import 'pdf_kit.dart';
import 'share_models.dart';

/// PDFs meant to be *sent* — see [PdfKit] for the shared look.

PdfColor _pdfColor(int argb) => PdfColor.fromInt(argb);

/// Green when they owe me, red when I owe them, ink when settled.
PdfColor _balanceColor(Money b) => b.isPositive
    ? PdfKit.income
    : b.isNegative
    ? PdfKit.expense
    : PdfKit.ink;

String _periodLine(SharePeriod period, {DateTime? since}) {
  final r = period.range;
  if (r == null) {
    return since == null
        ? 'Period: all time'
        : 'Period: ${PdfKit.date(since)} to ${PdfKit.date(DateTime.now())}';
  }
  return 'Period: ${PdfKit.date(r.start)} to ${PdfKit.date(r.end)}';
}

// ── Transaction receipt ──────────────────────────────────────────────────────

/// One transaction as a receipt: the amount up top, every detail in a
/// labelled list, its split and note, and the attached receipt photo when
/// there is one.
Future<Uint8List> buildTransactionPdf(TransactionShare s) async {
  final kit = await PdfKit.load();
  final t = s.tx;
  final color = _pdfColor(s.color.toARGB32());
  final doc = pw.Document(
    title: '${s.typeLabel} · ${PdfKit.date(t.date)}',
    author: 'XPENC',
  );

  final amount = kit.money(s.signedAmount, s.currency, signed: !s.isTransfer);
  final when = s.hasTime
      ? DateFormat('EEEE, d MMMM yyyy · h:mm a').format(t.date)
      : DateFormat('EEEE, d MMMM yyyy').format(t.date);

  final rows = <(String, String)>[
    ('Type', s.typeLabel),
    ('Date', when),
    if (s.category != null) ('Category', s.category!),
    ('Account', s.account),
    if (s.fundedFrom != null) ('Funded from', s.fundedFrom!),
    if (s.payee != null) ('Payee', s.payee!),
    if (s.person != null && s.payee == null) ('Person', s.person!),
    if (s.foreign case (final m, final c)?)
      ('Original amount', _foreignLine(kit, s, m, c)),
    if (s.received case (final m, final c)?) ('Arrived as', kit.money(m, c)),
    if (s.tags.isNotEmpty) ('Tags', s.tags.map((t) => t.name).join(', ')),
    if (s.rule != null) ('Posted by', 'Auto rule "${s.rule}"'),
    ('Currency', '${s.currency.code} · ${s.currency.name}'),
  ];

  final receipt = await _receiptImage(t.imagePath);

  doc.addPage(
    pw.MultiPage(
      pageTheme: kit.pageTheme(),
      header: (context) => kit.header(context, kind: 'Transaction receipt'),
      footer: kit.footer,
      build: (context) => [
        // The amount, the way a payment app's receipt leads with it.
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          decoration: pw.BoxDecoration(
            color: PdfKit.tint(color, 0.07),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
          ),
          child: pw.Column(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfKit.tint(color, 0.16),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(7),
                  ),
                ),
                child: pw.Text(
                  s.typeLabel.toUpperCase(),
                  style: kit.style(
                    size: 7.5,
                    font: kit.semiBold,
                    color: color,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                amount,
                style: kit.style(size: 30, font: kit.bold, color: color),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                s.headline,
                textAlign: pw.TextAlign.center,
                style: kit.style(size: 13, font: kit.semiBold),
              ),
              pw.SizedBox(height: 3),
              pw.Text(when, style: kit.style(size: 9, color: PdfKit.muted)),
            ],
          ),
        ),
        kit.section('Details'),
        kit.details(rows),
        if (s.splits.isNotEmpty) ...[
          kit.section('Split', trailing: '${s.splits.length} categories'),
          kit.table(
            columns: const [
              PdfColumn('Category', flex: 3),
              PdfColumn('Share', flex: 1.2, numeric: true),
              PdfColumn('Amount', flex: 1.6, numeric: true),
            ],
            rows: [
              for (final split in s.splits)
                [
                  PdfCell(split.name),
                  PdfCell(_percent(split.amount, t.amount)),
                  PdfCell(kit.money(split.amount, s.currency), strong: true),
                ],
              [
                const PdfCell('Total', strong: true),
                const PdfCell('100%'),
                PdfCell(kit.money(t.amount, s.currency), strong: true),
              ],
            ],
          ),
        ],
        if (s.note != null) ...[
          kit.section('Note'),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(
              color: PdfKit.panel,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Text(s.note!, style: kit.style(size: 10, lineSpacing: 2)),
          ),
        ],
        if (receipt != null) ...[
          kit.section('Attached receipt'),
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfKit.hairline),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Image(receipt, height: 360, fit: pw.BoxFit.contain),
          ),
        ],
      ],
    ),
  );
  return doc.save();
}

/// "$9.99 · 1 USD ≈ ₹83.08" — the implied rate is recomputed, never stored.
String _foreignLine(PdfKit kit, TransactionShare s, Money m, Currency c) {
  final formatted = kit.money(m, c);
  if (!m.isPositive) return formatted;
  final rate = Money.fromRupees(s.tx.amount.rupees / m.rupees);
  return '$formatted · 1 ${c.code} ≈ ${kit.money(rate, s.currency)}';
}

String _percent(Money part, Money whole) {
  if (whole.isZero) return '—';
  final p = part.paise * 100 / whole.paise;
  return '${p.toStringAsFixed(p == p.roundToDouble() ? 0 : 1)}%';
}

/// The attached receipt, or null when it's missing or in a format the pdf
/// package can't embed (HEIC, say) — a receipt never blocks the PDF.
Future<pw.ImageProvider?> _receiptImage(String? path) async {
  if (path == null) return null;
  try {
    final file = File(path);
    if (!await file.exists()) return null;
    return pw.MemoryImage(await file.readAsBytes());
  } catch (_) {
    return null;
  }
}

// ── Person statement ─────────────────────────────────────────────────────────

/// One person's ledger for [period]: an opening balance from everything
/// before it, each entry with the running balance after it, and today's
/// balance at the end (GitHub #128).
Future<Uint8List> buildPersonStatementPdf(
  PersonShare s,
  SharePeriod period,
) async {
  final kit = await PdfKit.load();
  final p = s.person;
  final ledger = s.ledger(period);
  final currency = MoneyFormat.currency;
  final owner = s.owner;
  final doc = pw.Document(title: '${p.name} · statement', author: 'XPENC');
  String m(Money v) => kit.money(v, currency);

  PdfCell balanceCell(Money b) => PdfCell(
    m(b.abs),
    sub: b.isPositive
        ? '${p.name} owes'
        : b.isNegative
        ? (owner.name == null ? 'You owe' : '${owner.name} owes')
        : 'Settled',
    color: _balanceColor(b),
    strong: true,
  );

  final hasOpening = period.range != null;

  doc.addPage(
    pw.MultiPage(
      pageTheme: kit.pageTheme(),
      header: (context) =>
          kit.header(context, kind: 'Person statement', who: p.name),
      footer: kit.footer,
      build: (context) => [
        kit.titleBlock(p.name, [
          _periodLine(period, since: s.firstDate),
          'Between ${p.name} and ${owner.object} · '
              'amounts in ${currency.code}',
        ]),
        pw.SizedBox(height: 16),
        kit.tiles([
          if (hasOpening)
            PdfTile(
              'Opening balance',
              m(ledger.opening.abs),
              caption: owner.balanceLine(ledger.opening, p.name),
            )
          else
            PdfTile(
              'Entries',
              '${ledger.lines.length}',
              caption: ledger.lines.length == 1 ? 'entry' : 'entries',
            ),
          PdfTile(owner.gave, m(ledger.ownerGave), caption: 'to ${p.name}'),
          PdfTile(
            '${p.name} gave',
            m(ledger.theyGave),
            caption: 'to ${owner.object}',
          ),
          PdfTile(
            hasOpening ? 'Closing balance' : 'Balance',
            m(ledger.closing.abs),
            caption: owner.balanceLine(ledger.closing, p.name),
            color: _balanceColor(ledger.closing),
          ),
        ]),
        kit.section(
          'Entries',
          trailing:
              '${ledger.lines.length} '
              '${ledger.lines.length == 1 ? 'entry' : 'entries'}',
        ),
        if (ledger.lines.isEmpty && !hasOpening)
          kit.emptyNote('No entries in this period.')
        else
          kit.table(
            columns: [
              const PdfColumn('Date', flex: 1.35),
              const PdfColumn('Details', flex: 3),
              PdfColumn(owner.gave, flex: 1.45, numeric: true),
              PdfColumn('${p.name} gave', flex: 1.45, numeric: true),
              const PdfColumn('Balance', flex: 1.7, numeric: true),
            ],
            rows: [
              if (hasOpening)
                [
                  PdfCell(PdfKit.date(period.range!.start)),
                  const PdfCell('Opening balance', strong: true),
                  PdfCell.empty,
                  PdfCell.empty,
                  balanceCell(ledger.opening),
                ],
              for (final line in ledger.lines)
                [
                  PdfCell(PdfKit.date(line.entry.date)),
                  PdfCell(s.titleOf(line.entry), sub: _entrySub(s, line.entry)),
                  line.entry.direction == PersonDirection.theyOwe
                      ? PdfCell(m(line.entry.amount))
                      : PdfCell.empty,
                  line.entry.direction == PersonDirection.iOwe
                      ? PdfCell(m(line.entry.amount))
                      : PdfCell.empty,
                  balanceCell(line.balance),
                ],
            ],
          ),
        kit.callout(
          label: 'Balance today',
          note: owner.balanceLine(s.balance, p.name),
          value: m(s.balance.abs),
          color: _balanceColor(s.balance),
        ),
      ],
    ),
  );
  return doc.save();
}

/// The muted line under an entry: its group, that it was a repayment,
/// when it's due.
String? _entrySub(PersonShare s, PersonEntryRow e) {
  final parts = [
    if (s.groupNames[e.id] case final g?) 'Group · $g',
    if (e.categoryId != null) 'Repayment',
    if (e.dueDate != null) 'Due ${PdfKit.date(e.dueDate!)}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

// ── Group statement ──────────────────────────────────────────────────────────

/// One group's expenses for [period] — who paid, how it was split, my share
/// of each — then today's who-owes-whom.
Future<Uint8List> buildGroupStatementPdf(
  GroupShare s,
  SharePeriod period,
) async {
  final kit = await PdfKit.load();
  final g = s.group;
  final slice = s.slice(period);
  final currency = MoneyFormat.currency;
  final owner = s.owner;
  final doc = pw.Document(
    title: '${g.name} · group statement',
    author: 'XPENC',
  );
  String m(Money v) => kit.money(v, currency);

  final memberNames = [owner.subject, ...s.members.map((p) => p.name)];
  final oldest = s.expenses.isEmpty
      ? null
      : s.expenses.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b);

  final balanceLine = s.balance.isPositive
      ? 'Owed to ${owner.object}'
      : s.balance.isNegative
      ? (owner.name == null ? 'You owe' : '${owner.name} owes')
      : 'All settled';

  doc.addPage(
    pw.MultiPage(
      pageTheme: kit.pageTheme(),
      header: (context) =>
          kit.header(context, kind: 'Group statement', who: g.name),
      footer: kit.footer,
      build: (context) => [
        kit.titleBlock(g.name, [
          '${memberNames.length} members · ${memberNames.join(', ')}',
          '${_periodLine(period, since: oldest)} · '
              'amounts in ${currency.code}',
        ]),
        pw.SizedBox(height: 16),
        kit.tiles([
          PdfTile(
            'Total spent',
            m(slice.total),
            caption:
                '${slice.expenses.length} '
                '${slice.expenses.length == 1 ? 'expense' : 'expenses'}',
          ),
          PdfTile(
            owner.name == null ? 'Your share' : "${owner.name}'s share",
            m(slice.myShare),
            caption: slice.total.isZero
                ? null
                : '${_percent(slice.myShare, slice.total)} of the total',
          ),
          PdfTile(
            'Balance today',
            m(s.balance.abs),
            caption: balanceLine,
            color: _balanceColor(s.balance),
          ),
        ]),
        kit.section(
          'Expenses',
          trailing: slice.expenses.isEmpty ? null : 'Newest first',
        ),
        if (slice.expenses.isEmpty)
          kit.emptyNote('No expenses in this period.')
        else
          kit.table(
            columns: [
              const PdfColumn('Date', flex: 1.35),
              const PdfColumn('Details', flex: 2.8),
              const PdfColumn('Paid by', flex: 1.5),
              const PdfColumn('Split', flex: 1),
              const PdfColumn('Amount', flex: 1.5, numeric: true),
              PdfColumn(
                owner.name == null ? 'Your share' : "${owner.name}'s share",
                flex: 1.5,
                numeric: true,
              ),
            ],
            rows: [
              for (final e in slice.expenses)
                [
                  PdfCell(PdfKit.date(e.date)),
                  PdfCell(s.titleOf(e)),
                  PdfCell(s.nameOf(e.payerId)),
                  PdfCell(GroupShare.splitLabel(e.splitMethod)),
                  PdfCell(m(e.amount), strong: true),
                  PdfCell(
                    s.myShares[e.id] == null ? '—' : m(s.myShares[e.id]!),
                  ),
                ],
              [
                PdfCell.empty,
                const PdfCell('Total', strong: true),
                PdfCell.empty,
                PdfCell.empty,
                PdfCell(m(slice.total), strong: true),
                PdfCell(m(slice.myShare), strong: true),
              ],
            ],
          ),
        kit.section('Who owes whom', trailing: 'As of today'),
        if (s.debts.isEmpty)
          kit.emptyNote('Everyone is settled up.')
        else
          kit.table(
            columns: const [
              PdfColumn('Owes', flex: 2),
              PdfColumn('To', flex: 2),
              PdfColumn('Amount', flex: 1.5, numeric: true),
            ],
            rows: [
              for (final d in s.debts)
                [
                  PdfCell(s.nameOf(d.from), strong: true),
                  PdfCell(s.nameOf(d.to)),
                  PdfCell(m(d.amount), strong: true),
                ],
            ],
          ),
        kit.callout(
          label: owner.name == null
              ? 'Your balance in this group'
              : "${owner.name}'s balance in this group",
          note: balanceLine,
          value: m(s.balance.abs),
          color: _balanceColor(s.balance),
        ),
      ],
    ),
  );
  return doc.save();
}
