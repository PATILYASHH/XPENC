import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/glass.dart';
import 'glass_sheet.dart';

/// A dialog that grows out of the button that opened it: the button swells on
/// a spring into the dialog's pane — its colour draining into the pane's, its
/// glyph dissolving — while the dialog forms inside; closing shrinks it back
/// into the button.
///
/// [from] is the button's context (its box is where the pane starts), and
/// [color], [icon] and [radius] are what the button looks like, so the first
/// frames read as the button itself. [builder] gives the dialog's body only —
/// the route draws the pane; [MorphDialogBody] lays one out like an
/// [AlertDialog]. Wrap the button in a [MorphDialogSource] and it steps aside
/// while the dialog is up — the dialog *is* the button then.
Future<T?> showMorphDialog<T>({
  required BuildContext from,
  required WidgetBuilder builder,
  required Color color,
  Widget? icon,
  double? radius,
}) {
  final navigator = Navigator.of(from, rootNavigator: true);
  final box = from.findRenderObject();
  final screen = MediaQuery.sizeOf(from);
  final anchor = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : Rect.fromCenter(
          center: screen.center(Offset.zero),
          width: 56,
          height: 56,
        );
  final surface = AppSurface.of(from);
  final source = from.findAncestorStateOfType<_MorphDialogSourceState>();
  final route = _MorphDialogRoute<T>(
    builder: builder,
    anchor: anchor,
    color: color,
    icon: icon,
    radius: radius ?? anchor.shortestSide / 2,
    glass: surface.isGlass,
    capturedThemes: InheritedTheme.capture(from: from, to: navigator.context),
    barrierColor:
        Theme.of(from).dialogTheme.barrierColor ??
        (surface.isGlass ? surface.tone.barrier : Colors.black54),
    barrierLabel: MaterialLocalizations.of(from).modalBarrierDismissLabel,
  );
  final result = navigator.push(route);
  source?._hideWhile(route.animation!);
  return result;
}

/// The button a [showMorphDialog] grows out of: hidden from the moment the
/// dialog starts growing out of it until the dialog has shrunk back into it.
class MorphDialogSource extends StatefulWidget {
  const MorphDialogSource({required this.child, super.key});

  final Widget child;

  @override
  State<MorphDialogSource> createState() => _MorphDialogSourceState();
}

class _MorphDialogSourceState extends State<MorphDialogSource> {
  bool _hidden = false;

  void _hideWhile(Animation<double> dialog) {
    setState(() => _hidden = true);
    void back(AnimationStatus status) {
      if (status != AnimationStatus.dismissed) return;
      dialog.removeStatusListener(back);
      if (mounted) setState(() => _hidden = false);
    }

    dialog.addStatusListener(back);
  }

  @override
  Widget build(BuildContext context) =>
      Opacity(opacity: _hidden ? 0 : 1, child: widget.child);
}

/// A dialog body laid out the way [AlertDialog] lays its parts out: [title],
/// then [content], then the [actions] along the bottom, right-aligned.
class MorphDialogBody extends StatelessWidget {
  const MorphDialogBody({
    required this.title,
    required this.content,
    required this.actions,
    super.key,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DefaultTextStyle(
            style:
                theme.dialogTheme.titleTextStyle ??
                theme.textTheme.headlineSmall!,
            child: title,
          ),
          const SizedBox(height: 16),
          content,
          const SizedBox(height: 20),
          // Side by side when they fit; stacked otherwise, centred, the
          // last (the primary) on top.
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 8,
            overflowSpacing: 4,
            overflowAlignment: OverflowBarAlignment.center,
            overflowDirection: VerticalDirection.up,
            children: actions,
          ),
        ],
      ),
    );
  }
}

class _MorphDialogRoute<T> extends PopupRoute<T> {
  _MorphDialogRoute({
    required this.builder,
    required this.anchor,
    required this.color,
    required this.icon,
    required this.radius,
    required this.glass,
    required this.capturedThemes,
    required Color barrierColor,
    required String barrierLabel,
  }) : _barrierColor = barrierColor,
       _barrierLabel = barrierLabel;

  final WidgetBuilder builder;

  /// The button's box, in global coordinates.
  final Rect anchor;
  final Color color;
  final Widget? icon;
  final double radius;
  final bool glass;
  final CapturedThemes capturedThemes;
  final Color _barrierColor;
  final String _barrierLabel;

  @override
  Color? get barrierColor => _barrierColor;

  @override
  String? get barrierLabel => _barrierLabel;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 560);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 380);

  /// Out on the bar's spring; back into the button on an even ease.
  late final CurvedAnimation morph = CurvedAnimation(
    parent: animation!,
    curve: const GlassBarSpring(),
    reverseCurve: Curves.easeInOutCubic,
  );

  @override
  Widget buildModalBarrier() {
    final barrier = super.buildModalBarrier();
    return glass ? _BlurIn(animation: animation!, child: barrier) : barrier;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => capturedThemes.wrap(_MorphDialogFrame(route: this));

  // The frame animates itself; nothing slides or fades as a whole.
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;

  @override
  void dispose() {
    morph.dispose();
    super.dispose();
  }
}

class _MorphDialogFrame extends StatelessWidget {
  const _MorphDialogFrame({required this.route});

  final _MorphDialogRoute<dynamic> route;

  static const double _maxWidth = 360;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final surface = AppSurface.of(context);
    final pane = route.glass
        ? surface.tone.floating
        : theme.dialogTheme.backgroundColor ??
              theme.colorScheme.surfaceContainerHigh;
    final shape = theme.dialogTheme.shape;
    final endRadius = shape is RoundedRectangleBorder
        ? shape.borderRadius.resolve(TextDirection.ltr).topLeft.x
        : 28.0;
    // What the pane keeps clear of: the keyboard, the system bars.
    final avoid = EdgeInsets.fromLTRB(
      media.padding.left,
      media.padding.top,
      media.padding.right,
      math.max(media.viewInsets.bottom, media.padding.bottom),
    );

    final content = Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      child: Material(
        type: MaterialType.transparency,
        child: Builder(builder: route.builder),
      ),
    );

    return AnimatedBuilder(
      animation: route.morph,
      builder: (context, content) {
        final t = route.morph.value;
        final open = t.clamp(0.0, 1.0);
        final radius = ui.lerpDouble(route.radius, endRadius, open)!;
        // The button's colour drains into the pane's as it grows; its
        // glyph dissolves; the dialog forms once there's room for it.
        final fill = Color.lerp(
          route.color,
          pane,
          Curves.easeOut.transform((open / 0.6).clamp(0.0, 1.0)),
        )!;
        final glyph = 1 - Curves.easeOut.transform((open / 0.3).clamp(0, 1));
        final reveal = Curves.easeOut.transform(
          ((open - 0.3) / 0.55).clamp(0.0, 1.0),
        );
        return _MorphDialogLayout(
          t: t,
          anchor: route.anchor,
          startRadius: route.radius,
          endRadius: endRadius,
          maxWidth: _maxWidth,
          avoid: avoid,
          reveal: reveal,
          pane: _pane(context, fill, radius),
          content: content!,
          glyph: Opacity(
            opacity: glyph,
            child: IconTheme.merge(
              data: const IconThemeData(color: Colors.white, size: 24),
              child: route.icon ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      child: content,
    );
  }

  Widget _pane(BuildContext context, Color fill, double radius) {
    final corners = BorderRadius.circular(math.max(0, radius));
    Widget pane = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: corners,
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
    );
    if (route.glass) {
      pane = CustomPaint(
        foregroundPainter: GlassRimPainter(
          corners,
          strength: 0.85 * AppSurface.of(context).tone.rimStrength,
        ),
        child: pane,
      );
    }
    return pane;
  }
}

/// Lays the dialog's body out at its full size, centred in the room the
/// keyboard and system bars leave, and the pane as the morph window — from
/// the button's box at [t] 0 to the body's box at 1 — then draws the body
/// scaled into the window, clipped to it and faded in by [reveal], with the
/// button's glyph on top.
class _MorphDialogLayout extends MultiChildRenderObjectWidget {
  _MorphDialogLayout({
    required this.t,
    required this.anchor,
    required this.startRadius,
    required this.endRadius,
    required this.maxWidth,
    required this.avoid,
    required this.reveal,
    required Widget pane,
    required Widget content,
    required Widget glyph,
  }) : super(children: [pane, content, glyph]);

  final double t;
  final Rect anchor;
  final double startRadius;
  final double endRadius;
  final double maxWidth;
  final EdgeInsets avoid;
  final double reveal;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMorphDialog()
    ..t = t
    ..anchor = anchor
    ..startRadius = startRadius
    ..endRadius = endRadius
    ..maxWidth = maxWidth
    ..avoid = avoid
    ..reveal = reveal;

  @override
  void updateRenderObject(BuildContext context, _RenderMorphDialog r) => r
    ..t = t
    ..anchor = anchor
    ..startRadius = startRadius
    ..endRadius = endRadius
    ..maxWidth = maxWidth
    ..avoid = avoid
    ..reveal = reveal;
}

class _MorphParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMorphDialog extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MorphParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MorphParentData> {
  double _t = 0;
  set t(double v) => _relayout(_t != v, () => _t = v);

  Rect _anchor = Rect.zero;
  set anchor(Rect v) => _relayout(_anchor != v, () => _anchor = v);

  double _startRadius = 0;
  set startRadius(double v) =>
      _relayout(_startRadius != v, () => _startRadius = v);

  double _endRadius = 0;
  set endRadius(double v) => _relayout(_endRadius != v, () => _endRadius = v);

  double _maxWidth = 360;
  set maxWidth(double v) => _relayout(_maxWidth != v, () => _maxWidth = v);

  EdgeInsets _avoid = EdgeInsets.zero;
  set avoid(EdgeInsets v) => _relayout(_avoid != v, () => _avoid = v);

  double _reveal = 0;
  set reveal(double v) {
    if (v == _reveal) return;
    _reveal = v;
    markNeedsPaint();
  }

  void _relayout(bool changed, VoidCallback write) {
    if (!changed) return;
    write();
    markNeedsLayout();
  }

  RenderBox get _pane => firstChild!;
  RenderBox get _content => childAfter(firstChild!)!;
  RenderBox get _glyph => lastChild!;

  RRect _window = RRect.zero;
  Matrix4 _contentTransform = Matrix4.identity();

  /// Whether the body sits exactly where it lands, unscaled.
  bool get _landed => (_t - 1).abs() < 0.001;

  final _clip = LayerHandle<ClipRRectLayer>();
  final _opacity = LayerHandle<OpacityLayer>();
  final _transform = LayerHandle<TransformLayer>();

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MorphParentData) {
      child.parentData = _MorphParentData();
    }
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    size = constraints.biggest;
    final room = Rect.fromLTRB(
      _avoid.left + 20,
      _avoid.top + 24,
      size.width - _avoid.right - 20,
      size.height - _avoid.bottom - 24,
    );
    final width = math.max(0.0, math.min(room.width, _maxWidth));
    _content.layout(
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: math.max(0.0, room.height),
      ),
      parentUsesSize: true,
    );
    final end = Rect.fromCenter(
      center: room.center,
      width: width,
      height: _content.size.height,
    );
    final lerped = Rect.lerp(_anchor, end, _t)!;
    final window = Rect.fromLTWH(
      lerped.left,
      lerped.top,
      math.max(0, lerped.width),
      math.max(0, lerped.height),
    );
    final radius = ui.lerpDouble(_startRadius, _endRadius, _t.clamp(0, 1))!;
    _window = RRect.fromRectAndRadius(
      window,
      Radius.circular(math.max(0, radius)),
    );

    _pane.layout(BoxConstraints.tight(window.size));
    (_pane.parentData! as _MorphParentData).offset = window.topLeft;
    _glyph.layout(BoxConstraints.loose(size), parentUsesSize: true);
    (_glyph.parentData! as _MorphParentData).offset =
        window.center - _glyph.size.center(Offset.zero);

    // The body, scaled to the window's width and riding its top-left corner.
    final scale = width <= 0 ? 1.0 : window.width / width;
    _contentTransform = Matrix4.translationValues(window.left, window.top, 0)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1));
    (_content.parentData! as _MorphParentData).offset = window.topLeft;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.paintChild(
      _pane,
      offset + (_pane.parentData! as _MorphParentData).offset,
    );
    if (_reveal > 0) {
      if (_reveal >= 1 && _landed) {
        _clip.layer = null;
        _opacity.layer = null;
        _transform.layer = null;
        context.paintChild(
          _content,
          offset + (_content.parentData! as _MorphParentData).offset,
        );
      } else {
        _clip.layer = context.pushClipRRect(
          needsCompositing,
          offset,
          Offset.zero & size,
          _window,
          (context, offset) {
            _opacity.layer = context.pushOpacity(
              offset,
              (_reveal * 255).round(),
              (context, offset) {
                _transform.layer = context.pushTransform(
                  needsCompositing,
                  offset,
                  _contentTransform,
                  (context, offset) => context.paintChild(_content, offset),
                  oldLayer: _transform.layer,
                );
              },
              oldLayer: _opacity.layer,
            );
          },
          oldLayer: _clip.layer,
        );
      }
    } else {
      _clip.layer = null;
      _opacity.layer = null;
      _transform.layer = null;
    }
    context.paintChild(
      _glyph,
      offset + (_glyph.parentData! as _MorphParentData).offset,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (identical(child, _content) && !(_reveal >= 1 && _landed)) {
      transform.multiply(_contentTransform);
      return;
    }
    super.applyPaintTransform(child, transform);
  }

  // Taps on the pane stay with the dialog; taps beyond it reach the barrier.
  @override
  bool hitTestSelf(Offset position) => _window.contains(position);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_reveal < 0.5) return false;
    final transform = Matrix4.identity();
    applyPaintTransform(_content, transform);
    return result.addWithPaintTransform(
      transform: transform,
      position: position,
      hitTest: (result, position) =>
          _content.hitTest(result, position: position),
    );
  }

  @override
  void dispose() {
    _clip.layer = null;
    _opacity.layer = null;
    _transform.layer = null;
    super.dispose();
  }
}

/// The page frosting over as the dialog opens, and clearing as it closes.
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
