import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/branding/app_info.dart';
import '../../core/currency.dart';
import '../../core/money.dart';

/// The shared look of every PDF a user *sends to someone* — a transaction
/// receipt, a person's ledger, a group's expenses. Unlike the bookkeeping
/// statements in `data_export/statement_pdf.dart` (plain ASCII on the
/// built-in Helvetica), these embed Inter, so amounts carry their real
/// currency symbol and the page reads like a document, not a printout.
///
/// Fully offline: the three weights are bundled assets
/// (`assets/fonts/pdf/`), and only the glyphs a document actually uses get
/// embedded, so a one-page receipt stays a few tens of KB.
class PdfKit {
  PdfKit._(this.regular, this.semiBold, this.bold, this._glyphs);

  final pw.Font regular;
  final pw.Font semiBold;
  final pw.Font bold;

  /// Every code point the fonts can draw — a currency symbol outside it
  /// (฿, ৳, the Arabic-script ones) falls back to its ISO code instead of
  /// rendering as a blank.
  final Set<int> _glyphs;

  static Future<PdfKit>? _loading;

  /// Loads the fonts once per app run; every later call reuses them.
  static Future<PdfKit> load() => _loading ??= _load().catchError((Object e) {
    // A failed load must not poison every later attempt.
    _loading = null;
    throw e;
  });

  static Future<PdfKit> _load() async {
    // One at a time, not Future.wait: an asset bundle may answer with a
    // SynchronousFuture (the test bundle does), which Future.wait mishandles
    // into an empty list.
    final regular = await rootBundle.load('assets/fonts/pdf/Inter-Regular.ttf');
    final semiBold = await rootBundle.load(
      'assets/fonts/pdf/Inter-SemiBold.ttf',
    );
    final bold = await rootBundle.load('assets/fonts/pdf/Inter-Bold.ttf');
    return PdfKit._(
      pw.Font.ttf(regular),
      pw.Font.ttf(semiBold),
      pw.Font.ttf(bold),
      TtfParser(regular).charToGlyphIndexMap.keys.toSet(),
    );
  }

  // ── Palette ────────────────────────────────────────────────────────────────

  static const ink = PdfColor.fromInt(0xFF0E0E10);
  static const muted = PdfColor.fromInt(0xFF6B6B76);
  static const faint = PdfColor.fromInt(0xFF9A9AA3);
  static const hairline = PdfColor.fromInt(0xFFE4E4E9);
  static const panel = PdfColor.fromInt(0xFFF4F4F6);
  static const zebra = PdfColor.fromInt(0xFFF9F9FB);
  static const income = PdfColor.fromInt(0xFF16A34A);
  static const expense = PdfColor.fromInt(0xFFDC2626);
  static const transfer = PdfColor.fromInt(0xFF2563EB);
  static const person = PdfColor.fromInt(0xFFA855F7);
  static const correction = PdfColor.fromInt(0xFFD97706);

  /// [c] washed toward white — a solid stand-in for a translucent fill,
  /// which the pdf package doesn't blend on its own.
  static PdfColor tint(PdfColor c, [double strength = 0.10]) => PdfColor(
    1 - (1 - c.red) * strength,
    1 - (1 - c.green) * strength,
    1 - (1 - c.blue) * strength,
  );

  // ── Text ───────────────────────────────────────────────────────────────────

  pw.ThemeData get theme => pw.ThemeData.withFont(base: regular, bold: bold);

  pw.TextStyle style({
    double size = 9.5,
    PdfColor color = ink,
    pw.Font? font,
    double? letterSpacing,
    double? lineSpacing,
  }) => pw.TextStyle(
    font: font ?? regular,
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
    lineSpacing: lineSpacing,
  );

  /// `₹1,250.00`, or `1,250.00 THB` when the symbol isn't in the font.
  /// [signed] prefixes a true minus (or a plus) — for ledger rows.
  String money(Money m, Currency currency, {bool signed = false}) {
    final sign = !signed
        ? (m.isNegative ? '−' : '')
        : (m.isNegative ? '−' : '+');
    final symbolOk = currency.symbol.runes.every(_glyphs.contains);
    final body = symbolOk
        ? MoneyFormat.forCurrency(m.abs, currency)
        : '${MoneyFormat.bareIn(m.abs, currency)} ${currency.code}';
    return '$sign$body';
  }

  static String date(DateTime d) => DateFormat('d MMM yyyy').format(d);

  static String dateTime(DateTime d) =>
      DateFormat('d MMM yyyy, h:mm a').format(d);

  // ── Page furniture ─────────────────────────────────────────────────────────

  pw.PageTheme pageTheme() => pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 28),
    theme: theme,
  );

  /// First page: the dark brand band with the document's kind and when it
  /// was made. Later pages: one quiet line, so a long ledger doesn't repeat
  /// a banner on every sheet.
  pw.Widget header(pw.Context context, {required String kind, String? who}) {
    if (context.pageNumber > 1) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 14),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: hairline)),
        ),
        child: pw.Row(
          children: [
            brandMark(12, tile: ink, ink: PdfColors.white),
            pw.SizedBox(width: 6),
            pw.Text(
              AppInfo.name,
              style: style(size: 9, font: bold, letterSpacing: 0.8),
            ),
            pw.Spacer(),
            pw.Text(
              [kind, ?who].join(' · '),
              style: style(size: 8.5, color: muted),
            ),
          ],
        ),
      );
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 22),
      padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const pw.BoxDecoration(
        color: ink,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          brandMark(26, tile: PdfColors.white, ink: ink),
          pw.SizedBox(width: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                AppInfo.name,
                style: style(
                  size: 15,
                  font: bold,
                  color: PdfColors.white,
                  letterSpacing: 1.2,
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Text(AppInfo.tagline, style: style(size: 7.5, color: faint)),
            ],
          ),
          pw.Spacer(),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                kind.toUpperCase(),
                style: style(
                  size: 10,
                  font: semiBold,
                  color: PdfColors.white,
                  letterSpacing: 1.4,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Generated ${dateTime(DateTime.now())}',
                style: style(size: 7.5, color: faint),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget footer(pw.Context context) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 12),
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: hairline)),
    ),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            'Made on-device with ${AppInfo.name} · '
            '${AppInfo.websiteUrl.replaceFirst('https://', '')}',
            style: style(size: 7.5, color: faint),
          ),
        ),
        pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: style(size: 7.5, color: faint),
        ),
      ],
    ),
  );

  // ── Building blocks ────────────────────────────────────────────────────────

  /// The document's subject — a name, a group, a transaction's title — with
  /// muted context lines under it.
  pw.Widget titleBlock(String title, List<String> lines) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title, style: style(size: 20, font: bold)),
      for (final line in lines) ...[
        pw.SizedBox(height: 3),
        pw.Text(line, style: style(size: 9.5, color: muted)),
      ],
    ],
  );

  /// `ENTRIES`-style small caps label opening a section.
  pw.Widget section(String label, {String? trailing}) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 7),
    child: pw.Row(
      children: [
        pw.Text(
          label.toUpperCase(),
          style: style(
            size: 8,
            font: semiBold,
            color: muted,
            letterSpacing: 1.3,
          ),
        ),
        pw.Spacer(),
        if (trailing != null)
          pw.Text(trailing, style: style(size: 8, color: faint)),
      ],
    ),
  );

  /// A row of equal-width figure tiles — the summary across the top of a
  /// statement.
  pw.Widget tiles(List<PdfTile> tiles) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < tiles.length; i++) ...[
        if (i > 0) pw.SizedBox(width: 8),
        pw.Expanded(child: _tile(tiles[i])),
      ],
    ],
  );

  pw.Widget _tile(PdfTile t) => pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(11, 9, 11, 10),
    decoration: pw.BoxDecoration(
      color: t.color == null ? panel : tint(t.color!, 0.08),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          t.label.toUpperCase(),
          style: style(
            size: 6.8,
            font: semiBold,
            color: muted,
            letterSpacing: 0.9,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          t.value,
          style: style(size: 12.5, font: bold, color: t.color ?? ink),
        ),
        if (t.caption != null) ...[
          pw.SizedBox(height: 2),
          pw.Text(t.caption!, style: style(size: 7.5, color: muted)),
        ],
      ],
    ),
  );

  /// A data table: tinted header, zebra rows, hairline rules. Each column's
  /// [PdfColumn.flex] sets its share of the width.
  pw.Widget table({
    required List<PdfColumn> columns,
    required List<List<PdfCell>> rows,
  }) {
    pw.Alignment align(PdfColumn c) =>
        c.numeric ? pw.Alignment.centerRight : pw.Alignment.centerLeft;

    return pw.Table(
      columnWidths: {
        for (var i = 0; i < columns.length; i++)
          i: pw.FlexColumnWidth(columns[i].flex),
      },
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: hairline, width: 0.6),
        bottom: pw.BorderSide(color: hairline, width: 0.6),
      ),
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: panel),
          children: [
            for (final c in columns)
              pw.Container(
                alignment: align(c),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 6,
                ),
                child: pw.Text(
                  c.label.toUpperCase(),
                  textAlign: c.numeric ? pw.TextAlign.right : null,
                  style: style(
                    size: 6.8,
                    font: semiBold,
                    color: muted,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
          ],
        ),
        for (var r = 0; r < rows.length; r++)
          pw.TableRow(
            decoration: r.isOdd ? const pw.BoxDecoration(color: zebra) : null,
            children: [
              for (var i = 0; i < columns.length; i++)
                pw.Container(
                  alignment: align(columns[i]),
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 6,
                  ),
                  child: _cell(rows[r][i], columns[i]),
                ),
            ],
          ),
      ],
    );
  }

  pw.Widget _cell(PdfCell cell, PdfColumn column) {
    final end = column.numeric
        ? pw.CrossAxisAlignment.end
        : pw.CrossAxisAlignment.start;
    return pw.Column(
      crossAxisAlignment: end,
      children: [
        pw.Text(
          cell.text,
          textAlign: column.numeric ? pw.TextAlign.right : null,
          style: style(
            size: 8.8,
            font: cell.strong ? semiBold : regular,
            color: cell.color ?? ink,
          ),
        ),
        if (cell.sub != null) ...[
          pw.SizedBox(height: 1.5),
          pw.Text(
            cell.sub!,
            textAlign: column.numeric ? pw.TextAlign.right : null,
            style: style(size: 7.2, color: muted),
          ),
        ],
      ],
    );
  }

  /// Label/value pairs in two columns, rules between — a receipt's details.
  pw.Widget details(List<(String, String)> rows) => pw.Column(
    children: [
      for (var i = 0; i < rows.length; i++)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 7),
          decoration: i == 0
              ? null
              : const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: hairline, width: 0.6),
                  ),
                ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 120,
                child: pw.Text(rows[i].$1, style: style(size: 9, color: muted)),
              ),
              pw.Expanded(
                child: pw.Text(
                  rows[i].$2,
                  textAlign: pw.TextAlign.right,
                  style: style(size: 9.5, font: semiBold),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  /// A highlighted line, tinted and outlined in [color] — the balance that
  /// matters.
  pw.Widget callout({
    required String label,
    required String value,
    String? note,
    PdfColor color = ink,
  }) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 16),
    padding: const pw.EdgeInsets.fromLTRB(14, 11, 14, 11),
    decoration: pw.BoxDecoration(
      color: tint(color, 0.07),
      border: pw.Border.all(color: tint(color, 0.45), width: 0.8),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                label.toUpperCase(),
                style: style(
                  size: 7,
                  font: semiBold,
                  color: muted,
                  letterSpacing: 1,
                ),
              ),
              if (note != null) ...[
                pw.SizedBox(height: 3),
                pw.Text(note, style: style(size: 8.5, color: ink)),
              ],
            ],
          ),
        ),
        pw.Text(
          value,
          style: style(size: 14, font: bold, color: color),
        ),
      ],
    ),
  );

  pw.Widget emptyNote(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 18),
    decoration: const pw.BoxDecoration(
      color: zebra,
      borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    alignment: pw.Alignment.center,
    child: pw.Text(text, style: style(size: 9, color: muted)),
  );

  /// The XPENC mark, drawn as vectors with the same geometry as
  /// `BrandMark` (lib/core/branding/brand_mark.dart): a squircle tile with
  /// the X knocked out of it, the ascending stroke on top of a seam.
  pw.Widget brandMark(
    double size, {
    required PdfColor tile,
    required PdfColor ink,
  }) => pw.SizedBox(
    width: size,
    height: size,
    child: pw.CustomPaint(
      size: PdfPoint(size, size),
      painter: (canvas, s) {
        final w = s.x;
        final c = PdfPoint(w / 2, w / 2);

        // |x/a|^n + |y/a|^n = 1, walked as a polygon (n = 4.4).
        const n = 4.4;
        final a = w * (0.5 - 0.02);
        const steps = 96;
        for (var i = 0; i < steps; i++) {
          final t = 2 * math.pi * i / steps;
          final x = c.x + a * _signedPow(math.cos(t), 2 / n);
          final y = c.y + a * _signedPow(math.sin(t), 2 / n);
          i == 0 ? canvas.moveTo(x, y) : canvas.lineTo(x, y);
        }
        canvas
          ..closePath()
          ..setFillColor(tile)
          ..fillPath();

        // y points up here, so the screen's descending stroke is -45°.
        final thick = w * 0.128;
        final gap = w * 0.030;
        _stadium(canvas, c, w * 0.56, thick, -math.pi / 4, ink);
        _stadium(canvas, c, w * 0.56, thick + 2 * gap, math.pi / 4, tile);
        _stadium(canvas, c, w * 0.56, thick, math.pi / 4, ink);
      },
    ),
  );

  static double _signedPow(double v, double e) =>
      math.pow(v.abs(), e).toDouble() * (v.isNegative ? -1 : 1);

  /// A filled pill [length] long and [thickness] thick, centred on [c] and
  /// rotated by [angle].
  static void _stadium(
    PdfGraphics canvas,
    PdfPoint c,
    double length,
    double thickness,
    double angle,
    PdfColor color,
  ) {
    final r = thickness / 2;
    final half = length / 2 - r;
    final ux = math.cos(angle), uy = math.sin(angle);
    const arc = 16;
    var first = true;
    for (final end in const [1, -1]) {
      final cx = c.x + ux * half * end;
      final cy = c.y + uy * half * end;
      final from = angle + (end == 1 ? -math.pi / 2 : math.pi / 2);
      for (var i = 0; i <= arc; i++) {
        final t = from + math.pi * i / arc;
        final x = cx + r * math.cos(t);
        final y = cy + r * math.sin(t);
        if (first) {
          canvas.moveTo(x, y);
          first = false;
        } else {
          canvas.lineTo(x, y);
        }
      }
    }
    canvas
      ..closePath()
      ..setFillColor(color)
      ..fillPath();
  }
}

/// One summary tile — see [PdfKit.tiles].
class PdfTile {
  const PdfTile(this.label, this.value, {this.caption, this.color});

  final String label;
  final String value;
  final String? caption;

  /// Colours the figure and tints the tile; null keeps it neutral.
  final PdfColor? color;
}

/// One table column — see [PdfKit.table].
class PdfColumn {
  const PdfColumn(this.label, {this.flex = 1, this.numeric = false});

  final String label;
  final double flex;

  /// Right-aligned, for amounts.
  final bool numeric;
}

/// One table cell: [text] with an optional muted [sub] line under it.
class PdfCell {
  const PdfCell(this.text, {this.sub, this.color, this.strong = false});

  static const empty = PdfCell('');

  final String text;
  final String? sub;
  final PdfColor? color;
  final bool strong;
}
