import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The themes a user can pick, as a flat list — "System, Light, Dark,
/// Colourful, Midnight" is what a person expects to see, not a matrix of
/// brightness × palette.
///
/// The name is what gets written to the database, so **never rename a value**.
/// Add new ones at the end.
enum ThemePreset {
  system(
    label: 'System',
    description: 'Follows your device',
    icon: Icons.brightness_auto_rounded,
    mode: ThemeMode.system,
    lightPalette: AppPalettes.monoLight,
    darkPalette: AppPalettes.monoDark,
  ),
  light(
    label: 'Light',
    description: 'Clean and monochrome',
    icon: Icons.light_mode_rounded,
    mode: ThemeMode.light,
    lightPalette: AppPalettes.monoLight,
    darkPalette: AppPalettes.monoLight,
  ),
  dark(
    label: 'Dark',
    description: 'True black, easy on AMOLED',
    icon: Icons.dark_mode_rounded,
    mode: ThemeMode.dark,
    lightPalette: AppPalettes.monoDark,
    darkPalette: AppPalettes.monoDark,
  ),
  colourful(
    label: 'Colourful',
    description: 'Violet chrome, follows your device',
    icon: Icons.palette_rounded,
    mode: ThemeMode.system,
    lightPalette: AppPalettes.vividLight,
    darkPalette: AppPalettes.vividDark,
  ),
  midnight(
    label: 'Midnight',
    description: 'Deep navy with a cyan accent',
    icon: Icons.nights_stay_rounded,
    mode: ThemeMode.dark,
    lightPalette: AppPalettes.midnight,
    darkPalette: AppPalettes.midnight,
  );

  const ThemePreset({
    required this.label,
    required this.description,
    required this.icon,
    required this.mode,
    required this.lightPalette,
    required this.darkPalette,
  });

  final String label;
  final String description;
  final IconData icon;

  /// How the two palettes below are chosen. A preset that forces one brightness
  /// stores the same palette in both slots, so [mode] alone decides.
  final ThemeMode mode;
  final Palette lightPalette;
  final Palette darkPalette;

  /// The palette actually shown, for previews and swatches.
  Palette resolve(Brightness platformBrightness) => switch (mode) {
        ThemeMode.light => lightPalette,
        ThemeMode.dark => darkPalette,
        ThemeMode.system => platformBrightness == Brightness.dark
            ? darkPalette
            : lightPalette,
      };

  static const fallback = ThemePreset.system;

  /// Parse a value previously written by [name]. An unknown string (a downgrade,
  /// a hand-edited row) falls back rather than crashing the whole app.
  static ThemePreset fromName(String? name) {
    for (final preset in values) {
      if (preset.name == name) return preset;
    }
    return fallback;
  }
}
