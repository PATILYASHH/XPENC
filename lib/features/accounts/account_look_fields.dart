import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/icon_picker_sheet.dart';
import '../../core/l10n/l10n.dart';

/// Preset colours for an account. Plain ints — colour here is decorative,
/// not a money-direction signal.
const accountPresetColors = <int>[
  0xFF16A34A,
  0xFF2563EB,
  0xFFDC2626,
  0xFFA855F7,
  0xFFF97316,
  0xFF0EA5E9,
  0xFF78716C,
  0xFFEC4899,
];

/// The row of colour dots shared by the Add and Edit account sheets. A
/// [selected] colour outside the presets (an account from an older version)
/// leads the row, so editing never silently swaps it for a preset.
class AccountColorPicker extends StatelessWidget {
  const AccountColorPicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        if (!accountPresetColors.contains(selected)) _dot(theme, selected),
        for (final c in accountPresetColors) _dot(theme, c),
      ],
    );
  }

  Widget _dot(ThemeData theme, int value) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Color(value),
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: theme.colorScheme.onSurface, width: 2.5)
              : null,
        ),
        child: isSelected
            ? const AppIcon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

/// A single tile showing the chosen icon; tapping it opens the searchable
/// icon sheet instead of a fixed row limited to the account types.
class AccountIconField extends StatelessWidget {
  const AccountIconField({
    required this.iconKey,
    required this.colorValue,
    required this.onChanged,
    super.key,
  });

  final String iconKey;
  final int colorValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(colorValue);
    return GestureDetector(
      onTap: () async {
        final picked = await showIconPickerSheet(
          context,
          selected: iconKey,
          accentColor: color,
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: AppIcon(AppIcons.resolve(iconKey), color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Tr(
                'Tap to change',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            AppIcon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
