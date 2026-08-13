import 'package:flutter/material.dart';

/// Every structural (non-colour) trait a theme preset varies: how rounded its
/// controls and cards are, and how bold its headlines read. Colour lives in
/// [Palette] instead — the two are kept separate so either can be reused
/// independently, but every [ThemePreset] still bundles one fixed pair of
/// each. A picker that let a user cross *any* colour with *any* shape would
/// be a matrix, and this app deliberately stays a flat list of named looks
/// (see the doc on [ThemePreset]).
@immutable
class ThemeShape {
  const ThemeShape({
    required this.controlRadius,
    required this.cardRadius,
    required this.headlineWeight,
    required this.headlineLetterSpacing,
  });

  /// Buttons, inputs, list tiles.
  final double controlRadius;

  /// Cards — always somewhat larger than [controlRadius], the same relation
  /// every preset keeps between the two.
  final double cardRadius;

  final FontWeight headlineWeight;
  final double headlineLetterSpacing;

  /// Today's numbers, unchanged — every preset before Cove uses this.
  static const classic = ThemeShape(
    controlRadius: 20,
    cardRadius: 24,
    headlineWeight: FontWeight.w700,
    headlineLetterSpacing: -0.4,
  );

  /// Bigger, softer "squircle" chrome and a bolder headline — the One UI 9
  /// look Cove borrows its shape language from.
  static const soft = ThemeShape(
    controlRadius: 26,
    cardRadius: 32,
    headlineWeight: FontWeight.w800,
    headlineLetterSpacing: -0.6,
  );
}
