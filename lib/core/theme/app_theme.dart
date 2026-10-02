import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'font_options.dart';
import 'theme_shape.dart';

export 'theme_shape.dart' show SurfaceStyle;

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
    final glass = shape.isGlass;
    final weightDelta = shape.baseWeightDelta + fontWeightDelta;
    final borderSide = BorderSide(color: p.border, width: shape.borderWidth);
    // Sheets and dialogs float over content, so even Glass keeps them nearly
    // opaque — frosted, not see-through.
    final floatingColor = glass ? const Color(0xF2F7F8FC) : null;
    // What separators and incidental outlines draw with. Noir's ink outline
    // would turn every divider into a heavy rule and Glass's white edge would
    // vanish as one, so both separate with a softer tone; their full
    // [borderSide] is kept for cards, chips and inputs.
    final hairline = glass
        ? const Color(0x1A000000)
        : shape.borderWidth > 1
        ? Color.alphaBlend(p.border.withValues(alpha: 0.22), p.surfaceHigh)
        : p.border;

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
      outline: hairline,
      outlineVariant: hairline,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      // Glass pages are transparent; [_BackdropTransitionsBuilder] paints the
      // gradient behind each route instead, so a page in mid-transition never
      // shows the one beneath it through.
      scaffoldBackgroundColor: glass ? Colors.transparent : p.bg,
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
      weightDelta: weightDelta,
    );

    return base.copyWith(
      extensions: [
        AppSurface(
          style: shape.surfaceStyle,
          backdrop: glass ? AppPalettes.glassBackdrop : null,
        ),
      ],
      // Each platform keeps the SDK's own default transition — Glass only
      // slips its backdrop underneath.
      pageTransitionsTheme: glass
          ? PageTransitionsTheme(
              builders: {
                for (final e in base.pageTransitionsTheme.builders.entries)
                  e.key: _BackdropTransitionsBuilder(e.value),
              },
            )
          : null,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: floatingColor,
        modalBackgroundColor: floatingColor,
        surfaceTintColor: Colors.transparent,
        shape: glass
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(cardRadius + 6),
                ),
              )
            : null,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: floatingColor,
        surfaceTintColor: Colors.transparent,
        shape: glass
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(cardRadius),
              )
            : null,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: glass ? Colors.transparent : p.bg,
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
          fontWeight: _shiftWeight(shape.headlineWeight, weightDelta),
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
          side: borderSide,
        ),
      ),
      dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
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
        side: borderSide,
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
        // A Glass input is a lighter frost on its card, not an opaque slab.
        fillColor: glass ? const Color(0x80FFFFFF) : p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: borderSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: borderSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: p.accent,
            width: shape.borderWidth + 0.6,
          ),
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

/// Surface facts a widget can't read off [ColorScheme]: whether cards are
/// frosted, and what the page behind them is painted with.
@immutable
class AppSurface extends ThemeExtension<AppSurface> {
  const AppSurface({required this.style, this.backdrop});

  static const solid = AppSurface(style: SurfaceStyle.solid);

  final SurfaceStyle style;

  /// Painted behind every page when set (Glass). `null` means the page is
  /// the plain `scaffoldBackgroundColor`.
  final Gradient? backdrop;

  bool get isGlass => style == SurfaceStyle.glass;

  static AppSurface of(BuildContext context) =>
      Theme.of(context).extension<AppSurface>() ?? solid;

  @override
  AppSurface copyWith({SurfaceStyle? style, Gradient? backdrop}) => AppSurface(
    style: style ?? this.style,
    backdrop: backdrop ?? this.backdrop,
  );

  @override
  AppSurface lerp(AppSurface? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

/// Paints the theme's [AppSurface.backdrop] behind a page — the full-screen
/// stand-in for `scaffoldBackgroundColor` when the page is a gradient. Use it
/// on any route that builds its own transitions (and so skips
/// [_BackdropTransitionsBuilder]).
class PageBackdrop extends StatelessWidget {
  const PageBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final backdrop = AppSurface.of(context).backdrop;
    if (backdrop == null) return child;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: backdrop),
      child: child,
    );
  }
}

/// [inner]'s transition, around a page that carries its own backdrop — so
/// transparent Glass scaffolds stay opaque as whole routes.
class _BackdropTransitionsBuilder extends PageTransitionsBuilder {
  const _BackdropTransitionsBuilder(this.inner);

  final PageTransitionsBuilder inner;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      inner.delegatedTransition;

  @override
  Duration get transitionDuration => inner.transitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => inner.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    PageBackdrop(child: child),
  );
}
