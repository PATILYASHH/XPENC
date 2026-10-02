import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The Glass theme's building blocks: the wallpaper every page sits on, and
/// the frosted pane every card, sheet and bar is cut from.
///
/// Glass only reads as glass when something *behind* it has shape. A smooth
/// gradient frosted is still a smooth gradient — so the wallpaper is a set
/// of saturated colour orbs with defined edges, and every pane really blurs
/// them ([BackdropFilter]), the way iOS frosts its wallpaper.
class GlassStyle {
  const GlassStyle._();

  /// Blur radius for cards and bars — strong enough to melt an orb's edge
  /// into a wash, light enough that colour still comes through.
  static const double blur = 22;

  /// Blur behind an open sheet or dialog — the whole page frosts over.
  static const double barrierBlur = 14;

  /// Frost of a pane, top-left (catching the light) to bottom-right.
  static const Color frostHigh = Color(0x8CFFFFFF);
  static const Color frostLow = Color(0x47FFFFFF);

  /// Sheets and dialogs: denser frost, since they hold forms and lists.
  static const Color floating = Color(0xB3FFFFFF);

  /// Menus and pickers Material paints *without* a blurred barrier behind
  /// them — near-opaque, or text over text becomes unreadable.
  static const Color solidFrost = Color(0xF2F7F8FC);

  static const Color barrier = Color(0x1F000000);

  /// The page tone the orbs float on.
  static const Color base = Color(0xFFF2F0FA);

  static const List<(Alignment, double, Color)> _orbs = [
    // (centre, radius as a fraction of the shorter side, colour)
    (Alignment(-0.95, -0.85), 0.78, Color(0xFF6FA6FF)), // sky blue
    (Alignment(1.05, -0.35), 0.70, Color(0xFFFF8CC8)), // pink
    (Alignment(-0.75, 0.30), 0.62, Color(0xFFA88BFF)), // violet
    (Alignment(0.95, 0.72), 0.72, Color(0xFFFFB66E)), // peach
    (Alignment(-0.10, 1.08), 0.58, Color(0xFF6EDFC6)), // mint
  ];

  /// Paints the wallpaper for a screen of [screen] size into [canvas],
  /// whose origin is the screen's top-left.
  static void paintWallpaper(Canvas canvas, Size screen) {
    final rect = Offset.zero & screen;
    canvas.drawRect(rect, Paint()..color = base);
    final side = screen.shortestSide;
    for (final (align, r, color) in _orbs) {
      final centre = align.withinRect(rect);
      final radius = side * r;
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            centre,
            radius,
            [
              color,
              color.withValues(alpha: 0.85),
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0),
            ],
            const [0, 0.6, 0.82, 1],
          ),
      );
    }
  }
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
    // Where this box sits on screen, so every slice lines up.
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

/// A frosted pane: the content behind it blurred, a white frost over that,
/// a light-catching edge and a soft shadow outside it.
///
/// [grouped] shares one backdrop read across every grouped pane under the
/// same [BackdropGroup] (each page provides one) — cheap enough for a list
/// of cards. A pane that must blur *other content* moving under it — the
/// nav bar — passes `grouped: false`.
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
      sigmaX: GlassStyle.blur,
      sigmaY: GlassStyle.blur,
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
      foregroundPainter: _GlassEdgePainter(borderRadius),
      child: pane,
    );
    pane = ClipRRect(
      borderRadius: borderRadius,
      child: group != null
          ? BackdropFilter.grouped(filter: filter, child: pane)
          : BackdropFilter(filter: filter, child: pane),
    );
    if (!shadow) return pane;
    return CustomPaint(painter: _GlassShadowPainter(borderRadius), child: pane);
  }
}

/// The pane's rim: bright where light would catch it (top-left), fading
/// along the sides, a little bright again at the bottom-right.
class _GlassEdgePainter extends CustomPainter {
  _GlassEdgePainter(this.radius);

  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(0.6);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          const [Color(0xF2FFFFFF), Color(0x40FFFFFF), Color(0x99FFFFFF)],
          const [0, 0.5, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_GlassEdgePainter old) => old.radius != radius;
}

/// A soft drop shadow drawn only *outside* the pane — under translucent
/// glass a shadow would otherwise show through and grey the frost.
class _GlassShadowPainter extends CustomPainter {
  _GlassShadowPainter(this.radius);

  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.toRRect(Offset.zero & size);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(40)),
      Path()..addRRect(rrect),
    );
    canvas
      ..save()
      ..clipPath(outside)
      ..drawRRect(
        rrect.shift(const Offset(0, 6)),
        Paint()
          ..color = const Color(0x1A3A2A6A)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_GlassShadowPainter old) => old.radius != radius;
}
