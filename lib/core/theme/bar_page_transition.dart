import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import '../widgets/glass_sheet.dart';
import 'glass.dart';

/// Pages that open as the tab bar transforming into them — the same motion
/// as the month picker and every sheet: the bar's capsule grows up on its
/// spring and stretches out to the whole screen, its clear glass thickening
/// as it goes, the tabs dissolving and the ➕ sliding away, while the page
/// forms inside it riding the rising top edge. Back folds the page back down
/// into the bar.
///
/// Open a page this way with [pushFromBar] (or call [PageFromBar.record]
/// just before any push). Every theme's page transitions pick it up
/// ([BarMorphTransitionsBuilder]); other pushes keep their usual transition.
class PageFromBar {
  const PageFromBar._();

  static BarPageSpec? _pending;
  static final _specs = Expando<BarPageSpec>('PageFromBar');
  static final _animations = Expando<bool>('PageFromBarAnimation');

  /// The bar's own spring, over the same time a sheet takes.
  static const duration = Duration(milliseconds: 560);
  static const reverseDuration = Duration(milliseconds: 440);

  /// Whether the next pushed page will grow out of the bar.
  static bool get pending => _pending != null;

  /// Records that the next pushed page grows out of the tab bar under
  /// [context] — the Glass capsule when [context] is in the shell, otherwise
  /// a bar along the foot of the screen.
  static void record(BuildContext context) {
    final spec = _pending = BarPageSpec._(
      fromBar: GlassBarScope.of(context),
      glass: AppSurface.of(context).isGlass,
    );
    // Unclaimed for a few frames — the push it was meant for never built a
    // route — it's dropped, so it can't hijack some later push.
    var frames = 0;
    void expire(Duration _) {
      if (!identical(_pending, spec)) return;
      if (++frames >= 6) {
        _pending = null;
        return;
      }
      SchedulerBinding.instance
        ..addPostFrameCallback(expire)
        ..scheduleFrame();
    }

    SchedulerBinding.instance
      ..addPostFrameCallback(expire)
      ..scheduleFrame();
  }

  /// The morph for [route], claiming the pending one for the route now being
  /// pushed (the one whose animation hasn't completed yet).
  static BarPageSpec? specFor(
    Route<dynamic> route,
    Animation<double> animation,
  ) {
    final known = _specs[route];
    if (known != null) return known;
    final pending = _pending;
    if (pending == null || animation.value >= 1) return null;
    _pending = null;
    _specs[route] = pending;
    _animations[_innermost(animation)] = true;
    return pending;
  }

  /// Whether [secondaryAnimation] — what a page receives while another
  /// opens over it — belongs to a page growing out of the bar; this page then
  /// stays put and dims under it rather than sliding aside. A pending morph
  /// counts: this page can rebuild in the same frame as, but before, the new
  /// page claims it.
  static bool isMorphing(Animation<double> secondaryAnimation) =>
      (_animations[_innermost(secondaryAnimation)] ?? false) ||
      _pending != null;

  static Animation<double> _innermost(Animation<double> a) {
    var current = a;
    for (var i = 0; i < 8 && current is ProxyAnimation; i++) {
      final parent = current.parent;
      if (parent == null) break;
      current = parent;
    }
    return current;
  }
}

/// How a page grows out of the bar: from the shell's Glass capsule (handing
/// the bar over as it goes), or from a bar along the foot of the screen.
class BarPageSpec {
  const BarPageSpec._({required this.fromBar, required this.glass});

  /// Whether this page grows out of (and hands over) the shell's tab bar.
  final bool fromBar;

  /// Whether the morphing window is Liquid Glass (else the page's surface).
  final bool glass;
}

/// Opens [location] as the tab bar transforming into it.
Future<T?> pushFromBar<T extends Object?>(
  BuildContext context,
  String location,
) {
  PageFromBar.record(context);
  return context.push<T>(location);
}

/// [inner]'s transitions, plus the bar morph: a page opened from the bar
/// grows out of it, and the page under it dims. Everything else is
/// [inner]'s. The page under is always wrapped — idle unless a page is
/// growing over it — because changing the shape of its tree mid-push would
/// remount the whole page.
class BarMorphTransitionsBuilder extends PageTransitionsBuilder {
  const BarMorphTransitionsBuilder(this.inner);

  final PageTransitionsBuilder inner;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      inner.delegatedTransition;

  // Read when the route is created — just after the morph was recorded.
  @override
  Duration get transitionDuration =>
      PageFromBar.pending ? PageFromBar.duration : inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => PageFromBar.pending
      ? PageFromBar.reverseDuration
      : inner.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final spec = PageFromBar.specFor(route, animation);
    if (spec != null) {
      return BarPageTransition(animation: animation, spec: spec, child: child);
    }
    final morphing = PageFromBar.isMorphing(secondaryAnimation);
    return _Dim(
      animation: morphing ? secondaryAnimation : kAlwaysDismissedAnimation,
      child: inner.buildTransitions(
        route,
        context,
        animation,
        morphing ? kAlwaysDismissedAnimation : secondaryAnimation,
        child,
      ),
    );
  }
}

/// The page growing out of the bar. Its tree has one shape for every frame —
/// the page always at the same place in it — so the page keeps its state
/// through the whole motion.
class BarPageTransition extends StatefulWidget {
  const BarPageTransition({
    required this.animation,
    required this.spec,
    required this.child,
    super.key,
  });

  final Animation<double> animation;
  final BarPageSpec spec;
  final Widget child;

  @override
  State<BarPageTransition> createState() => _BarPageTransitionState();
}

class _BarPageTransitionState extends State<BarPageTransition> {
  late CurvedAnimation _morph;

  @override
  void initState() {
    super.initState();
    _listen(widget.animation);
  }

  void _listen(Animation<double> animation) {
    _morph = CurvedAnimation(
      parent: animation,
      curve: const GlassBarSpring(),
      reverseCurve: const GlassBarSpring().flipped,
    );
    animation
      ..addListener(_tick)
      ..addStatusListener(_status);
  }

  void _unlisten(Animation<double> animation) {
    animation
      ..removeListener(_tick)
      ..removeStatusListener(_status);
    _morph.dispose();
  }

  @override
  void didUpdateWidget(BarPageTransition old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      _unlisten(old.animation);
      _listen(widget.animation);
    }
  }

  // The bar is taken on the animation's ticks — never while this page is
  // being built, when the bar can't rebuild.
  void _tick() {
    if (widget.spec.fromBar) GlassBarMorph.claim(this, _morph.value);
    setState(() {});
  }

  void _status(AnimationStatus status) {
    if (widget.spec.fromBar && status == AnimationStatus.dismissed) {
      GlassBarMorph.release(this);
    }
  }

  @override
  void dispose() {
    // Normally already given back when the fold finished; if the page went
    // without one, give it back once this frame is done.
    final owner = this;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => GlassBarMorph.release(owner),
    );
    _unlisten(widget.animation);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final settled = widget.animation.isCompleted;
    final t = _morph.value;
    final open = t.clamp(0.0, 1.0);
    final media = MediaQuery.of(context);
    final size = media.size;

    // Where the window starts: the Glass tab capsule (the ➕ and its gap lie
    // beyond its right end), or a bar-shaped capsule across the foot.
    final barBottom = size.height - glassBarBottom(media);
    final from = Rect.fromLTRB(
      kGlassBarSide,
      barBottom - kGlassBarHeight,
      size.width -
          kGlassBarSide -
          (spec.fromBar ? kGlassBarHeight + kGlassAddGap : 0),
      barBottom,
    );
    // Up on the spring (a hair past at its peak); out to the sides and down
    // to the screen's foot along with it.
    final rect = Rect.fromLTRB(
      from.left * (1 - open),
      from.top * (1 - t),
      from.right + (size.width - from.right) * open,
      from.bottom + (size.height - from.bottom) * open,
    );
    // Capsule round, soft corners while it travels, square at the screen.
    final round = 32 - 4 * open;
    final corner = open > 0.88 ? round * (1 - open) / 0.12 : round;
    // The page forms inside as the glass grows, the way the month grid does.
    final reveal = Curves.easeOut.transform(((open - 0.28) / 0.6).clamp(0, 1));
    final appear = Curves.easeOut.transform((open / 0.25).clamp(0.0, 1.0));

    return Stack(
      children: [
        Positioned.fromRect(
          rect: rect,
          child: settled
              ? const SizedBox.shrink()
              : Opacity(opacity: appear, child: _window(context, open)),
        ),
        Positioned.fill(
          child: ClipRRect(
            clipper: _WindowClipper(rect, corner),
            clipBehavior: settled ? Clip.none : Clip.antiAlias,
            child: Opacity(
              opacity: settled ? 1 : reveal,
              child: Transform.translate(
                // The page rides the window's rising top edge.
                offset: Offset(0, settled ? 0 : rect.top),
                child: widget.child,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The morphing window itself: the bar's clear, lensed glass thickening
  /// into a frosted pane under Glass; the page's own surface otherwise.
  Widget _window(BuildContext context, double open) {
    final corner = 32 - 4 * open;
    if (!widget.spec.glass) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(corner),
        ),
      );
    }
    final tone = AppSurface.of(context).tone;
    final lens = 18 * (1 - open);
    return LiquidGlass(
      borderRadius: BorderRadius.circular(corner),
      frost: Color.lerp(tone.controlFrost, tone.sheetFrost, open),
      blur: GlassStyle.controlBlur + (24 - GlassStyle.controlBlur) * open,
      refraction: lens < 1 ? 0 : lens,
      light: (1 - open / 0.85).clamp(0.0, 1.0),
      child: const SizedBox.expand(),
    );
  }
}

class _WindowClipper extends CustomClipper<RRect> {
  _WindowClipper(this.rect, this.corner);

  final Rect rect;
  final double corner;

  @override
  RRect getClip(Size size) =>
      RRect.fromRectAndRadius(rect, Radius.circular(math.max(0, corner)));

  @override
  bool shouldReclip(_WindowClipper old) =>
      old.rect != rect || old.corner != corner;
}

/// The page under one growing out of the bar: it stays where it is and dims,
/// as it does under a sheet.
class _Dim extends AnimatedWidget {
  const _Dim({required Animation<double> animation, required this.child})
    : super(listenable: animation);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value.clamp(0.0, 1.0);
    final dim = Curves.easeOut.transform(t);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (dim > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.4 * dim),
              ),
            ),
          ),
      ],
    );
  }
}
