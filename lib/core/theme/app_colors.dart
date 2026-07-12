import 'package:flutter/material.dart';

/// Semantic colour is reserved for money direction only — it must always
/// *mean* something, and it must mean the same thing in every theme. Green is
/// income whether the app is monochrome or violet; a theme may never repaint it.
class AppColors {
  const AppColors._();

  /// Money in.
  static const income = Color(0xFF16A34A);

  /// Money out.
  static const expense = Color(0xFFDC2626);

  /// Neither in nor out — moves between your own accounts.
  static const transfer = Color(0xFF2563EB);

  /// Money moved to or from a person. It leaves (or enters) your account, but
  /// lending is not spending and being repaid is not earning — so it wears
  /// neither green nor red.
  static const person = Color(0xFFA855F7);

  /// The default accent, used when no theme is loaded yet. Live code should
  /// read the accent off the theme (`colorScheme.secondary`) so it follows the
  /// palette the user picked.
  static const accent = Color(0xFF2563EB);
}

/// Every colour a theme varies. Semantic money colours are deliberately absent.
///
/// The two rules a palette must obey:
///  * [surfaceHigh] (cards) must be clearly distinct from [bg] (the page), or
///    cards dissolve into the background.
///  * [track] must read as a groove against [surfaceHigh], or an empty progress
///    bar is invisible.
@immutable
class Palette {
  const Palette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.track,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.primary,
    required this.onPrimary,
  });

  final Brightness brightness;

  /// The page, behind the cards.
  final Color bg;

  /// Page-level surface: app bars, sheets, input fills.
  final Color surface;

  /// Cards — raised above [bg].
  final Color surfaceHigh;

  /// The unfilled part of a progress bar.
  final Color track;

  final Color border;
  final Color text;
  final Color textMuted;

  /// Interactive accent: the ➕ button, focus rings, links.
  final Color accent;

  /// Filled buttons and badges. Monochrome palettes make this the text colour;
  /// vivid palettes make it the accent.
  final Color primary;
  final Color onPrimary;
}

/// The palettes the presets are built from.
class AppPalettes {
  const AppPalettes._();

  // ── Monochrome: minimal chrome, one accent ───────────────────────────────
  static const monoLight = Palette(
    brightness: Brightness.light,
    bg: Color(0xFFF2F2F5),
    surface: Color(0xFFF2F2F5),
    surfaceHigh: Color(0xFFFFFFFF),
    track: Color(0xFFE5E5EA),
    border: Color(0xFFDBDBE1),
    text: Color(0xFF0A0A0B),
    textMuted: Color(0xFF6B6B70),
    accent: Color(0xFF2563EB),
    primary: Color(0xFF0A0A0B),
    onPrimary: Color(0xFFFFFFFF),
  );

  /// True black, AMOLED friendly.
  static const monoDark = Palette(
    brightness: Brightness.dark,
    bg: Color(0xFF000000),
    surface: Color(0xFF0E0E10),
    surfaceHigh: Color(0xFF17171A),
    track: Color(0xFF232328),
    border: Color(0xFF2F2F35),
    text: Color(0xFFF5F5F6),
    textMuted: Color(0xFF9A9AA0),
    accent: Color(0xFF3B82F6),
    primary: Color(0xFFF5F5F6),
    onPrimary: Color(0xFF0A0A0B),
  );

  // ── Vivid: violet chrome ─────────────────────────────────────────────────
  static const vividLight = Palette(
    brightness: Brightness.light,
    bg: Color(0xFFF6F4FF),
    surface: Color(0xFFF6F4FF),
    surfaceHigh: Color(0xFFFFFFFF),
    track: Color(0xFFE9E3FB),
    border: Color(0xFFDCD3F7),
    text: Color(0xFF1A1330),
    textMuted: Color(0xFF6C6484),
    accent: Color(0xFF7C3AED),
    primary: Color(0xFF7C3AED),
    onPrimary: Color(0xFFFFFFFF),
  );

  static const vividDark = Palette(
    brightness: Brightness.dark,
    bg: Color(0xFF0F0B1E),
    surface: Color(0xFF15102A),
    surfaceHigh: Color(0xFF1C1636),
    track: Color(0xFF2A2148),
    border: Color(0xFF352B57),
    text: Color(0xFFF3F0FF),
    textMuted: Color(0xFFA69FC4),
    accent: Color(0xFFA78BFA),
    primary: Color(0xFFA78BFA),
    onPrimary: Color(0xFF1A1030),
  );

  // ── Midnight: deep navy, cyan accent. Dark only. ─────────────────────────
  static const midnight = Palette(
    brightness: Brightness.dark,
    bg: Color(0xFF060B18),
    surface: Color(0xFF0B1224),
    surfaceHigh: Color(0xFF111A31),
    track: Color(0xFF1B2745),
    border: Color(0xFF24324F),
    text: Color(0xFFE8EEF9),
    textMuted: Color(0xFF92A2BF),
    accent: Color(0xFF38BDF8),
    primary: Color(0xFF38BDF8),
    onPrimary: Color(0xFF04121F),
  );
}

/// Convenience so widgets can read semantic colours off the theme.
extension MoneyColors on ThemeData {
  Color get incomeColor => AppColors.income;
  Color get expenseColor => AppColors.expense;
  Color get transferColor => AppColors.transfer;

  /// The live accent for the palette in use.
  Color get accentColor => colorScheme.secondary;
}
