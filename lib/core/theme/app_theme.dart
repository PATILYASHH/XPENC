import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// One UI–inspired: large rounded cards, generous spacing, big titles.
/// The chrome is whatever [Palette] it is handed; money colours never change.
class AppTheme {
  const AppTheme._();

  static const _radius = 20.0;
  static const _cardRadius = 24.0;

  /// The default monochrome pair, used before a preference has loaded.
  static ThemeData get light => of(AppPalettes.monoLight);
  static ThemeData get dark => of(AppPalettes.monoDark);

  static ThemeData of(Palette p) {
    final isDark = p.brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.accent,
      onSecondary: Colors.white,
      error: AppColors.expense,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.text,
      // Cards read `surfaceHigh` straight off `cardTheme`. This role is what
      // progress bars, chips and wells fill themselves with, so it has to be a
      // *recessed* tone — otherwise an empty bar on a card is invisible.
      surfaceContainerHighest: p.track,
      onSurfaceVariant: p.textMuted,
      outline: p.border,
      outlineVariant: p.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: base.textTheme.headlineSmall?.copyWith(
          color: p.text,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
          side: BorderSide(color: p.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: p.textMuted,
        textColor: p.text,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceHigh,
        selectedColor: p.accent.withValues(alpha: 0.14),
        checkmarkColor: p.accent,
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: base.textTheme.labelLarge?.copyWith(color: p.text),
        secondaryLabelStyle: base.textTheme.labelLarge?.copyWith(
          color: p.accent,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // ⚠️ `Size.fromHeight` means `Size(double.infinity, 56)` — an infinite
          // MINIMUM WIDTH. Buttons stretch full-width in a Column (the One UI
          // look we want), but a Row gives non-flex children unbounded width and
          // this then throws `BoxConstraints forces an infinite width`.
          // A FilledButton inside a Row must override `minimumSize` or be
          // wrapped in Expanded/Flexible.
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: p.accent, width: 1.6),
        ),
      ),
      textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
