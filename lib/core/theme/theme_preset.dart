import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'theme_shape.dart';

/// The themes a user can pick, as a flat list — "System, Light, Dark,
/// Colourful, Midnight, Cove" is what a person expects to see, not a matrix of
/// brightness × palette × shape.
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
    shape: ThemeShape.classic,
  ),
  light(
    label: 'Light',
    description: 'Clean and monochrome',
    icon: Icons.light_mode_rounded,
    mode: ThemeMode.light,
    lightPalette: AppPalettes.monoLight,
    darkPalette: AppPalettes.monoLight,
    shape: ThemeShape.classic,
  ),
  dark(
    label: 'Dark',
    description: 'True black, easy on AMOLED',
    icon: Icons.dark_mode_rounded,
    mode: ThemeMode.dark,
    lightPalette: AppPalettes.monoDark,
    darkPalette: AppPalettes.monoDark,
    shape: ThemeShape.classic,
  ),
  colourful(
    label: 'Colourful',
    description: 'Violet chrome, follows your device',
    icon: Icons.palette_rounded,
    mode: ThemeMode.system,
    lightPalette: AppPalettes.vividLight,
    darkPalette: AppPalettes.vividDark,
    shape: ThemeShape.classic,
  ),
  midnight(
    label: 'Midnight',
    description: 'Deep navy with a cyan accent',
    icon: Icons.nights_stay_rounded,
    mode: ThemeMode.dark,
    lightPalette: AppPalettes.midnight,
    darkPalette: AppPalettes.midnight,
    shape: ThemeShape.classic,
  ),
  cove(
    label: 'Cove',
    description: 'Soft curves, ocean blue — follows your device',
    icon: Icons.water_rounded,
    mode: ThemeMode.system,
    lightPalette: AppPalettes.coveLight,
    darkPalette: AppPalettes.coveDark,
    shape: ThemeShape.soft,
  );

  const ThemePreset({
    required this.label,
    required this.description,
    required this.icon,
    required this.mode,
    required this.lightPalette,
    required this.darkPalette,
    required this.shape,
  });

  final String label;
  final String description;
  final IconData icon;

  /// How the two palettes below are chosen. A preset that forces one brightness
  /// stores the same palette in both slots, so [mode] alone decides.
  final ThemeMode mode;
  final Palette lightPalette;
  final Palette darkPalette;

  /// Card/control radius and headline weight — see [ThemeShape].
  final ThemeShape shape;

  /// The palette actually shown, for previews and swatches.
  Palette resolve(Brightness platformBrightness) => switch (mode) {
    ThemeMode.light => lightPalette,
    ThemeMode.dark => darkPalette,
    ThemeMode.system =>
      platformBrightness == Brightness.dark ? darkPalette : lightPalette,
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
