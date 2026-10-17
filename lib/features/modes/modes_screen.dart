import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/database.dart';
import '../../data/mode_providers.dart';
import '../../data/tables.dart';
import 'mode_detail_screen.dart';
import 'mode_modules.dart';
import 'mode_widgets.dart';

/// More → Modes: every trip or event — the one that's ON, the planned ones
/// and the ones that are over.
class ModesScreen extends ConsumerWidget {
  const ModesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final modesAsync = ref.watch(modesProvider);
    final modes = modesAsync.valueOrNull ?? const <ModeRow>[];
    final sections = [
      (
        'ON',
        [
          for (final m in modes)
            if (m.status == ModeStatus.active) m,
        ],
      ),
      (
        'PLANNED',
        [
          for (final m in modes)
            if (m.status == ModeStatus.planned) m,
        ],
      ),
      (
        'ENDED',
        [
          for (final m in modes)
            if (m.status == ModeStatus.ended) m,
        ],
      ),
    ];

    return Scaffold(
      appBar: AppTopBar(
        title: const Text('Modes'),
        actions: [
          IconButton(
            icon: const AppIcon(Icons.add_rounded),
            tooltip: 'New mode',
            onPressed: () => showNewModeSheet(context),
          ),
        ],
      ),
      body: modesAsync.isLoading && modes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                8,
                20,
                32,
              ).plusNavBar(context),
              children: [
                if (modes.isEmpty) const _Intro(),
                for (final (title, list) in sections)
                  if (list.isNotEmpty) ...[
                    modeSectionLabel(theme, title),
                    for (final m in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ModeCard(mode: m),
                      ),
                  ],
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => showNewModeSheet(context),
                  icon: const AppIcon(Icons.add_rounded),
                  label: const Text('New mode'),
                ),
              ],
            ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A mode for every trip',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Switch a mode ON and the app focuses on it: everything you add '
              'joins it, tagged the way you set, from the accounts and '
              'categories you picked. Switch it off and it becomes one line '
              'in your everyday app that opens into the whole story.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends ConsumerWidget {
  const _ModeCard({required this.mode});

  final ModeRow mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(modeSummaryProvider(mode.id));
    return AppCard(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: AppListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: () => context.push('/mode/${mode.id}'),
        leading: ModeBadge(mode),
        title: Text(
          mode.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          modeStatusLine(mode, DateTime.now()),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          modeSpentLabel(summary.spent),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: summary.spent.isZero
                ? theme.colorScheme.onSurfaceVariant
                : AppColors.expense,
          ),
        ),
      ),
    );
  }
}

/// "Start from Trip or Blank", then the editor.
Future<void> showNewModeSheet(BuildContext context) async {
  final preset = await showAppSheet<ModePreset>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'New mode',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final p in ModePreset.all)
            AppListTile(
              leading: CircleAvatar(
                backgroundColor: Color(p.colorValue),
                child: KeyIcon(p.iconKey, color: Colors.white, size: 20),
              ),
              title: Text(p.title),
              subtitle: Text(p.subtitle),
              onTap: () => Navigator.of(context).pop(p),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
  if (preset == null || !context.mounted) return;
  await context.push('/more/modes/new?preset=${preset.key}');
}
