import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

import '../theme/glass.dart';

/// The Glass tab bar's geometry, shared with the sheets that grow out of it
/// (app_shell.dart's `_LiquidTabBar` lays itself out from these).
const double kGlassBarHeight = 64;

/// The tab capsule's inset from each side of the screen.
const double kGlassBarSide = 16;

/// The gap between the tab capsule and the ➕ disc.
const double kGlassAddGap = 10;

/// A sheet's inset from each side of the screen.
const double kGlassSheetSide = 8;

/// The space under the bar (and under a sheet): the home indicator's, or 8 —
/// what the bar's own `SafeArea(minimum: 8)` leaves, so the two line up.
double glassBarBottom(MediaQueryData media) =>
    math.max(8.0, media.padding.bottom);

/// Lets the shell's Glass tab bar hand itself over to a sheet or page growing
/// out of it: while one opened from the shell is up, [progress] carries its
/// morph (spring-eased, so it can overshoot 0…1 a hair) and the bar fades its
/// own glass out — the sheet or page *is* the bar now — dissolves its tabs
/// and slides the ➕ away, exactly as it does when it grows into the month
/// picker. `null` when nothing has the bar.
///
/// One owner at a time: whoever [claim]s it drives it until it [release]s.
class GlassBarMorph {
  const GlassBarMorph._();

  static final ValueNotifier<double?> progress = ValueNotifier<double?>(null);
  static Object? _owner;

  /// Takes the bar for [owner] (at progress [value]); false if another has it.
  static bool claim(Object owner, double value) {
    if (_owner != null && !identical(_owner, owner)) return false;
    _owner = owner;
    progress.value = value;
    return true;
  }

  /// Moves the bar's hand-over along, if [owner] has it.
  static void update(Object owner, double value) {
    if (identical(_owner, owner)) progress.value = value;
  }

  /// Gives the bar back, if [owner] has it.
  static void release(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    progress.value = null;
  }
}

/// Marks the subtree the Glass tab bar sits over (the shell). A sheet opened
/// from inside it grows out of the bar; one opened anywhere else grows out of
/// a bar-shaped capsule at the foot of the screen.
///
/// The shell keeps one in its tree whatever the theme, so switching themes
/// never changes the tree's shape (which would remount every tab); [active]
/// says whether there's a Glass tab bar to grow out of.
class GlassBarScope extends InheritedWidget {
  const GlassBarScope({required this.active, required super.child, super.key});

  final bool active;

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GlassBarScope>()?.active ?? false;

  @override
  bool updateShouldNotify(GlassBarScope old) => old.active != active;
}

/// The month picker's spring (app_shell's `_LiquidTabBar`), as a curve over
/// a sheet's or page's transition out of the bar — damped a touch more than
/// the picker's: an overshoot that's a soft settle on a 286-pt card is a
/// visible wobble on a sheet three times as tall.
class GlassBarSpring extends Curve {
  const GlassBarSpring();

  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 240,
    ratio: 0.86,
  );

  /// Long enough for the spring to come to rest (it's within 0.3% by then).
  static const double seconds = 0.56;

  @override
  double transformInternal(double t) =>
      SpringSimulation(_spring, 0, 1, 0).x(t * seconds);
}

/// Pushes [builder]'s content as a Glass sheet — see [showAppSheet], which
/// calls this under Glass. Always on the root navigator, so the sheet sits
/// above the tab bar it grows out of rather than under it.
Future<T?> pushGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showHandle = false,
  bool useSafeArea = false,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final localizations = MaterialLocalizations.of(context);
  return navigator.push(
    GlassSheetRoute<T>(
      builder: builder,
      fromBar: GlassBarScope.of(context),
      showHandle: showHandle,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierColor: AppSurface.of(context).tone.barrier,
      barrierLabel: localizations.scrimLabel,
      sheetLabel: localizations.bottomSheetLabel,
    ),
  );
}

/// A Glass sheet: the tab bar transforming into a page. It opens as the tab
/// capsule growing up on a spring — the bar's lens and clear glass thickening
/// into the sheet's frost, the tabs dissolving, the ➕ sliding away — with
/// the content riding the rising top edge and fading in; it folds back into
/// the bar the same way on close. Drag it down, or tap outside, to close.
class GlassSheetRoute<T> extends PopupRoute<T> {
  GlassSheetRoute({
    required this.builder,
    required this.fromBar,
    required this.showHandle,
    required this.isScrollControlled,
    required this.useSafeArea,
    required this.capturedThemes,
    required Color barrierColor,
    required String barrierLabel,
    required this.sheetLabel,
  }) : _barrierColor = barrierColor,
       _barrierLabel = barrierLabel;

  final WidgetBuilder builder;

  /// Whether this sheet grows out of (and hands over) the shell's tab bar.
  final bool fromBar;
  final bool showHandle;
  final bool isScrollControlled;
  final bool useSafeArea;
  final CapturedThemes capturedThemes;
  final String sheetLabel;
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
  Duration get reverseTransitionDuration => const Duration(milliseconds: 440);

  /// The morph's own progress: the spring on the way up and, mirrored, on
  /// the way back down into the bar.
  late final CurvedAnimation morph = CurvedAnimation(
    parent: animation!,
    curve: const GlassBarSpring(),
    reverseCurve: const GlassBarSpring().flipped,
  );

  @override
  void install() {
    super.install();
    if (fromBar) {
      animation!.addListener(_publish);
      animation!.addStatusListener(_publishStatus);
    }
  }

  void _publish() => GlassBarMorph.update(this, morph.value);

  void _publishStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      GlassBarMorph.release(this);
    } else {
      GlassBarMorph.claim(this, morph.value);
    }
  }

  @override
  void dispose() {
    GlassBarMorph.release(this);
    if (fromBar) {
      animation?.removeListener(_publish);
      animation?.removeStatusListener(_publishStatus);
    }
    morph.dispose();
    super.dispose();
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => capturedThemes.wrap(_GlassSheetFrame(route: this));

  // The frame animates itself (see [_GlassSheetFrame]); nothing slides.
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

class _GlassSheetFrame extends StatefulWidget {
  const _GlassSheetFrame({required this.route});

  final GlassSheetRoute<dynamic> route;

  @override
  State<_GlassSheetFrame> createState() => _GlassSheetFrameState();
}

class _GlassSheetFrameState extends State<_GlassSheetFrame>
    with SingleTickerProviderStateMixin {
  /// How far the sheet has been dragged down, in logical pixels.
  double _drag = 0;
  late final AnimationController _settle;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() => setState(() => _drag = _settleFrom * _settle.value));
  }

  double _settleFrom = 0;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  bool get _closing =>
      widget.route.animation?.status == AnimationStatus.reverse ||
      !widget.route.isActive;

  void _close() {
    if (_closing) return;
    Navigator.of(context).pop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_closing) return;
    _settle.stop();
    setState(() => _drag = math.max(0, _drag + details.delta.dy));
  }

  void _onDragEnd(DragEndDetails details, double height) {
    if (_closing) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 700 || _drag > math.min(160.0, height * 0.35)) {
      _close();
      return;
    }
    // Spring back up.
    _settleFrom = _drag;
    _settle
      ..value = 1
      ..animateTo(0, curve: Curves.easeOutCubic);
  }

  bool _onExtent(DraggableScrollableNotification n) {
    if (n.extent <= n.minExtent + 0.001 && n.shouldCloseOnMinExtent) _close();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final media = MediaQuery.of(context);
    final tone = AppSurface.of(context).tone;
    final bottom = glassBarBottom(media);
    final maxHeight = route.isScrollControlled
        ? media.size.height - (route.useSafeArea ? media.padding.top : 0)
        : media.size.height * 9 / 16;
    // Where the morph starts, as insets from the sheet's own sides: the tab
    // capsule (the ➕ and its gap lie beyond its right end), or — opened from
    // a page with no tab bar — a bar-shaped capsule across the foot.
    const side = kGlassBarSide - kGlassSheetSide;
    final right = route.fromBar ? side + kGlassBarHeight + kGlassAddGap : side;

    final content = MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      child: Material(
        type: MaterialType.transparency,
        child: NotificationListener<DraggableScrollableNotification>(
          onNotification: _onExtent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (route.showHandle)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 14),
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 5,
                      decoration: BoxDecoration(
                        color: tone.grabber,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 10),
              Flexible(child: Builder(builder: route.builder)),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: route.sheetLabel,
      explicitChildNodes: true,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 640),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              kGlassSheetSide,
              0,
              kGlassSheetSide,
              bottom,
            ),
            child: LayoutBuilder(
              builder: (context, box) => GestureDetector(
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: (d) => _onDragEnd(d, box.maxHeight),
                child: AnimatedBuilder(
                  animation: route.morph,
                  builder: (context, content) {
                    final t = route.morph.value;
                    final open = t.clamp(0.0, 1.0);
                    // Closing after a drag: the sheet slides home as it folds.
                    final drag = _drag * (route.animation?.value ?? 1);
                    // The content follows the glass in, the way the month
                    // grid forms in the bar.
                    final reveal = Curves.easeOut.transform(
                      ((open - 0.3) / 0.7).clamp(0.0, 1.0),
                    );
                    return Transform.translate(
                      offset: Offset(0, drag),
                      child: _MorphPane(
                        t: t,
                        left: side,
                        right: right,
                        reveal: reveal,
                        glass: _glass(tone, t),
                        content: content!,
                      ),
                    );
                  },
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The glass itself at morph progress [t]: the bar's clear, lensed glass
  /// at 0, the sheet's frosted pane at 1. It fades in over the first stretch
  /// while the bar's own glass fades out under it (see `_LiquidTabBar`), so
  /// the bar's tabs blur into the sheet instead of all at once.
  Widget _glass(GlassTone tone, double t) {
    final open = t.clamp(0.0, 1.0);
    final lens = 18 * (1 - open);
    final appear = Curves.easeOut.transform((open / 0.25).clamp(0.0, 1.0));
    final glass = LiquidGlass(
      borderRadius: BorderRadius.circular(32 + 2 * open),
      frost: Color.lerp(tone.controlFrost, tone.sheetFrost, open),
      blur: GlassStyle.controlBlur + (24 - GlassStyle.controlBlur) * open,
      // The lens and the light it takes are the bar's; on a pane this large
      // their pass would be paid on every frame for little to see.
      refraction: lens < 1 ? 0 : lens,
      light: (1 - open / 0.85).clamp(0.0, 1.0),
      child: const SizedBox.expand(),
    );
    return appear >= 1 ? glass : Opacity(opacity: appear, child: glass);
  }
}

/// Lays the sheet's content out at its full size and the glass as the morph
/// window — from the bar's capsule at [t] 0 to the whole sheet at 1, always
/// anchored at the foot — then draws the content riding the window's top
/// edge, clipped to it and faded in by [reveal].
class _MorphPane extends MultiChildRenderObjectWidget {
  _MorphPane({
    required this.t,
    required this.left,
    required this.right,
    required this.reveal,
    required Widget glass,
    required Widget content,
  }) : super(children: [glass, content]);

  final double t;
  final double left;
  final double right;
  final double reveal;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMorphPane(t: t, left: left, right: right, reveal: reveal);

  @override
  void updateRenderObject(BuildContext context, _RenderMorphPane r) => r
    ..t = t
    ..left = left
    ..right = right
    ..reveal = reveal;
}

class _MorphParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMorphPane extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MorphParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MorphParentData> {
  _RenderMorphPane({
    required double t,
    required double left,
    required double right,
    required double reveal,
  }) : _t = t,
       _left = left,
       _right = right,
       _reveal = reveal;

  double _t;
  set t(double v) {
    if (v == _t) return;
    _t = v;
    markNeedsLayout();
  }

  double _left;
  set left(double v) {
    if (v == _left) return;
    _left = v;
    markNeedsLayout();
  }

  double _right;
  set right(double v) {
    if (v == _right) return;
    _right = v;
    markNeedsLayout();
  }

  double _reveal;
  set reveal(double v) {
    if (v == _reveal) return;
    _reveal = v;
    markNeedsPaint();
  }

  RRect _window = RRect.zero;

  final _clip = LayerHandle<ClipRRectLayer>();
  final _opacity = LayerHandle<OpacityLayer>();

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MorphParentData) {
      child.parentData = _MorphParentData();
    }
  }

  RenderBox get _glass => firstChild!;
  RenderBox get _content => lastChild!;

  // The glass reads its backdrop, and the content is clipped and faded on
  // its own layers mid-morph.
  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    _content.layout(
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: constraints.maxHeight,
      ),
      parentUsesSize: true,
    );
    size = constraints.constrain(Size(width, _content.size.height));

    final full = size.height;
    final height = math.max(
      0.0,
      kGlassBarHeight + (full - kGlassBarHeight) * _t,
    );
    final open = _t.clamp(-0.05, 1.05);
    final rect = Rect.fromLTRB(
      _left * (1 - open),
      full - height,
      size.width - _right * (1 - open),
      full,
    );
    _window = RRect.fromRectAndRadius(
      rect,
      Radius.circular(32 + 2 * _t.clamp(0.0, 1.0)),
    );
    _glass.layout(BoxConstraints.tight(rect.size));
    (_glass.parentData! as _MorphParentData).offset = rect.topLeft;
    // The content rides the window's rising top edge.
    (_content.parentData! as _MorphParentData).offset = Offset(0, rect.top);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.paintChild(
      _glass,
      offset + (_glass.parentData! as _MorphParentData).offset,
    );
    if (_reveal <= 0) {
      _clip.layer = null;
      _opacity.layer = null;
      return;
    }
    final at = offset + (_content.parentData! as _MorphParentData).offset;
    if (_reveal >= 1 && _t >= 1) {
      _clip.layer = null;
      _opacity.layer = null;
      context.paintChild(_content, at);
      return;
    }
    _clip.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      _window,
      (context, _) {
        _opacity.layer = context.pushOpacity(
          Offset.zero,
          (_reveal * 255).round(),
          (context, _) => context.paintChild(_content, at),
          oldLayer: _opacity.layer,
        );
      },
      oldLayer: _clip.layer,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_reveal < 0.5) return false;
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void dispose() {
    _clip.layer = null;
    _opacity.layer = null;
    super.dispose();
  }
}
