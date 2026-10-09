import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/branding/app_info.dart';
import '../../core/branding/brand_mark.dart';
import '../../core/currency.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/tables.dart';
import '../persons/person_avatar.dart' show personInitials;
import 'share_models.dart';

/// The shareable image cards — a transaction receipt, a person's balance,
/// a group's spend. Each is a fixed 360-wide layout, captured at 3× into a
/// 1080 px PNG, so it looks the same whatever phone made it.
///
/// Deliberately independent of the app's theme: a card is something the
/// *recipient* sees, so it carries its own two looks ([ShareCardTone]) and
/// Inter throughout, rather than whatever palette and font the sender
/// happens to use. Amounts are never masked here — sharing one is the
/// user's explicit choice.

enum ShareCardTone { dark, light }

class _Palette {
  const _Palette({
    required this.page,
    required this.pageEnd,
    required this.card,
    required this.text,
    required this.muted,
    required this.faint,
    required this.line,
    required this.panel,
    required this.isDark,
  });

  final Color page;
  final Color pageEnd;
  final Color card;
  final Color text;
  final Color muted;
  final Color faint;
  final Color line;
  final Color panel;
  final bool isDark;

  static const dark = _Palette(
    page: Color(0xFF08080A),
    pageEnd: Color(0xFF141418),
    card: Color(0xFF18181D),
    text: Color(0xFFF5F5F7),
    muted: Color(0xFFA1A1AB),
    faint: Color(0xFF6C6C76),
    line: Color(0x29FFFFFF),
    panel: Color(0xFF222229),
    isDark: true,
  );

  static const light = _Palette(
    page: Color(0xFFE6E6EB),
    pageEnd: Color(0xFFF5F5F8),
    card: Colors.white,
    text: Color(0xFF0E0E10),
    muted: Color(0xFF686873),
    faint: Color(0xFF9B9BA4),
    line: Color(0x1F000000),
    panel: Color(0xFFF3F3F6),
    isDark: false,
  );

  static _Palette of(ShareCardTone tone) =>
      tone == ShareCardTone.dark ? dark : light;

  /// What shows through the ticket's notches — the page, midway down.
  Color get notch => Color.lerp(page, pageEnd, 0.5)!;
}

String _money(Money m, Currency c, {bool signed = false}) {
  final sign = m.isNegative ? '−' : (signed && m.isPositive ? '+' : '');
  return '$sign${MoneyFormat.forCurrency(m.abs, c)}';
}

const _tabular = kTabularFigures;

// ── Frame ────────────────────────────────────────────────────────────────────

/// Brand row, the ticket itself, and a sign-off — shared by every card.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.tone,
    required this.accent,
    required this.kind,
    required this.child,
  });

  final ShareCardTone tone;
  final Color accent;
  final String kind;
  final Widget child;

  static const width = 360.0;

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(tone);
    return DefaultTextStyle(
      style: TextStyle(
        fontFamily: 'Inter',
        color: p.text,
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w400,
        decoration: TextDecoration.none,
      ),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.page, p.pageEnd],
          ),
        ),
        child: Stack(
          children: [
            // The accent's glow behind the brand row and the ticket's top.
            Positioned(
              top: -150,
              left: -40,
              right: -40,
              height: 360,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: p.isDark ? 0.30 : 0.18),
                      accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      BrandMark(
                        size: 24,
                        tile: p.text,
                        ink: p.isDark ? const Color(0xFF0E0E10) : Colors.white,
                        radiusRim: false,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppInfo.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: p.text,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: p.line),
                        ),
                        child: Text(
                          kind.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.3,
                            color: p.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(26),
                      // A hairline, not a shadow: a white card needs an
                      // edge on the pale page, and a blur renders
                      // differently from one device to the next.
                      border: p.isDark ? null : Border.all(color: p.line),
                    ),
                    child: child,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Tracked with ${AppInfo.name} · '
                    '${AppInfo.websiteUrl.replaceFirst('https://', '')}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: p.faint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A ticket's tear line: a notch bitten out of each edge, dashes between.
class _Perforation extends StatelessWidget {
  const _Perforation(this.p);

  final _Palette p;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Container(
            width: 12,
            decoration: BoxDecoration(
              color: p.notch,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: LayoutBuilder(
                builder: (context, c) {
                  final count = (c.maxWidth / 10).floor();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < count; i++)
                        Container(width: 5, height: 1.5, color: p.line),
                    ],
                  );
                },
              ),
            ),
          ),
          Container(
            width: 12,
            decoration: BoxDecoration(
              color: p.notch,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.color, required this.size, this.icon, this.child});

  final Color color;
  final double size;
  final IconData? icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: child ?? Icon(icon, size: size * 0.48, color: color),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.p, this.label, {this.trailing});

  final _Palette p;
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: p.faint,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: style),
          const Spacer(),
          if (trailing != null)
            Text(trailing!, style: style.copyWith(letterSpacing: 0.2)),
        ],
      ),
    );
  }
}

/// Label on the left, value pushed right — a receipt line.
class _DetailRow extends StatelessWidget {
  const _DetailRow(this.p, this.label, {this.text, this.value});

  final _Palette p;
  final String label;
  final String? text;
  final Widget? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: p.muted),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  value ??
                  Text(
                    text ?? '—',
                    textAlign: TextAlign.right,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small figure tile — "You gave ₹5,000".
class _Stat extends StatelessWidget {
  const _Stat(this.p, this.label, this.value, {this.caption, this.color});

  final _Palette p;
  final String label;
  final String value;
  final String? caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: p.muted),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color ?? p.text,
                fontFeatures: _tabular,
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: p.faint),
            ),
          ],
        ],
      ),
    );
  }
}

/// The big figure in the middle of a card.
class _Hero extends StatelessWidget {
  const _Hero(this.text, this.color, {this.size = 36});

  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          height: 1.1,
          color: color,
          fontFeatures: _tabular,
        ),
      ),
    );
  }
}

/// One line of a list: a direction disc, two lines of text, an amount.
class _ListLine extends StatelessWidget {
  const _ListLine({
    required this.p,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.amountColor,
  });

  final _Palette p;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String amount;
  final Color? amountColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _Disc(color: color, size: 30, icon: icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: p.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: amountColor ?? p.text,
              fontFeatures: _tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreLine extends StatelessWidget {
  const _MoreLine(this.p, this.count, this.one, this.many);

  final _Palette p;
  final int count;
  final String one;
  final String many;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '+ $count more ${count == 1 ? one : many}',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11.5, color: p.faint),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.p, this.text);

  final _Palette p;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.5, color: p.muted),
      ),
    );
  }
}

// ── Transaction ──────────────────────────────────────────────────────────────

/// A transaction as a payment-app style receipt.
class TransactionShareCard extends StatelessWidget {
  const TransactionShareCard({
    required this.data,
    required this.tone,
    super.key,
  });

  final TransactionShare data;
  final ShareCardTone tone;

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(tone);
    final t = data.tx;
    final accent = data.color;
    final showCategoryIcon =
        data.categoryIconKey != null &&
        data.splits.isEmpty &&
        t.type.isIncomeOrExpense;
    // The transaction's own icon, else its category's emoji if it has one.
    final badge =
        t.customIcon ??
        (showCategoryIcon ? AppIcons.emojiOf(data.categoryIconKey) : null);
    final date = data.hasTime
        ? DateFormat('EEE, d MMM yyyy · h:mm a').format(t.date)
        : DateFormat('EEE, d MMM yyyy').format(t.date);

    return _Frame(
      tone: tone,
      accent: accent,
      kind: 'Receipt',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
            child: Column(
              children: [
                _Disc(
                  color: accent,
                  size: 56,
                  icon: showCategoryIcon
                      ? AppIcons.resolve(data.categoryIconKey!)
                      : t.type == TxType.expense && data.splits.isNotEmpty
                      ? Icons.call_split_rounded
                      : iconForTxType(t.type),
                  child: badge == null
                      ? null
                      : CustomIconBadge(value: badge, size: 56, color: accent),
                ),
                const SizedBox(height: 14),
                _Hero(
                  _money(
                    data.signedAmount,
                    data.currency,
                    signed: !data.isTransfer,
                  ),
                  accent,
                  size: 38,
                ),
                const SizedBox(height: 8),
                Text(
                  data.headline,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(date, style: TextStyle(fontSize: 12.5, color: p.muted)),
                const SizedBox(height: 12),
                _Pill(data.typeLabel, accent),
              ],
            ),
          ),
          _Perforation(p),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (data.category != null)
                  _DetailRow(
                    p,
                    'Category',
                    value: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (AppIcons.emojiOf(data.categoryIconKey)
                            case final emoji?)
                          CustomIconBadge(value: emoji, size: 15, scaled: false)
                        else
                          Icon(
                            AppIcons.resolve(data.categoryIconKey ?? 'other'),
                            size: 16,
                            color: data.categoryColor == null
                                ? p.muted
                                : Color(data.categoryColor!),
                          ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            data.category!,
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (data.splits.isNotEmpty)
                  _DetailRow(
                    p,
                    'Split',
                    value: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final s in data.splits)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: s.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        '  ${_money(s.amount, data.currency)}',
                                    style: TextStyle(
                                      color: p.muted,
                                      fontFeatures: _tabular,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                _DetailRow(p, 'Account', text: data.account),
                if (data.fundedFrom != null)
                  _DetailRow(p, 'Funded from', text: data.fundedFrom),
                if (data.payee != null)
                  _DetailRow(p, 'Payee', text: data.payee),
                if (data.person != null && data.payee == null)
                  _DetailRow(p, 'Person', text: data.person),
                if (data.foreign case (final m, final c)?)
                  _DetailRow(p, 'Original', text: _money(m, c)),
                if (data.received case (final m, final c)?)
                  _DetailRow(p, 'Arrived as', text: _money(m, c)),
                if (data.tags.isNotEmpty)
                  _DetailRow(
                    p,
                    'Tags',
                    value: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in data.tags)
                          _Pill(tag.name, Color(tag.colorValue)),
                      ],
                    ),
                  ),
                if (data.rule != null)
                  _DetailRow(p, 'Auto rule', text: data.rule),
                if (data.note != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                    decoration: BoxDecoration(
                      color: p.panel,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes_rounded, size: 16, color: p.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data.note!,
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Person ───────────────────────────────────────────────────────────────────

/// Where things stand with one person, plus their latest entries.
class PersonShareCard extends StatelessWidget {
  const PersonShareCard({
    required this.data,
    required this.period,
    required this.tone,
    super.key,
  });

  /// How many entries the card lists before "+ n more".
  static const maxLines = 6;

  final PersonShare data;
  final SharePeriod period;
  final ShareCardTone tone;

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(tone);
    final person = data.person;
    final owner = data.owner;
    final ledger = data.ledger(period);
    final balance = data.balance;
    final currency = MoneyFormat.currency;
    final accent = balance.isPositive
        ? AppColors.income
        : balance.isNegative
        ? AppColors.expense
        : p.muted;
    final recent = ledger.lines.reversed.take(maxLines).toList();
    final count = ledger.lines.length;

    return _Frame(
      tone: tone,
      accent: balance.isZero ? AppColors.person : accent,
      kind: 'Statement',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    _Avatar(p: p, name: person.name, path: person.photoPath),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${period.label} · $count '
                            '${count == 1 ? 'entry' : 'entries'}',
                            style: TextStyle(fontSize: 12, color: p.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  owner.balanceLine(balance, person.name).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: p.muted,
                  ),
                ),
                const SizedBox(height: 6),
                _Hero(_money(balance.abs, currency), accent),
                const SizedBox(height: 4),
                Text(
                  'Balance as of ${DateFormat('d MMM yyyy').format(DateTime.now())}',
                  style: TextStyle(fontSize: 11.5, color: p.faint),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        p,
                        owner.gave,
                        _money(ledger.ownerGave, currency),
                        caption: period.label,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Stat(
                        p,
                        '${person.name} gave',
                        _money(ledger.theyGave, currency),
                        caption: period.label,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _Perforation(p),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionLabel(
                  p,
                  count > maxLines ? 'Latest entries' : 'Entries',
                ),
                if (recent.isEmpty)
                  _Empty(p, 'No entries in this period.')
                else
                  for (final line in recent) _entry(p, line.entry, currency),
                _MoreLine(p, count - recent.length, 'entry', 'entries'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _entry(_Palette p, PersonEntryRow e, Currency currency) {
    final ownerGave = e.direction == PersonDirection.theyOwe;
    final isRepayment = e.categoryId != null;
    final color = isRepayment || !ownerGave
        ? AppColors.income
        : AppColors.expense;
    final group = data.groupNames[e.id];
    return _ListLine(
      p: p,
      icon: isRepayment
          ? Icons.paid_outlined
          : ownerGave
          ? Icons.arrow_upward_rounded
          : Icons.arrow_downward_rounded,
      color: color,
      title: data.titleOf(e),
      subtitle: [DateFormat('d MMM yyyy').format(e.date), ?group].join(' · '),
      amount: _money(e.amount, currency),
      amountColor: color,
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.p, required this.name, this.path});

  final _Palette p;
  final String name;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final file = path == null ? null : File(path!);
    if (file != null && file.existsSync()) {
      return CircleAvatar(radius: 23, backgroundImage: FileImage(file));
    }
    return CircleAvatar(
      radius: 23,
      backgroundColor: p.panel,
      child: Text(
        personInitials(name),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: p.text,
        ),
      ),
    );
  }
}

// ── Group ────────────────────────────────────────────────────────────────────

/// A group's spend, who owes whom, and its latest expenses.
class GroupShareCard extends StatelessWidget {
  const GroupShareCard({
    required this.data,
    required this.period,
    required this.tone,
    super.key,
  });

  static const maxDebts = 4;
  static const maxExpenses = 4;

  final GroupShare data;
  final SharePeriod period;
  final ShareCardTone tone;

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(tone);
    final g = data.group;
    final owner = data.owner;
    final slice = data.slice(period);
    final currency = MoneyFormat.currency;
    final balance = data.balance;
    final balanceColor = balance.isPositive
        ? AppColors.income
        : balance.isNegative
        ? AppColors.expense
        : p.text;
    final members = data.members.length + 1;
    final debts = data.debts.take(maxDebts).toList();
    final recent = slice.expenses.take(maxExpenses).toList();

    return _Frame(
      tone: tone,
      accent: AppColors.person,
      kind: 'Group',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    const _Disc(
                      color: AppColors.person,
                      size: 46,
                      icon: Icons.groups_2_rounded,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '$members members · ${period.label}',
                            style: TextStyle(fontSize: 12, color: p.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'TOTAL SPENT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: p.muted,
                  ),
                ),
                const SizedBox(height: 6),
                _Hero(_money(slice.total, currency), p.text),
                const SizedBox(height: 4),
                Text(
                  '${slice.expenses.length} '
                  '${slice.expenses.length == 1 ? 'expense' : 'expenses'}',
                  style: TextStyle(fontSize: 11.5, color: p.faint),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        p,
                        owner.name == null
                            ? 'Your share'
                            : "${owner.name}'s share",
                        _money(slice.myShare, currency),
                        caption: period.label,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Stat(
                        p,
                        'Balance today',
                        _money(balance.abs, currency),
                        caption: balance.isPositive
                            ? 'Owed to ${owner.object}'
                            : balance.isNegative
                            ? (owner.name == null
                                  ? 'You owe'
                                  : '${owner.name} owes')
                            : 'All settled',
                        color: balanceColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _Perforation(p),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionLabel(p, 'Who owes whom', trailing: 'Today'),
                if (debts.isEmpty)
                  _Empty(p, 'Everyone is settled up.')
                else
                  for (final d in debts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: data.nameOf(d.from),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '  →  ',
                                    style: TextStyle(color: p.faint),
                                  ),
                                  TextSpan(
                                    text: data.nameOf(d.to),
                                    style: TextStyle(color: p.muted),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _money(d.amount, currency),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              fontFeatures: _tabular,
                            ),
                          ),
                        ],
                      ),
                    ),
                _MoreLine(p, data.debts.length - debts.length, 'debt', 'debts'),
                const SizedBox(height: 10),
                _SectionLabel(
                  p,
                  slice.expenses.length > maxExpenses
                      ? 'Latest expenses'
                      : 'Expenses',
                ),
                if (recent.isEmpty)
                  _Empty(p, 'No expenses in this period.')
                else
                  for (final e in recent)
                    _ListLine(
                      p: p,
                      icon: Icons.receipt_long_rounded,
                      color: AppColors.person,
                      title: data.titleOf(e),
                      subtitle:
                          '${DateFormat('d MMM').format(e.date)} · '
                          '${e.payerId == null ? '${owner.subject} paid' : '${data.nameOf(e.payerId)} paid'}',
                      amount: _money(e.amount, currency),
                    ),
                _MoreLine(
                  p,
                  slice.expenses.length - recent.length,
                  'expense',
                  'expenses',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
