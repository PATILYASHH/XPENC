import 'package:flutter/material.dart';

import 'theme_shape.dart';

export 'theme_shape.dart' show MotionStyle;

/// How much the active theme moves — its [ThemeShape.motion].
///
/// Classic is [MotionStyle.brisk]: a working look, where motion only
/// confirms what happened and never makes you wait. Pages open with the
/// platform's own push, cut to about half its length; nothing springs past
/// where it lands, nothing staggers in, and numbers and bars arrive quickly.
/// Noir is [MotionStyle.smooth] and Glass [MotionStyle.fluid]: both keep the
/// full motion, Noir settling without a bounce.
abstract final class AppMotion {
  /// A brisk theme's page push, and its quicker way back.
  static const pushDuration = Duration(milliseconds: 240);
  static const popDuration = Duration(milliseconds: 200);

  static MotionStyle of(BuildContext context) => ThemeShape.of(context).motion;

  static bool isBrisk(BuildContext context) => of(context) == MotionStyle.brisk;

  static bool isSmooth(BuildContext context) =>
      of(context) == MotionStyle.smooth;

  /// [fluid] as it is, or no longer than [cap] under a brisk theme.
  static Duration capped(
    BuildContext context,
    Duration fluid, {
    Duration cap = const Duration(milliseconds: 300),
  }) => isBrisk(context) && fluid > cap ? cap : fluid;

  /// [curve], or a plain ease-out in place of an overshooting one under a
  /// theme that settles without a bounce (brisk or smooth).
  static Curve settle(BuildContext context, Curve curve) =>
      of(context) == MotionStyle.fluid ? curve : Curves.easeOutCubic;
}
