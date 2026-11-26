import 'package:flutter/material.dart';

/// How a theme paints its surfaces — the one structural trait that changes
/// *what* a card is, not just its size.
enum SurfaceStyle {
  /// Opaque cards on a flat page — Classic and Noir.
  solid,

  /// Frosted, translucent cards over a soft gradient page — Glass. Every
  /// route paints its own gradient (see `AppTheme`), so cards need no real
  /// blur: frosting a smooth gradient looks identical to tinting it, at none
  /// of `BackdropFilter`'s cost.
  glass,
}

/// How much a theme moves (read it with `AppMotion`).
enum MotionStyle {
  /// Classic, the working look: motion only confirms what happened. Pages
  /// open with the platform's own push, cut short; nothing springs past
  /// where it lands and nothing staggers in.
  brisk,

  /// Noir: every motion the app has — pages growing out of the bar, rows
  /// assembling — but settling softly, with no visible bounce.
  smooth,

  /// Glass: springs, morphs and overshoot, as iOS moves.
  fluid,
}

/// Every structural (non-colour) trait a theme preset varies: how rounded its
/// controls and cards are, and how bold its headlines read. Colour lives in
/// [Palette] instead — the two are kept separate so either can be reused
/// independently, but every [ThemeStyle] still bundles one fixed pair of
/// each. A picker that let a user cross *any* colour with *any* shape would
/// be a matrix, and this app deliberately stays a flat list of named looks
/// (see the doc on [ThemeStyle]).
///
/// The theme carries its shape ([ThemeShapeScope]), so a widget can read the
/// active one with [ThemeShape.of].
@immutable
class ThemeShape {
  const ThemeShape({
    required this.controlRadius,
    required this.cardRadius,
    required this.headlineWeight,
    required this.headlineLetterSpacing,
    this.displayFontFamily,
    this.bodyFontFamily,
    this.borderWidth = 1,
    this.baseWeightDelta = 0,
    this.surfaceStyle = SurfaceStyle.solid,
    this.motion = MotionStyle.fluid,
    this.dividers = true,
    this.floatingBar = false,
    this.sharpIcons = false,
  });

  /// Buttons, inputs, list tiles.
  final double controlRadius;

  /// Cards — always somewhat larger than [controlRadius], the same relation
  /// every preset keeps between the two.
  final double cardRadius;

  final FontWeight headlineWeight;
  final double headlineLetterSpacing;

  /// Font family for display/headline/title-large roles — the big, showy
  /// text. `null` keeps the platform default; every preset before Bold
  /// leaves this unset.
  final String? displayFontFamily;

  /// Font family for title-medium-and-smaller, body and label roles — the
  /// working text. `null` keeps the platform default.
  final String? bodyFontFamily;

  /// Card, chip and input outline width.
  final double borderWidth;

  /// Rungs every text role is shifted by before the user's own font-weight
  /// setting is applied on top — Noir reads heavier everywhere, not just in
  /// headlines.
  final int baseWeightDelta;

  final SurfaceStyle surfaceStyle;

  final MotionStyle motion;

  /// Whether [Divider]s draw a line. Without, rows in a card are told apart
  /// by their spacing alone — Noir's ink-outlined cards need nothing more.
  final bool dividers;

  /// Whether a phone's bottom bar floats a little off the screen's foot,
  /// in a card of its own, instead of running edge to edge.
  final bool floatingBar;

  /// Whether chrome icons use Material's square-cornered (sharp) glyphs in
  /// place of the rounded ones (see `AppIcon`).
  final bool sharpIcons;

  bool get isGlass => surfaceStyle == SurfaceStyle.glass;

  /// Today's numbers, unchanged — Classic uses this.
  static const classic = ThemeShape(
    controlRadius: 20,
    cardRadius: 24,
    headlineWeight: FontWeight.w700,
    headlineLetterSpacing: -0.4,
    motion: MotionStyle.brisk,
  );

  /// Noir: Sora headlines over Manrope body text, every weight two rungs
  /// heavier and every outline thicker — bold through and through. No
  /// divider lines, a floating bar and square-cornered icons.
  static const noir = ThemeShape(
    controlRadius: 18,
    cardRadius: 22,
    headlineWeight: FontWeight.w800,
    headlineLetterSpacing: -0.6,
    displayFontFamily: 'Sora',
    bodyFontFamily: 'Manrope',
    borderWidth: 1.6,
    baseWeightDelta: 2,
    motion: MotionStyle.smooth,
    dividers: false,
    floatingBar: true,
    sharpIcons: true,
  );

  /// Glass: iOS's generous, concentric corners and tight, heavy titles,
  /// set in Inter — the closest open face to SF Pro.
  static const glass = ThemeShape(
    controlRadius: 14,
    // Continuous (squircle) corners — reads squarer than the same circular
    // radius, the proportions of an iOS widget.
    cardRadius: 22,
    headlineWeight: FontWeight.w700,
    headlineLetterSpacing: -0.8,
    displayFontFamily: 'Inter',
    bodyFontFamily: 'Inter',
    surfaceStyle: SurfaceStyle.glass,
  );

  /// The active theme's shape; [classic] under a theme without one.
  static ThemeShape of(BuildContext context) =>
      Theme.of(context).extension<ThemeShapeScope>()?.shape ?? classic;
}

/// Carries a [ThemeShape] on [ThemeData], for [ThemeShape.of].
@immutable
class ThemeShapeScope extends ThemeExtension<ThemeShapeScope> {
  const ThemeShapeScope(this.shape);

  final ThemeShape shape;

  @override
  ThemeShapeScope copyWith({ThemeShape? shape}) =>
      ThemeShapeScope(shape ?? this.shape);

  @override
  ThemeShapeScope lerp(ThemeShapeScope? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}
