import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/beta_badge.dart';
import '../../core/widgets/nav_bar_inset.dart';

/// Shared building blocks for every More → Calculators screen: the page
/// shell, number fields, the headline result card and breakdown rows.

/// Owns a screen's [TextEditingController]s: each [field] rebuilds the
/// screen on every keystroke (results are live, there's no "Calculate"
/// button) and is disposed with the state.
mixin CalculatorFormMixin<T extends StatefulWidget> on State<T> {
  final _controllers = <TextEditingController>[];

  TextEditingController field(String initial) {
    final c = TextEditingController(text: initial)
      ..addListener(() => setState(() {}));
    _controllers.add(c);
    return c;
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }
}

/// A field's value as a number — `0` for blank or half-typed input.
double numOf(TextEditingController c) =>
    double.tryParse(c.text.replaceAll(',', '')) ?? 0;

int intOf(TextEditingController c) => numOf(c).floor();

Money moneyOf(TextEditingController c) => Money.fromRupees(numOf(c));

/// App bar with the BETA pill, a scrolling body, and an "estimates only"
/// footnote so nobody mistakes a calculator for their bank's statement.
class CalculatorScaffold extends StatelessWidget {
  const CalculatorScaffold({
    required this.title,
    required this.children,
    this.footnote =
        'Estimates only. Your bank, fund house or tax filing may round or '
        'compound differently.',
    super.key,
  });

  final String title;
  final List<Widget> children;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            const BetaBadge(),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32).plusNavBar(context),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            ...children,
            const SizedBox(height: 20),
            Text(
              footnote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A numeric input. [prefix] is usually the currency symbol, [suffix] a
/// unit like `%` or `yrs`.
class CalcField extends StatelessWidget {
  const CalcField({
    required this.controller,
    required this.label,
    this.prefix,
    this.suffix,
    this.helper,
    this.decimal = true,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? prefix;
  final String? suffix;
  final String? helper;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            decimal ? RegExp(r'^\d*\.?\d{0,2}') : RegExp(r'^\d*'),
          ),
        ],
        style: const TextStyle(fontFeatures: kTabularFigures),
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix,
          suffixText: suffix,
          helperText: helper,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// Two fields side by side, e.g. tenure years + months.
class CalcFieldPair extends StatelessWidget {
  const CalcFieldPair(this.a, this.b, {super.key});

  final Widget a;
  final Widget b;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 12),
      Expanded(child: b),
    ],
  );
}

/// One slice of a [CalcResultCard]'s split bar.
class CalcPart {
  const CalcPart(this.label, this.value, this.color);

  final String label;
  final Money value;
  final Color color;
}

/// The big number (maturity, EMI, total tax) plus a proportional bar and
/// legend showing what it's made of.
class CalcResultCard extends StatelessWidget {
  const CalcResultCard({
    required this.label,
    required this.value,
    required this.format,
    this.parts = const [],
    this.sub,
    super.key,
  });

  final String label;
  final Money value;
  final String Function(Money) format;
  final List<CalcPart> parts;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = parts.fold<int>(0, (s, p) => s + p.value.paise.abs());

    return AppCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                format(value),
                maxLines: 1,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(
                sub!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            if (total > 0) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      for (final p in parts)
                        if (p.value.paise != 0)
                          Expanded(
                            flex: (p.value.paise.abs() * 1000 / total)
                                .round()
                                .clamp(1, 1000),
                            child: ColoredBox(color: p.color),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final p in parts)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: p.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(p.label, style: theme.textTheme.bodyMedium),
                      ),
                      Text(
                        format(p.value),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFeatures: kTabularFigures,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A plain card of label/value rows — tax breakdowns, GST splits.
class CalcBreakdownCard extends StatelessWidget {
  const CalcBreakdownCard({required this.rows, super.key});

  final List<CalcRow> rows;

  @override
  Widget build(BuildContext context) => AppCard(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(children: rows),
    ),
  );
}

class CalcRow extends StatelessWidget {
  const CalcRow(this.label, this.value, {this.bold = false, super.key});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = bold
        ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: bold
                  ? style
                  : style?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: style?.copyWith(fontFeatures: kTabularFigures)),
        ],
      ),
    );
  }
}

/// Full-width segmented toggle between two or more modes (FD/RD, SIP/Lumpsum,
/// add/remove GST).
class CalcModeToggle<T> extends StatelessWidget {
  const CalcModeToggle({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        segments: [
          for (final e in options.entries)
            ButtonSegment(value: e.key, label: Text(e.value)),
        ],
        selected: {value},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    ),
  );
}

/// Bold sub-heading between groups of fields ("Income (yearly)").
class CalcHeading extends StatelessWidget {
  const CalcHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 10),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}
