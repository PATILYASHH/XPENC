import 'package:flutter/material.dart';

/// Minimal, monochrome chrome + one accent. Semantic colour is reserved for
/// money direction only — it must always *mean* something.
class AppColors {
  const AppColors._();

  // ── Semantic (money direction) ───────────────────────────────────────────
  /// Money in.
  static const income = Color(0xFF16A34A);

  /// Money out.
  static const expense = Color(0xFFDC2626);

  /// Neither in nor out — moves between your own accounts.
  static const transfer = Color(0xFF2563EB);

  /// The one accent. Interactive elements only.
  static const accent = Color(0xFF2563EB);

  // ── Light ────────────────────────────────────────────────────────────────
  static const lightBg = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFF7F7F8);
  static const lightSurfaceHigh = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE6E6E8);
  static const lightText = Color(0xFF0A0A0B);
  static const lightTextMuted = Color(0xFF6B6B70);

  // ── Dark (true black, AMOLED friendly) ───────────────────────────────────
  static const darkBg = Color(0xFF000000);
  static const darkSurface = Color(0xFF0E0E10);
  static const darkSurfaceHigh = Color(0xFF17171A);
  static const darkBorder = Color(0xFF26262A);
  static const darkText = Color(0xFFF5F5F6);
  static const darkTextMuted = Color(0xFF9A9AA0);
}

/// Convenience so widgets can read semantic colours off the theme.
extension MoneyColors on ThemeData {
  Color get incomeColor => AppColors.income;
  Color get expenseColor => AppColors.expense;
  Color get transferColor => AppColors.transfer;
}
