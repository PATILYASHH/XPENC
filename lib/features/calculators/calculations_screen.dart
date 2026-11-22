import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/providers.dart';
import '../reports/stats_sections.dart' show SectionCaption;
import 'calculator_kind.dart';
import '../../core/l10n/l10n.dart';

/// More → Calculations: every calculator on one page, grouped by what it's
/// for — saving and growing money, borrowing, tax. Each tile opens its own
/// calculator. India-only ones (GST, PPF, India's income tax) are left out
/// unless the app is in rupees — see `indiaToolsFor` — and the page says
/// so, so nobody wonders where they went.
class CalculationsScreen extends ConsumerWidget {
  const CalculationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final india = ref.watch(indiaToolsProvider);
    final shown = CalculatorKind.shownFor(india: india);

    return Scaffold(
      appBar: AppTopBar(title: const Tr('Calculations')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32).plusNavBar(context),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 20),
            child: Tr(
              'Work it out before you commit. Results update as you type; '
              'nothing here touches your ledger.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          for (final section in CalculatorSection.values)
            if (shown.any((k) => k.section == section))
              _Section(section, [
                for (final k in shown)
                  if (k.section == section) k,
              ], india: india),
          if (!india)
            AppCard(
              margin: const EdgeInsets.only(top: 4),
              clipBehavior: Clip.antiAlias,
              child: AppListTile(
                leading: const AppIcon(Icons.public_rounded),
                title: const Tr('Calculators for India'),
                subtitle: Tr(
                  'GST, PPF and India’s income tax show when your currency '
                  'is ₹.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                trailing: const AppIcon(Icons.chevron_right_rounded),
                onTap: () => context.push('/more/settings/currency'),
              ),
            ),
        ],
      ),
    );
  }
}

/// One heading and its calculators, two to a row; an odd one out at the
/// end takes the whole row instead of leaving half of it empty.
class _Section extends StatelessWidget {
  const _Section(this.section, this.kinds, {required this.india});

  final CalculatorSection section;
  final List<CalculatorKind> kinds;
  final bool india;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCaption(section.label),
        for (var i = 0; i < kinds.length; i += 2) ...[
          if (i + 1 < kinds.length)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: CalculatorTile(kinds[i], india: india)),
                  const SizedBox(width: 12),
                  Expanded(child: CalculatorTile(kinds[i + 1], india: india)),
                ],
              ),
            )
          else
            CalculatorTile(kinds[i], india: india),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

/// A calculator's tile: its glyph, name and what it works out.
class CalculatorTile extends StatelessWidget {
  const CalculatorTile(this.kind, {required this.india, super.key});

  final CalculatorKind kind;
  final bool india;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AppCard(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('calculation:${kind.name}'),
        onTap: () => context.push(kind.route),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox.square(
                    dimension: 40,
                    child: IconWell(kind.icon, size: 22, color: cs.secondary),
                  ),
                  const Spacer(),
                  AppIcon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                kind.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                kind.subtitleFor(india: india),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
