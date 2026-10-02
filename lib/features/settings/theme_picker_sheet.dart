import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_preset.dart';
import '../../core/theme/theme_shape.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/motion.dart';
import '../../data/providers.dart';

/// Pick a theme: a style, then — for styles that come in both — light, dark
/// or follow the device. Each style row previews the palette it will apply,
/// so the choice is made by looking rather than by reading.
class ThemePickerSheet extends ConsumerWidget {
  const ThemePickerSheet({super.key});

  static Future<void> show(BuildContext context) => showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const ThemePickerSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(themeChoiceProvider);
    final platform = MediaQuery.platformBrightnessOf(context);

    void save(ThemeChoice choice) =>
        ref.read(dbProvider).setThemeName(choice.storageName);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_rounded, color: theme.colorScheme.secondary),
                const SizedBox(width: 10),
                Text(
                  'Theme',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Money colours never change — green is always income.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < ThemeStyle.values.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Reveal(
                index: i,
                child: _PresetTile(
                  choice: current.withStyle(ThemeStyle.values[i]),
                  selected: ThemeStyle.values[i] == current.style,
                  platformBrightness: platform,
                  onTap: () => save(current.withStyle(ThemeStyle.values[i])),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Appearance',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: current.style.supportsModes
                  ? SizedBox(
                      key: const ValueKey('modes'),
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_rounded),
                            label: Text('System'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_rounded),
                            label: Text('Light'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_rounded),
                            label: Text('Dark'),
                          ),
                        ],
                        selected: {current.mode},
                        onSelectionChanged: (s) =>
                            save(current.withMode(s.first)),
                      ),
                    )
                  : Text(
                      key: const ValueKey('fixed'),
                      '${current.style.label} comes in light only. Your '
                      'light/dark choice is kept for the other themes.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.choice,
    required this.selected,
    required this.platformBrightness,
    required this.onTap,
  });

  final ThemeChoice choice;
  final bool selected;
  final Brightness platformBrightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final style = choice.style;
    final palette = choice.resolve(platformBrightness);

    return PressScale(
      child: Material(
        // A tile is a card, not a groove: it takes the card tone.
        color: selected
            ? cs.secondary.withValues(alpha: 0.08)
            : theme.cardTheme.color ?? cs.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? cs.secondary : cs.outline,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                _Swatch(palette: palette, shape: style.shape),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(style.icon, size: 16, color: cs.onSurface),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              style.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        style.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: cs.secondary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A miniature of the theme: its page, a card on it, and the accent. The
/// card's own corner scales with [shape], and Glass's page is its gradient —
/// each style shows at a glance, the same way its colour shows in the fill.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.palette, required this.shape});

  final Palette palette;
  final ThemeShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        // Glass's page is its gradient, not a flat tone.
        color: shape.isGlass ? null : palette.bg,
        gradient: shape.isGlass ? AppPalettes.glassBackdrop : null,
        borderRadius: BorderRadius.circular(shape.controlRadius * 0.7),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: palette.surfaceHigh,
                borderRadius: BorderRadius.circular(shape.cardRadius / 6),
                border: Border.all(color: palette.border),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                // Income green, always. It is the point of the sentence above.
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.income,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
