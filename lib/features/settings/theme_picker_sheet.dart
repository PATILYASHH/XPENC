import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_preset.dart';
import '../../core/widgets/motion.dart';
import '../../data/providers.dart';

/// Pick a theme. Each row previews the palette it will apply, so the choice is
/// made by looking rather than by reading.
class ThemePickerSheet extends ConsumerWidget {
  const ThemePickerSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const ThemePickerSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(themePresetProvider);
    final platform = MediaQuery.platformBrightnessOf(context);

    return SafeArea(
      child: Padding(
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
            for (var i = 0; i < ThemePreset.values.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Reveal(
                index: i,
                child: _PresetTile(
                  preset: ThemePreset.values[i],
                  selected: ThemePreset.values[i] == current,
                  platformBrightness: platform,
                  onTap: () => ref
                      .read(dbProvider)
                      .setThemeName(ThemePreset.values[i].name),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.platformBrightness,
    required this.onTap,
  });

  final ThemePreset preset;
  final bool selected;
  final Brightness platformBrightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final palette = preset.resolve(platformBrightness);

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
                _Swatch(palette: palette),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(preset.icon, size: 16, color: cs.onSurface),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              preset.label,
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
                        preset.description,
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

/// A miniature of the theme: its page, a card on it, and the accent.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.palette});

  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(14),
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
                borderRadius: BorderRadius.circular(4),
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
