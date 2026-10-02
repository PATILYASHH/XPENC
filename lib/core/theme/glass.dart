import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The Glass theme's building blocks, modelled on iOS's Liquid Glass.
///
/// Two materials, two layers — the same split Apple draws:
///  * **Content** ([GlassPane]): cards and grouped lists. A frosted pane
///    that blurs the wallpaper behind it, with a light-catching rim.
///  * **Controls** ([LiquidGlass]): everything that floats above content —
///    the tab bar, top-bar buttons, the ➕, sheets. Clearer glass with real
///    *lensing*: on Impeller a fragment shader bends the backdrop at the rim
///    (`shaders/liquid_glass.frag`); elsewhere it degrades to blur alone.
class GlassStyle {
  const GlassStyle._();

  /// Content panes: enough blur to melt the wallpaper into a wash.
  static const double contentBlur = 26;

  /// Controls: little blur, so what slides beneath stays legible and the
  /// lens has detail to bend.
  static const double controlBlur = 7;

  /// Blur behind an open dialog — the page frosts over.
  static const double barrierBlur = 12;

  // Content frost, top-left (catching the light) to bottom-right.
  static const Color frostHigh = Color(0xA8FFFFFF);
  static const Color frostLow = Color(0x80FFFFFF);

  /// Control frost: mostly clear, with a whisper of white.
  static const Color controlFrost = Color(0x4DFFFFFF);

  /// Sheets: denser, since they hold forms and lists over a busy page.
  static const Color sheetFrost = Color(0xC7F9FAFE);

  /// Dialogs sit over a blurred, dimmed page.
  static const Color floating = Color(0xD9FFFFFF);

  /// Menus and pickers Material paints with no blur behind them —
  /// near-opaque, or text lands on text.
  static const Color solidFrost = Color(0xF5F8F9FC);

  static const Color barrier = Color(0x29000000);

  /// The page tone the wallpaper's light pools on.
  static const Color base = Color(0xFFEFF2F8);

  // (centre, radius as a fraction of the screen's longer side, colour)
  static const List<(Alignment, double, Color)> _pools = [
    (Alignment(-1.0, -0.95), 0.62, Color(0xFFA9C4FF)), // periwinkle
    (Alignment(1.1, -0.45), 0.55, Color(0xFFE6C8FF)), // lilac
    (Alignment(-0.9, 0.35), 0.50, Color(0xFFBDEBE0)), // mint
    (Alignment(1.0, 0.85), 0.58, Color(0xFFFFD6BF)), // peach
    (Alignment(-0.2, 1.15), 0.45, Color(0xFFC9D6FF)), // haze
  ];

  /// Paints the wallpaper for a screen of [screen] size into [canvas],
  /// whose origin is the screen's top-left: soft pools of light, the airy
  /// kind iOS wallpapers use, rather than hard shapes.
  static void paintWallpaper(Canvas canvas, Size screen) {
    final rect = Offset.zero & screen;
    canvas.drawRect(rect, Paint()..color = base);
    final side = screen.longestSide;
    for (final (align, r, color) in _pools) {
      final centre = align.withinRect(rect);
      final radius = side * r;
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            centre,
            radius,
            [color, color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
            const [0, 0.5, 1],
          ),
      );
    }
    // A top-down veil of light keeps the status bar and titles crisp.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.center,
          const [Color(0x8CFFFFFF), Color(0x00FFFFFF)],
        ),
    );
  }
}

/// Loads and holds the lens shader. [program] stays `null` where the
/// renderer can't run shader filters (Skia, tests), and every glass surface
/// then falls back to blur alone.
class LiquidGlassShader {
  const LiquidGlassShader._();

  static ui.FragmentProgram? _program;
  static ui.FragmentProgram? get program => _program;

  /// Call once before `runApp`. Never throws: a failure only costs the lens.
  static Future<void> load() async {
    if (_program != null || !ui.ImageFilter.isShaderFilterSupported) return;
    try {
      _program = await ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass.frag',
      );
    } catch (e) {
      debugPrint('Liquid Glass lens unavailable: $e');
    }
  }

  @visibleForTesting
  static void debugReset() => _program = null;
}

/// Paints the Glass wallpaper behind [child], in *screen* coordinates — so a
/// page nested inside the shell (below its top bar) shows exactly the slice
/// of wallpaper the shell shows around it, with no seam where they meet.
class GlassWallpaper extends SingleChildRenderObjectWidget {
  const GlassWallpaper({super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderGlassWallpaper(MediaQuery.sizeOf(context));

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassWallpaper renderObject,
  ) {
    renderObject.screen = MediaQuery.sizeOf(context);
  }
}

class RenderGlassWallpaper extends RenderProxyBox {
  RenderGlassWallpaper(this._screen);

  Size _screen;
  set screen(Size value) {
    if (value == _screen) return;
    _screen = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final origin = localToGlobal(Offset.zero);
    canvas
      ..save()
      ..clipRect(offset & size)
      ..translate(offset.dx - origin.dx, offset.dy - origin.dy);
    GlassStyle.paintWallpaper(canvas, _screen);
    canvas.restore();
    super.paint(context, offset);
  }
}

/// A content pane — a card. The wallpaper behind it blurred, a white frost
/// over that, a light-catching rim and a soft shadow outside it.
///
/// [grouped] shares one backdrop read across every grouped pane under the
/// same [BackdropGroup] (each page provides one) — cheap enough for a long
/// list of cards.
class GlassPane extends StatelessWidget {
  const GlassPane({
    required this.child,
    required this.borderRadius,
    this.tint,
    this.frost,
    this.grouped = true,
    this.shadow = true,
    super.key,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// A colour to wash the pane with (a card given an explicit `color`).
  final Color? tint;

  /// Overrides the default two-tone frost with one flat frost colour.
  final Color? frost;

  final bool grouped;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final filter = ui.ImageFilter.blur(
      sigmaX: GlassStyle.contentBlur,
      sigmaY: GlassStyle.contentBlur,
      tileMode: TileMode.mirror,
    );
    final group = grouped ? BackdropGroup.of(context) : null;

    Widget pane = DecoratedBox(
      decoration: BoxDecoration(
        color: frost,
        gradient: frost != null
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [GlassStyle.frostHigh, GlassStyle.frostLow],
              ),
      ),
      child: tint == null
          ? child
          : DecoratedBox(
              decoration: BoxDecoration(
                color: tint!.withValues(alpha: (tint!.a * 0.35).clamp(0, 0.3)),
              ),
              child: child,
            ),
    );
    pane = CustomPaint(
      foregroundPainter: GlassRimPainter(borderRadius, strength: 0.85),
      child: pane,
    );
    pane = ClipRRect(
      borderRadius: borderRadius,
      child: group != null
          ? BackdropFilter.grouped(filter: filter, child: pane)
          : BackdropFilter(filter: filter, child: pane),
    );
    if (!shadow) return pane;
    return CustomPaint(
      painter: GlassShadowPainter(borderRadius, opacity: 0.07),
      child: pane,
    );
  }
}

/// Liquid Glass — the control material. Clear, lensed glass for anything
/// that floats above content.
///
/// [borderRadius] defaults to a capsule (half the shorter side, resolved
/// from the laid-out size). [tint] colours the glass the way iOS tints a
/// prominent button; [pressed] lifts the highlight while a finger is down
/// (see [GlassButton]).
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    required this.child,
    this.borderRadius,
    this.tint,
    this.frost = GlassStyle.controlFrost,
    this.blur = GlassStyle.controlBlur,
    this.refraction = 14,
    this.band = 20,
    this.shadow = true,
    this.pressed = false,
    super.key,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final Color? tint;
  final Color frost;
  final double blur;

  /// Lens strength (logical pixels the rim pulls the backdrop inward) and
  /// the width of the curved rim band.
  final double refraction;
  final double band;

  final bool shadow;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final fill = tint == null
        ? frost
        : Color.alphaBlend(tint!.withValues(alpha: 0.82), frost);
    Widget body = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // Thickness: light pools at the top of the slab, a shade at its
          // foot. Brighter while pressed — the glass "lights up" under touch.
          colors: [
            Colors.white.withValues(alpha: pressed ? 0.45 : 0.26),
            Colors.white.withValues(alpha: 0),
            Colors.black.withValues(alpha: tint == null ? 0.03 : 0.07),
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: child,
    );
    body = DecoratedBox(
      decoration: BoxDecoration(color: fill),
      child: body,
    );
    Widget glass = CustomPaint(
      foregroundPainter: GlassRimPainter(
        borderRadius,
        strength: tint == null ? 1 : 0.7,
      ),
      child: body,
    );
    glass = ClipRRect(
      clipper: _GlassClipper(borderRadius),
      child: _LensFilter(
        radius: borderRadius?.topLeft.x,
        blur: blur,
        refraction: refraction,
        band: band,
        dpr: MediaQuery.devicePixelRatioOf(context),
        screen: MediaQuery.sizeOf(context),
        child: glass,
      ),
    );
    if (!shadow) return glass;
    return CustomPaint(
      painter: GlassShadowPainter(borderRadius, opacity: 0.12),
      child: glass,
    );
  }
}

/// [radius], or a capsule of whatever size the pane turned out to be.
BorderRadius _resolve(BorderRadius? radius, Size size) =>
    radius ?? BorderRadius.circular(size.shortestSide / 2);

class _GlassClipper extends CustomClipper<RRect> {
  _GlassClipper(this.radius);

  final BorderRadius? radius;

  @override
  RRect getClip(Size size) => _resolve(radius, size).toRRect(Offset.zero & size);

  @override
  bool shouldReclip(_GlassClipper old) => old.radius != radius;
}

/// The backdrop filter behind a [LiquidGlass]: on Impeller the lens shader
/// (then a light blur), otherwise blur alone.
class _LensFilter extends SingleChildRenderObjectWidget {
  const _LensFilter({
    required this.radius,
    required this.blur,
    required this.refraction,
    required this.band,
    required this.dpr,
    required this.screen,
    super.child,
  });

  /// `null` = a capsule, resolved from the laid-out size.
  final double? radius;
  final double blur;
  final double refraction;
  final double band;
  final double dpr;
  final Size screen;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLensFilter()
    ..radius = radius
    ..blur = blur
    ..refraction = refraction
    ..band = band
    ..dpr = dpr
    ..screen = screen;

  @override
  void updateRenderObject(BuildContext context, _RenderLensFilter r) => r
    ..radius = radius
    ..blur = blur
    ..refraction = refraction
    ..band = band
    ..dpr = dpr
    ..screen = screen;
}

class _RenderLensFilter extends RenderProxyBox {
  double? _radius;
  double _blur = 0, _refraction = 0, _band = 0, _dpr = 1;

  set radius(double? v) {
    if (_radius == v) return;
    _radius = v;
    markNeedsPaint();
  }

  set blur(double v) => _set(_blur, v, (x) => _blur = x);
  set refraction(double v) => _set(_refraction, v, (x) => _refraction = x);
  set band(double v) => _set(_band, v, (x) => _band = x);
  set dpr(double v) => _set(_dpr, v, (x) => _dpr = x);

  Size _screen = Size.zero;
  set screen(Size v) {
    if (_screen == v) return;
    _screen = v;
    markNeedsPaint();
  }

  void _set(double old, double v, void Function(double) write) {
    if (old == v) return;
    write(v);
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  final _blurLayer = LayerHandle<BackdropFilterLayer>();
  final _lensLayer = LayerHandle<BackdropFilterLayer>();

  @override
  void dispose() {
    _blurLayer.layer = null;
    _lensLayer.layer = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    // Two passes, not one composed filter: composing lets the engine pad
    // the shader's input by the blur radius, and the lens then can't tell
    // where the pane sits in it. Blur first, then the lens bends the
    // blurred backdrop.
    _blurLayer.layer ??= BackdropFilterLayer();
    _blurLayer.layer!.filter = ui.ImageFilter.blur(
      sigmaX: _blur,
      sigmaY: _blur,
      tileMode: TileMode.mirror,
    );
    final program = LiquidGlassShader.program;
    if (program == null || _refraction <= 0) {
      _lensLayer.layer = null;
      context.pushLayer(_blurLayer.layer!, super.paint, offset);
      return;
    }
    final origin = localToGlobal(Offset.zero) * _dpr;
    final screen = _screen;
    final shader = program.fragmentShader()
      // 0–1: uSize, written by the engine.
      ..setFloat(2, origin.dx)
      ..setFloat(3, origin.dy)
      ..setFloat(4, size.width * _dpr)
      ..setFloat(5, size.height * _dpr)
      ..setFloat(6, (_radius ?? size.shortestSide / 2) * _dpr)
      ..setFloat(7, _refraction * _dpr)
      ..setFloat(8, _band * _dpr)
      ..setFloat(9, 0.18)
      ..setFloat(10, 1.04)
      ..setFloat(11, screen.width * _dpr)
      ..setFloat(12, screen.height * _dpr);
    _lensLayer.layer ??= BackdropFilterLayer();
    _lensLayer.layer!.filter = ui.ImageFilter.shader(shader);
    context.pushLayer(
      _blurLayer.layer!,
      (context, offset) => context.pushLayer(
        _lensLayer.layer!,
        super.paint,
        offset,
      ),
      offset,
    );
  }
}

/// A glass control you press: the pane dips and springs back, and its
/// highlight brightens under the finger — Liquid Glass's tactile response.
class GlassButton extends StatefulWidget {
  const GlassButton({
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.tint,
    this.size,
    this.borderRadius,
    this.tooltip,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Color? tint;

  /// Fixed square size (a circle). Leave null to size to [child].
  final double? size;
  final BorderRadius? borderRadius;
  final String? tooltip;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    Widget glass = LiquidGlass(
      tint: widget.tint,
      borderRadius: widget.borderRadius,
      pressed: _down,
      child: widget.size == null
          ? widget.child
          : SizedBox.square(
              dimension: widget.size,
              child: Center(child: widget.child),
            ),
    );
    glass = AnimatedScale(
      scale: _down ? 0.9 : 1,
      duration: Duration(milliseconds: _down ? 90 : 420),
      curve: _down ? Curves.easeOut : Curves.elasticOut,
      child: glass,
    );
    final enabled = widget.onPressed != null || widget.onLongPress != null;
    Widget result = Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setDown(true) : null,
        onTapUp: enabled ? (_) => _setDown(false) : null,
        onTapCancel: () => _setDown(false),
        onTap: widget.onPressed,
        onLongPress: widget.onLongPress,
        child: glass,
      ),
    );
    if (widget.tooltip != null) {
      result = Tooltip(message: widget.tooltip!, child: result);
    }
    return result;
  }
}

/// The glyph inside a Glass back/close button: a small glass disc. Used by
/// the Glass theme's `actionIconTheme`, so every AppBar's automatic
/// back button wears it with no per-screen change.
class GlassNavGlyph extends StatelessWidget {
  const GlassNavGlyph(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: LiquidGlass(
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// The rim of a glass pane: bright where light would catch it (top-left),
/// fading along the sides, catching again at the bottom-right.
class GlassRimPainter extends CustomPainter {
  GlassRimPainter(this.radius, {this.strength = 1});

  /// `null` = a capsule.
  final BorderRadius? radius;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = _resolve(radius, size).toRRect(rect).deflate(0.5);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          [
            Colors.white.withValues(alpha: 0.95 * strength),
            Colors.white.withValues(alpha: 0.18 * strength),
            Colors.white.withValues(alpha: 0.12 * strength),
            Colors.white.withValues(alpha: 0.7 * strength),
          ],
          const [0, 0.38, 0.62, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(GlassRimPainter old) =>
      old.radius != radius || old.strength != strength;
}

/// A soft drop shadow drawn only *outside* the pane — under translucent
/// glass a shadow would otherwise show through and grey the frost.
class GlassShadowPainter extends CustomPainter {
  GlassShadowPainter(this.radius, {this.opacity = 0.1});

  /// `null` = a capsule.
  final BorderRadius? radius;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = _resolve(radius, size).toRRect(Offset.zero & size);
    // Scaled to the pane: a 40-pt button casts a tight shadow that stays
    // inside a toolbar's clip; a sheet or card casts a broad, soft one.
    final side = size.shortestSide;
    final spread = (side * 0.1).clamp(3.0, 14.0);
    final lift = (side * 0.06).clamp(1.5, 6.0);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(48)),
      Path()..addRRect(rrect),
    );
    canvas
      ..save()
      ..clipPath(outside)
      ..drawRRect(
        rrect.shift(Offset(0, lift)),
        Paint()
          ..color = Color.fromRGBO(30, 34, 60, opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, spread),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(GlassShadowPainter old) =>
      old.radius != radius || old.opacity != opacity;
}
