import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'font_options.dart';
import 'glass.dart';
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
    // Glass sheets and dialogs open over a blurred page (see
    // `showAppSheet`/`showAppDialog`), so they can stay translucent.
    final floatingColor = glass ? GlassStyle.floating : null;
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
      // Material paints menus, date pickers and dropdowns with these, over
      // content and with no blur behind — Glass keeps them near-opaque.
      surfaceContainerLowest: glass ? GlassStyle.solidFrost : null,
      surfaceContainerLow: glass ? GlassStyle.solidFrost : null,
      surfaceContainer: glass ? GlassStyle.solidFrost : null,
      surfaceContainerHigh: glass ? GlassStyle.solidFrost : null,
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
      // Dropdown menus and plain `Material`s: see `surfaceContainer` above.
      canvasColor: glass ? GlassStyle.solidFrost : null,
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

    final theme = base.copyWith(
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
      popupMenuTheme: glass
          ? const PopupMenuThemeData(color: GlassStyle.solidFrost)
          : null,
      datePickerTheme: glass
          ? const DatePickerThemeData(
              backgroundColor: GlassStyle.solidFrost,
              surfaceTintColor: Colors.transparent,
            )
          : null,
      timePickerTheme: glass
          ? const TimePickerThemeData(backgroundColor: GlassStyle.solidFrost)
          : null,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: floatingColor,
        modalBackgroundColor: floatingColor,
        modalBarrierColor: glass ? GlassStyle.barrier : null,
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
        barrierColor: glass ? GlassStyle.barrier : null,
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
        fillColor: glass ? const Color(0x66FFFFFF) : p.surface,
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
    return glass ? _liquidGlass(theme, p, shape) : theme;
  }

  /// Glass's controls, modelled on iOS: capsule buttons, the iOS switch,
  /// plain filled fields, hairline separators, Cupertino page transitions
  /// (with swipe-back), glass back buttons, no Material ripple, and SF-like
  /// tracking on Inter.
  static ThemeData _liquidGlass(ThemeData t, Palette p, ThemeShape shape) {
    const stadium = StadiumBorder();
    const separator = Color(0x243C3C43);
    const iosGreen = Color(0xFF34C759);
    const fill = Color(0x9EFFFFFF);
    final text = t.textTheme;

    TextStyle? track(TextStyle? s, double spacing) =>
        s?.copyWith(letterSpacing: spacing);

    return t.copyWith(
      splashFactory: NoSplash.splashFactory,
      highlightColor: const Color(0x14000000),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const _BackdropTransitionsBuilder(
              CupertinoPageTransitionsBuilder(),
            ),
        },
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) =>
            const GlassNavGlyph(CupertinoIcons.chevron_back),
        closeButtonIconBuilder: (_) => const GlassNavGlyph(CupertinoIcons.xmark),
      ),
      appBarTheme: t.appBarTheme.copyWith(
        centerTitle: true,
        titleTextStyle: text.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.45,
          color: p.text,
        ),
      ),
      textTheme: text.copyWith(
        displayLarge: track(text.displayLarge, -1.2),
        displayMedium: track(text.displayMedium, -1.0),
        displaySmall: track(text.displaySmall, -0.9),
        headlineLarge: track(text.headlineLarge, -0.8),
        headlineMedium: track(text.headlineMedium, -0.7),
        headlineSmall: track(text.headlineSmall, -0.6),
        titleLarge: track(text.titleLarge, -0.45),
        titleMedium: track(text.titleMedium, -0.3),
        titleSmall: track(text.titleSmall, -0.2),
        bodyLarge: track(text.bodyLarge, -0.25),
        bodyMedium: track(text.bodyMedium, -0.15),
        bodySmall: track(text.bodySmall, -0.05),
        labelLarge: track(text.labelLarge, -0.15),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: stadium,
          backgroundColor: p.accent,
          foregroundColor: Colors.white,
          // From the text theme, so the label stays in Inter.
          textStyle: text.labelLarge?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: stadium,
          backgroundColor: fill,
          foregroundColor: p.text,
          side: const BorderSide(color: Color(0xE6FFFFFF)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: stadium, foregroundColor: p.accent),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: stadium,
          backgroundColor: fill,
          foregroundColor: p.accent,
          elevation: 0,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 6,
        highlightElevation: 2,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? iosGreen
              : const Color(0x29787880),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbIcon: const WidgetStatePropertyAll(null),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : null,
        ),
      ),
      chipTheme: t.chipTheme.copyWith(
        backgroundColor: fill,
        selectedColor: p.accent.withValues(alpha: 0.16),
        side: const BorderSide(color: Color(0xD9FFFFFF)),
        shape: stadium,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(stadium),
          side: const WidgetStatePropertyAll(BorderSide(color: separator)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? Colors.white
                : const Color(0x33FFFFFF),
          ),
          foregroundColor: WidgetStatePropertyAll(p.text),
        ),
      ),
      inputDecorationTheme: t.inputDecorationTheme.copyWith(
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shape.controlRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shape.controlRadius),
          borderSide: const BorderSide(color: Color(0xB3FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shape.controlRadius),
          borderSide: BorderSide(color: p.accent, width: 1.6),
        ),
      ),
      listTileTheme: t.listTileTheme.copyWith(iconColor: p.accent),
      dividerTheme: const DividerThemeData(
        color: separator,
        thickness: 0.6,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: const Color(0x1F787880),
        circularTrackColor: const Color(0x1F787880),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xF21C1C1E),
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: const Color(0xFF64A8FF),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dialogTheme: t.dialogTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        titleTextStyle: text.titleLarge?.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: p.text,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: GlassStyle.solidFrost,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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

/// Paints the Glass wallpaper behind a page — the full-screen stand-in for
/// `scaffoldBackgroundColor` when the page is a [GlassWallpaper]. Use it
/// on any route that builds its own transitions (and so skips
/// [_BackdropTransitionsBuilder]).
class PageBackdrop extends StatelessWidget {
  const PageBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AppSurface.of(context).backdrop == null) return child;
    // One BackdropGroup per page: every card on it shares a single read of
    // the wallpaper instead of each re-reading it. The RepaintBoundary keeps
    // content changes from repainting the wallpaper.
    return BackdropGroup(
      child: GlassWallpaper(child: RepaintBoundary(child: child)),
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
