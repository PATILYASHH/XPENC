import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/font_options.dart';
import '../../data/providers.dart';

/// Text size, boldness and font family — three global reading-comfort knobs,
/// each applied over the whole app (see `AppTheme.of` and `XpencApp`'s
/// `TextScaler`), not just this screen. Every control writes straight to the
/// database, so the preview card above them shows the real effect live, the
/// same way [ThemePickerSheet]'s swatches preview a palette by *being* one.
class FontSettingsScreen extends ConsumerWidget {
  const FontSettingsScreen({super.key});

  static const _minScale = 80;
  static const _maxScale = 150;
  static const _minWeight = -2;
  static const _maxWeight = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final db = ref.read(dbProvider);

    final scale = ref.watch(fontScalePercentProvider);
    final weightDelta = ref.watch(fontWeightDeltaProvider);
    final family = ref.watch(fontFamilyProvider);

    final isDefault =
        scale == 100 && weightDelta == 0 && family == AppFontFamily.system;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Font'),
        actions: [
          IconButton(
            tooltip: 'Reset to default',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: isDefault
                ? null
                : () async {
                    await db.setFontScalePercent(100);
                    await db.setFontWeightDelta(0);
                    await db.setFontFamily(null);
                  },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _PreviewCard(family: family),
          const SizedBox(height: 20),
          _sectionLabel(context, 'Text size'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Size',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '$scale%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'A',
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: scale.toDouble(),
                          min: _minScale.toDouble(),
                          max: _maxScale.toDouble(),
                          divisions: (_maxScale - _minScale) ~/ 5,
                          label: '$scale%',
                          onChanged: (v) => db.setFontScalePercent(v.round()),
                        ),
                      ),
                      Text(
                        'A',
                        style: TextStyle(
                          fontSize: 26,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, 'Boldness'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Weight',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _weightLabel(weightDelta),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'B',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: weightDelta.toDouble(),
                          min: _minWeight.toDouble(),
                          max: _maxWeight.toDouble(),
                          divisions: _maxWeight - _minWeight,
                          label: _weightLabel(weightDelta),
                          onChanged: (v) => db.setFontWeightDelta(v.round()),
                        ),
                      ),
                      Text(
                        'B',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, 'Font family'),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < AppFontFamily.values.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 60, color: cs.outline),
                  _FontFamilyTile(
                    option: AppFontFamily.values[i],
                    selected: AppFontFamily.values[i] == family,
                    onTap: () => db.setFontFamily(
                      AppFontFamily.values[i] == AppFontFamily.system
                          ? null
                          : AppFontFamily.values[i].name,
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

  Widget _sectionLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  // "Normal", not "Default" — the font-family list below already uses
  // "Default" for its own zero state, and showing both on one screen read as
  // if they were the same choice.
  String _weightLabel(int delta) => switch (delta) {
    <= -2 => 'Lighter',
    -1 => 'Light',
    0 => 'Normal',
    1 => 'Bold',
    _ => 'Bolder',
  };
}

/// A sentence and a money amount, rendered through the live theme — exactly
/// what the rest of the app will look like once the sliders below are moved.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.family});

  final AppFontFamily family;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grocery Shopping', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Food & Dining · Today',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '- ₹1,240.00',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FontFamilyTile extends StatelessWidget {
  const _FontFamilyTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppFontFamily option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: SizedBox(
        width: 32,
        child: Text(
          'Aa',
          style: TextStyle(fontSize: 20, fontFamily: option.family),
        ),
      ),
      title: Text(option.label, style: TextStyle(fontFamily: option.family)),
      subtitle: Text(
        option.description,
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: cs.secondary)
          : null,
      onTap: onTap,
    );
  }
}
