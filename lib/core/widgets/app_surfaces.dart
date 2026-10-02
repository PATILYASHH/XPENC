import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/glass.dart';

/// The app's card. Outside Glass it *is* a [Card] — same arguments, same
/// result. Under Glass it becomes a real frosted [GlassPane] that blurs the
/// wallpaper behind it.
///
/// Use this instead of [Card] everywhere in `lib/`, or that card stays an
/// opaque slab when Glass is on.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    this.child,
    this.margin,
    this.clipBehavior,
    this.shape,
    this.color,
  });

  final Widget? child;
  final EdgeInsetsGeometry? margin;
  final Clip? clipBehavior;
  final ShapeBorder? shape;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!AppSurface.of(context).isGlass) {
      return Card(
        margin: margin,
        clipBehavior: clipBehavior,
        shape: shape,
        color: color,
        child: child,
      );
    }

    final cardTheme = Theme.of(context).cardTheme;
    final resolved = shape ?? cardTheme.shape;
    final radius = resolved is RoundedRectangleBorder
        ? resolved.borderRadius.resolve(Directionality.of(context))
        : BorderRadius.circular(24);

    return Semantics(
      container: true,
      child: Padding(
        padding: margin ?? cardTheme.margin ?? EdgeInsets.zero,
        child: GlassPane(
          borderRadius: radius,
          tint: color,
          // A transparent Material so ink splashes from the card's
          // InkWells/ListTiles still have somewhere to draw, as on a Card.
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

/// [showModalBottomSheet], with the same arguments. Under Glass the page
/// behind frosts over as the sheet rises, and the sheet itself is a
/// translucent pane on top of that blur.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool? showDragHandle,
  bool useRootNavigator = false,
  ShapeBorder? shape,
  bool useSafeArea = false,
}) {
  if (!AppSurface.of(context).isGlass) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      useRootNavigator: useRootNavigator,
      shape: shape,
      useSafeArea: useSafeArea,
    );
  }
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final localizations = MaterialLocalizations.of(context);
  final sheetTheme = Theme.of(context).bottomSheetTheme;
  return navigator.push(
    _GlassSheetRoute<T>(
      builder: builder,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      isScrollControlled: isScrollControlled,
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      // The theme's own rounded top wins over a call site's: a pane's corner
      // is part of the look.
      shape: sheetTheme.shape ?? shape,
      modalBarrierColor: sheetTheme.modalBarrierColor,
      showDragHandle: showDragHandle,
      useSafeArea: useSafeArea,
    ),
  );
}

/// [showDialog], with the same arguments. Under Glass the page behind
/// frosts over while the dialog is open.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  if (!AppSurface.of(context).isGlass) {
    return showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
    );
  }
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push(
    _GlassDialogRoute<T>(
      context: context,
      builder: builder,
      barrierColor:
          Theme.of(context).dialogTheme.barrierColor ?? GlassStyle.barrier,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
    ),
  );
}

class _GlassSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _GlassSheetRoute({
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.shape,
    super.modalBarrierColor,
    super.showDragHandle,
    super.useSafeArea,
  });

  @override
  Widget buildModalBarrier() =>
      _BlurIn(animation: animation!, child: super.buildModalBarrier());
}

class _GlassDialogRoute<T> extends DialogRoute<T> {
  _GlassDialogRoute({
    required super.context,
    required super.builder,
    super.barrierColor,
    super.barrierDismissible,
    super.barrierLabel,
    super.themes,
  });

  @override
  Widget buildModalBarrier() =>
      _BlurIn(animation: animation!, child: super.buildModalBarrier());
}

/// The page frosting over as a route opens (and clearing as it closes),
/// rather than snapping to full blur on the first frame.
class _BlurIn extends AnimatedWidget {
  const _BlurIn({required Animation<double> animation, required this.child})
    : super(listenable: animation);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeOut.transform(
      (listenable as Animation<double>).value.clamp(0.0, 1.0),
    );
    if (t == 0) return child;
    final sigma = GlassStyle.barrierBlur * t;
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}
