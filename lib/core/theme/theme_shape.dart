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

/// Every structural (non-colour) trait a theme preset varies: how rounded its
/// controls and cards are, and how bold its headlines read. Colour lives in
/// [Palette] instead — the two are kept separate so either can be reused
/// independently, but every [ThemeStyle] still bundles one fixed pair of
/// each. A picker that let a user cross *any* colour with *any* shape would
/// be a matrix, and this app deliberately stays a flat list of named looks
/// (see the doc on [ThemeStyle]).
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

  bool get isGlass => surfaceStyle == SurfaceStyle.glass;

  /// Today's numbers, unchanged — Classic uses this.
  static const classic = ThemeShape(
    controlRadius: 20,
    cardRadius: 24,
    headlineWeight: FontWeight.w700,
    headlineLetterSpacing: -0.4,
  );

  /// Noir: Sora headlines over Manrope body text, every weight a rung
  /// heavier and every outline thicker — bold through and through.
  static const noir = ThemeShape(
    controlRadius: 18,
    cardRadius: 22,
    headlineWeight: FontWeight.w800,
    headlineLetterSpacing: -0.6,
    displayFontFamily: 'Sora',
    bodyFontFamily: 'Manrope',
    borderWidth: 1.6,
    baseWeightDelta: 1,
  );

  /// Glass: iOS's generous, concentric corners and tight, heavy titles,
  /// set in Inter — the closest open face to SF Pro.
  static const glass = ThemeShape(
    controlRadius: 14,
    cardRadius: 26,
    headlineWeight: FontWeight.w700,
    headlineLetterSpacing: -0.8,
    displayFontFamily: 'Inter',
    bodyFontFamily: 'Inter',
    surfaceStyle: SurfaceStyle.glass,
  );
}
