import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'theme_shape.dart';

/// The looks a user can pick — "Classic, Noir, Glass" is what a person expects
/// to see. Brightness is a separate, smaller choice ([ThemeChoice.mode]) that
/// every style except Glass offers.
///
/// The name is what gets written to the database, so **never rename a value**.
/// Add new ones at the end.
enum ThemeStyle {
  classic(
    label: 'Classic',
    description: 'Clean and monochrome',
    icon: Icons.contrast_rounded,
    lightPalette: AppPalettes.monoLight,
    darkPalette: AppPalettes.monoDark,
    shape: ThemeShape.classic,
  ),
  noir(
    label: 'Noir',
    description: 'Heavy type, ink outlines, coral & gold',
    icon: Icons.bolt_rounded,
    lightPalette: AppPalettes.noirLight,
    darkPalette: AppPalettes.noirDark,
    shape: ThemeShape.noir,
  ),
  glass(
    label: 'Glass',
    description: 'Frosted panes over a soft gradient — light only',
    icon: Icons.blur_on_rounded,
    lightPalette: AppPalettes.glass,
    darkPalette: AppPalettes.glass,
    shape: ThemeShape.glass,
    fixedMode: ThemeMode.light,
  );

  const ThemeStyle({
    required this.label,
    required this.description,
    required this.icon,
    required this.lightPalette,
    required this.darkPalette,
    required this.shape,
    this.fixedMode,
  });

  final String label;
  final String description;
  final IconData icon;
  final Palette lightPalette;
  final Palette darkPalette;

  /// Card/control radius, weights and surface treatment — see [ThemeShape].
  final ThemeShape shape;

  /// Set when the style only exists in one brightness: the user's mode
  /// choice is ignored (and hidden in the picker) while it is active.
  final ThemeMode? fixedMode;

  bool get supportsModes => fixedMode == null;

  static ThemeStyle? _byName(String name) {
    for (final style in values) {
      if (style.name == name) return style;
    }
    return null;
  }
}

/// What the user picked: a [style] and, for styles that offer it, a [mode].
///
/// Stored in `Settings.themeName` as `style` (follow the device) or
/// `style:light` / `style:dark` — so the split needs no new column, and an
/// older build reading a newer value degrades to its own default rather than
/// failing.
@immutable
class ThemeChoice {
  const ThemeChoice(this.style, [this.mode = ThemeMode.system]);

  final ThemeStyle style;

  /// The user's own preference, kept even while a fixed-mode style is active
  /// so switching back to Classic restores it.
  final ThemeMode mode;

  static const fallback = ThemeChoice(ThemeStyle.classic);

  /// The mode actually applied.
  ThemeMode get effectiveMode => style.fixedMode ?? mode;

  /// The palette actually shown, for previews and swatches.
  Palette resolve(Brightness platformBrightness) {
    final dark = switch (effectiveMode) {
      ThemeMode.light => false,
      ThemeMode.dark => true,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };
    return dark ? style.darkPalette : style.lightPalette;
  }

  ThemeChoice withStyle(ThemeStyle s) => ThemeChoice(s, mode);
  ThemeChoice withMode(ThemeMode m) => ThemeChoice(style, m);

  String get storageName => switch (mode) {
    ThemeMode.system => style.name,
    ThemeMode.light => '${style.name}:light',
    ThemeMode.dark => '${style.name}:dark',
  };

  /// Parse a value previously written by [storageName] — or by an older
  /// build, whose flat presets map onto the nearest style here. An unknown
  /// string (a downgrade, a hand-edited row) falls back rather than crashing
  /// the whole app.
  static ThemeChoice parse(String? raw) {
    if (raw == null || raw.isEmpty) return fallback;
    final legacy = _legacy[raw];
    if (legacy != null) return legacy;

    final parts = raw.split(':');
    final style = ThemeStyle._byName(parts.first);
    if (style == null || parts.length > 2) return fallback;
    final mode = parts.length == 1
        ? ThemeMode.system
        : switch (parts[1]) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          };
    return ThemeChoice(style, mode);
  }

  /// The presets before styles existed (≤ 1.6.x). Colourful, Midnight and
  /// Cove were retired into Classic; a forced brightness is carried over so
  /// nobody's dark mode disappears. Bold was renamed Noir and was dark-only.
  /// `classic` itself is absent: it parses as a style.
  static const _legacy = <String, ThemeChoice>{
    'system': ThemeChoice(ThemeStyle.classic),
    'mono': ThemeChoice(ThemeStyle.classic),
    'light': ThemeChoice(ThemeStyle.classic, ThemeMode.light),
    'dark': ThemeChoice(ThemeStyle.classic, ThemeMode.dark),
    'colourful': ThemeChoice(ThemeStyle.classic),
    'cove': ThemeChoice(ThemeStyle.classic),
    'midnight': ThemeChoice(ThemeStyle.classic, ThemeMode.dark),
    'bold': ThemeChoice(ThemeStyle.noir, ThemeMode.dark),
  };

  @override
  bool operator ==(Object other) =>
      other is ThemeChoice && other.style == style && other.mode == mode;

  @override
  int get hashCode => Object.hash(style, mode);

  @override
  String toString() => 'ThemeChoice($storageName)';
}
