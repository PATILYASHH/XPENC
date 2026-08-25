import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'font_options.dart';
import 'theme_shape.dart';

/// One UI–inspired: large rounded cards, generous spacing, big titles.
/// The chrome is whatever [Palette]/[ThemeShape] it is handed; money colours
/// never change.
class AppTheme {
  const AppTheme._();

  /// The default monochrome pair, used before a preference has loaded.
  static ThemeData get light => of(AppPalettes.monoLight, ThemeShape.classic);
  static ThemeData get dark => of(AppPalettes.monoDark, ThemeShape.classic);

  static ThemeData of(
    Palette p,
    ThemeShape shape, {
    AppFontFamily fontFamily = AppFontFamily.system,
    int fontWeightDelta = 0,
  }) {
    final isDark = p.brightness == Brightness.dark;
    final radius = shape.controlRadius;
    final cardRadius = shape.cardRadius;

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

    // An explicit font choice wins over the theme's own split — a user who
    // picked "Serif" expects it everywhere, not just on working text. Left
    // at [AppFontFamily.system] (the default), each field falls through to
    // `shape`'s own family, unchanged from before this setting existed.
    final displayFamily = fontFamily.family ?? shape.displayFontFamily;
    final bodyFamily = fontFamily.family ?? shape.bodyFontFamily;

    final textTheme = _typeset(
      base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
      displayFamily: displayFamily,
      bodyFamily: bodyFamily,
      weightDelta: fontWeightDelta,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: base.textTheme.headlineSmall?.copyWith(
          color: p.text,
          fontWeight: _shiftWeight(shape.headlineWeight, fontWeightDelta),
          letterSpacing: shape.headlineLetterSpacing,
          fontFamily: displayFamily,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: p.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: p.textMuted,
        textColor: p.text,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceHigh,
        selectedColor: p.accent.withValues(alpha: 0.14),
        checkmarkColor: p.accent,
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: p.accent, width: 1.6),
        ),
      ),
      textTheme: textTheme,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  /// Applies [displayFamily] to display/headline/title-large — the "showy"
  /// text a theme like Bold gives its own face — and [bodyFamily] to
  /// everything from title-medium down. Either being `null` is a no-op
  /// `copyWith`, so every preset before Bold, and every family left at
  /// [AppFontFamily.system], passes through unchanged. [weightDelta] then
  /// shifts every role's weight by the same number of `FontWeight` rungs.
  static TextTheme _typeset(
    TextTheme t, {
    required String? displayFamily,
    required String? bodyFamily,
    required int weightDelta,
  }) {
    TextStyle? display(TextStyle? s) => s
        ?.copyWith(fontFamily: displayFamily)
        .copyWith(fontWeight: _shiftWeight(s.fontWeight, weightDelta));
    TextStyle? body(TextStyle? s) => s
        ?.copyWith(fontFamily: bodyFamily)
        .copyWith(fontWeight: _shiftWeight(s.fontWeight, weightDelta));

    return t.copyWith(
      displayLarge: display(t.displayLarge),
      displayMedium: display(t.displayMedium),
      displaySmall: display(t.displaySmall),
      headlineLarge: display(t.headlineLarge),
      headlineMedium: display(t.headlineMedium),
      headlineSmall: display(t.headlineSmall),
      titleLarge: display(t.titleLarge),
      titleMedium: body(t.titleMedium),
      titleSmall: body(t.titleSmall),
      bodyLarge: body(t.bodyLarge),
      bodyMedium: body(t.bodyMedium),
      bodySmall: body(t.bodySmall),
      labelLarge: body(t.labelLarge),
      labelMedium: body(t.labelMedium),
      labelSmall: body(t.labelSmall),
    );
  }

  /// Moves [weight] (defaulting to [FontWeight.w400], same as Flutter's own
  /// text styles) by [delta] rungs on the 100–900 scale, clamped so a large
  /// delta can never push weight out of range instead of just capping at the
  /// lightest/boldest available.
  static FontWeight _shiftWeight(FontWeight? weight, int delta) {
    if (delta == 0) return weight ?? FontWeight.w400;
    final index = FontWeight.values.indexOf(weight ?? FontWeight.w400) + delta;
    return FontWeight.values[index.clamp(0, FontWeight.values.length - 1)];
  }
}
