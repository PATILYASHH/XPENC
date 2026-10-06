import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'app_colors.dart';
import 'theme_shape.dart';

/// The Glass theme's building blocks, modelled on iOS's Liquid Glass.
///
/// Two materials, two layers — the same split Apple draws:
///  * **Content** ([GlassPane]): cards and grouped lists. A thin, mostly
///    clear pane that blurs whatever is behind it, with a light-catching rim.
///  * **Controls** ([LiquidGlass]): everything that floats above content —
///    the tab bar, top-bar buttons, the ➕, sheets. Near-clear glass with
///    real *lensing*: on Impeller a fragment shader bends the backdrop at the
///    rim (`shaders/liquid_glass.frag`); elsewhere it degrades to blur alone.
///
/// What sits behind it all is the user's [GlassBackdrop]; its [GlassTone]
/// decides whether the glass is light or dark.
class GlassStyle {
  const GlassStyle._();

  /// Content panes: enough blur to soften what's behind into colour.
  static const double contentBlur = 20;

  /// Controls: barely any — iOS's glass keeps what slides beneath it
  /// recognisable, and the lens needs that detail to bend.
  static const double controlBlur = 3.5;

  /// Blur behind an open dialog — the page frosts over.
  static const double barrierBlur = 12;
}

/// Every colour a glass surface takes, for one kind of background. Light
/// glass is a whisper of white over a bright backdrop; dark glass a whisper
/// of white over a dark one, with softer rims and deeper shadows.
@immutable
class GlassTone {
  const GlassTone({
    required this.brightness,
    required this.frostHigh,
    required this.frostLow,
    required this.controlFrost,
    required this.selected,
    required this.sheetFrost,
    required this.floating,
    required this.solidFrost,
    required this.fill,
    required this.separator,
    required this.rimStrength,
    required this.shadowOpacity,
    required this.barrier,
    required this.quiet,
    required this.grabber,
    required this.switchOff,
    required this.track,
    required this.thumb,
    required this.edge,
    required this.ambient,
  });

  final Brightness brightness;

  /// Content pane frost, top-left to bottom-right.
  final Color frostHigh;
  final Color frostLow;

  /// Control frost — nearly clear.
  final Color controlFrost;

  /// The selected-tab droplet and similar "this one" lenses.
  final Color selected;

  /// Sheets and dialogs hold forms and lists, so they frost denser.
  final Color sheetFrost;
  final Color floating;

  /// Menus and pickers Material paints with no blur behind them.
  final Color solidFrost;

  /// Inputs, chips and secondary buttons.
  final Color fill;

  final Color separator;

  /// Multiplier on the white rim's brightness.
  final double rimStrength;
  final double shadowOpacity;
  final Color barrier;

  /// Disclosure chevrons and similar quiet glyphs.
  final Color quiet;
  final Color grabber;
  final Color switchOff;
  final Color track;

  /// Selected segment of a segmented control.
  final Color thumb;

  /// Hairline edge of inputs and outlined buttons.
  final Color edge;

  /// Opacity of the ambient glow around cards.
  final double ambient;

  bool get isDark => brightness == Brightness.dark;

  /// Light glass over a colourful, bright backdrop.
  static const light = GlassTone(
    brightness: Brightness.light,
    frostHigh: Color(0x61FFFFFF),
    frostLow: Color(0x38FFFFFF),
    controlFrost: Color(0x1FFFFFFF),
    selected: Color(0x1F787880),
    sheetFrost: Color(0xB8F7F8FC),
    floating: Color(0xD9FFFFFF),
    solidFrost: Color(0xF5F8F9FC),
    fill: Color(0x80FFFFFF),
    separator: Color(0x243C3C43),
    rimStrength: 1,
    shadowOpacity: 0.10,
    barrier: Color(0x29000000),
    quiet: Color(0xFFB4B4BA),
    grabber: Color(0x4D3C3C43),
    switchOff: Color(0x29787880),
    track: Color(0x1F787880),
    thumb: Color(0xFFFFFFFF),
    ambient: 0.42,
    edge: Color(0xB3FFFFFF),
  );

  /// Light glass over a plain white page — cards need body to show at all.
  static const paper = GlassTone(
    brightness: Brightness.light,
    frostHigh: Color(0xF2FFFFFF),
    frostLow: Color(0xE0FFFFFF),
    controlFrost: Color(0x8CFFFFFF),
    selected: Color(0x1F787880),
    sheetFrost: Color(0xD9F7F8FC),
    floating: Color(0xEBFFFFFF),
    solidFrost: Color(0xF5F8F9FC),
    fill: Color(0xFFFFFFFF),
    separator: Color(0x243C3C43),
    rimStrength: 1,
    shadowOpacity: 0.08,
    barrier: Color(0x29000000),
    quiet: Color(0xFFB4B4BA),
    grabber: Color(0x4D3C3C43),
    switchOff: Color(0x29787880),
    track: Color(0x1F787880),
    thumb: Color(0xFFFFFFFF),
    ambient: 0.18,
    edge: Color(0x1F3C3C43),
  );

  /// Dark glass over a colourful, dark backdrop: smoky, the way iOS's dark
  /// glass reads over a vivid wallpaper — a white tint there would wash the
  /// content out against the colour behind it.
  static const dark = GlassTone(
    brightness: Brightness.dark,
    frostHigh: Color(0x660E1020),
    frostLow: Color(0x8C0E1020),
    controlFrost: Color(0x4D12141F),
    selected: Color(0x1FFFFFFF),
    sheetFrost: Color(0xBF1C1C1E),
    floating: Color(0xE62C2C2E),
    solidFrost: Color(0xF22C2C2E),
    fill: Color(0x29FFFFFF),
    separator: Color(0x33FFFFFF),
    rimStrength: 0.55,
    shadowOpacity: 0.35,
    barrier: Color(0x66000000),
    quiet: Color(0xFF5C5C61),
    grabber: Color(0x66EBEBF5),
    switchOff: Color(0x52787880),
    track: Color(0x3D787880),
    thumb: Color(0x4DFFFFFF),
    ambient: 0.5,
    edge: Color(0x33FFFFFF),
  );

  /// Dark glass over pure black — iOS's dark grouped look, in glass.
  static const ink = GlassTone(
    brightness: Brightness.dark,
    frostHigh: Color(0x29FFFFFF),
    frostLow: Color(0x1AFFFFFF),
    controlFrost: Color(0x29FFFFFF),
    selected: Color(0x38FFFFFF),
    sheetFrost: Color(0xD91C1C1E),
    floating: Color(0xF22C2C2E),
    solidFrost: Color(0xF22C2C2E),
    fill: Color(0x29FFFFFF),
    separator: Color(0x33FFFFFF),
    rimStrength: 0.5,
    shadowOpacity: 0.5,
    barrier: Color(0x80000000),
    quiet: Color(0xFF5C5C61),
    grabber: Color(0x66EBEBF5),
    switchOff: Color(0x52787880),
    track: Color(0x3D787880),
    thumb: Color(0x4DFFFFFF),
    ambient: 0.10,
    edge: Color(0x33FFFFFF),
  );
}

// The five places light pools on a wallpaper, as (centre, radius as a
// fraction of the screen's longer side).
const _poolSpots = <(Alignment, double)>[
  (Alignment(-1.0, -0.95), 0.62),
  (Alignment(1.1, -0.45), 0.55),
  (Alignment(-0.9, 0.35), 0.50),
  (Alignment(1.0, 0.85), 0.58),
  (Alignment(-0.2, 1.15), 0.45),
];

/// What the Glass theme sits on — the user's pick under Theme →
/// Background. Plain pages (white, black) or soft pools of colour, the way
/// iOS wallpapers glow behind its glass.
///
/// The name is what gets stored, so **never rename a value**. Add new ones
/// at the end.
enum GlassBackdrop {
  aurora(
    label: 'Aurora',
    tone: GlassTone.light,
    base: Color(0xFFEFF2F8),
    pools: [
      Color(0xFFA9C4FF),
      Color(0xFFE6C8FF),
      Color(0xFFBDEBE0),
      Color(0xFFFFD6BF),
      Color(0xFFC9D6FF),
    ],
  ),
  white(label: 'White', tone: GlassTone.paper, base: Color(0xFFF2F2F7)),
  black(label: 'Black', tone: GlassTone.ink, base: Color(0xFF000000)),
  ocean(
    label: 'Ocean',
    tone: GlassTone.dark,
    base: Color(0xFF03101F),
    pools: [
      Color(0xFF0D5BA8),
      Color(0xFF0E8AA6),
      Color(0xFF2A3FB0),
      Color(0xFF0A7A72),
      Color(0xFF1B4C9E),
    ],
  ),
  sunset(
    label: 'Sunset',
    tone: GlassTone.light,
    base: Color(0xFFFFEDE3),
    pools: [
      Color(0xFFFFB08A),
      Color(0xFFFF8FBA),
      Color(0xFFC6A0FF),
      Color(0xFFFFD07A),
      Color(0xFFFF9E9E),
    ],
  ),
  nebula(
    label: 'Nebula',
    tone: GlassTone.dark,
    base: Color(0xFF07040F),
    pools: [
      Color(0xFF5B2BBF),
      Color(0xFFB0307E),
      Color(0xFF2A4FD6),
      Color(0xFF0F7F8A),
      Color(0xFF7A2BB0),
    ],
  );

  const GlassBackdrop({
    required this.label,
    required this.tone,
    required this.base,
    this.pools = const [],
  });

  final String label;
  final GlassTone tone;
  final Color base;

  /// Colours pooled at [_poolSpots]; empty for a plain page.
  final List<Color> pools;

  static const fallback = GlassBackdrop.aurora;

  bool get isDark => tone.isDark;

  /// The colours text and controls take on this background.
  Palette get palette => isDark ? AppPalettes.glassDark : AppPalettes.glass;

  static GlassBackdrop? byName(String name) {
    for (final b in values) {
      if (b.name == name) return b;
    }
    return null;
  }

  /// The wallpaper's colour of light around [point] (screen coordinates):
  /// its pools blended by nearness, pushed a little more saturated so a
  /// glow reads as coloured light. Plain pages give a soft cool white.
  Color ambientAt(Offset point, Size screen) {
    if (pools.isEmpty) {
      return isDark ? const Color(0xFFFFFFFF) : const Color(0xFF8FA8FF);
    }
    final rect = Offset.zero & screen;
    final side = screen.longestSide;
    var r = 0.0, g = 0.0, b = 0.0, w = 0.0;
    for (var i = 0; i < pools.length && i < _poolSpots.length; i++) {
      final (align, radius) = _poolSpots[i];
      final d = (point - align.withinRect(rect)).distance / (side * radius);
      var weight = (1 - d).clamp(0.0, 1.0);
      weight *= weight;
      final c = pools[i];
      r += c.r * weight;
      g += c.g * weight;
      b += c.b * weight;
      w += weight;
    }
    if (w < 0.0001) return pools.first;
    final hsl = HSLColor.fromColor(
      Color.from(alpha: 1, red: r / w, green: g / w, blue: b / w),
    );
    return hsl
        .withSaturation((hsl.saturation * 1.25).clamp(0.0, 1.0))
        .withLightness(
          isDark
              ? (hsl.lightness * 1.25).clamp(0.2, 0.65)
              : hsl.lightness.clamp(0.5, 0.78),
        )
        .toColor();
  }

  /// Paints this wallpaper for a screen of [screen] size into [canvas],
  /// whose origin is the screen's top-left.
  void paint(Canvas canvas, Size screen) {
    final rect = Offset.zero & screen;
    canvas.drawRect(rect, Paint()..color = base);
    final side = screen.longestSide;
    for (var i = 0; i < pools.length && i < _poolSpots.length; i++) {
      final (align, r) = _poolSpots[i];
      final color = pools[i];
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
    if (pools.isEmpty) return;
    // Dark wallpapers sit a step back, so text and amounts printed straight
    // on them (section headers, day totals) stay readable over the colour.
    if (isDark) canvas.drawRect(rect, Paint()..color = const Color(0x40000000));
    // A veil at the top keeps the status bar and large titles crisp.
    final veil = isDark ? const Color(0x59000000) : const Color(0x8CFFFFFF);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.center, [
          veil,
          veil.withValues(alpha: 0),
        ]),
    );
  }
}

/// Surface facts a widget can't read off [ColorScheme]: whether cards are
/// glass, what the page behind them is, and which [GlassTone] to tint with.
@immutable
class AppSurface extends ThemeExtension<AppSurface> {
  const AppSurface({required this.style, this.backdrop});

  static const solid = AppSurface(style: SurfaceStyle.solid);

  final SurfaceStyle style;

  /// The Glass wallpaper, painted behind every page. `null` outside Glass,
  /// where the page is the plain `scaffoldBackgroundColor`.
  final GlassBackdrop? backdrop;

  bool get isGlass => style == SurfaceStyle.glass;

  GlassTone get tone => (backdrop ?? GlassBackdrop.fallback).tone;

  static AppSurface of(BuildContext context) =>
      Theme.of(context).extension<AppSurface>() ?? solid;

  @override
  AppSurface copyWith({SurfaceStyle? style, GlassBackdrop? backdrop}) =>
      AppSurface(
        style: style ?? this.style,
        backdrop: backdrop ?? this.backdrop,
      );

  @override
  AppSurface lerp(AppSurface? other, double t) =>
      t < 0.5 ? this : (other ?? this);
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
  const GlassWallpaper({required this.backdrop, super.child, super.key});

  final GlassBackdrop backdrop;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderGlassWallpaper(MediaQuery.sizeOf(context), backdrop);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassWallpaper renderObject,
  ) {
    renderObject
      ..screen = MediaQuery.sizeOf(context)
      ..backdrop = backdrop;
  }
}

class RenderGlassWallpaper extends RenderProxyBox {
  RenderGlassWallpaper(this._screen, this._backdrop);

  Size _screen;
  set screen(Size value) {
    if (value == _screen) return;
    _screen = value;
    markNeedsPaint();
  }

  GlassBackdrop _backdrop;
  set backdrop(GlassBackdrop value) {
    if (value == _backdrop) return;
    _backdrop = value;
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
    _backdrop.paint(canvas, _screen);
    canvas.restore();
    super.paint(context, offset);
  }
}

/// A content pane — a card. A thin, see-through frost over the wallpaper in
/// iOS's continuous-corner squircle, a light-catching rim, and *ambient
/// light*: a soft glow around it, tinted by the wallpaper colour where the
/// card sits, as if the backdrop's light spilled around the glass.
///
/// No backdrop blur: what's behind a card is only the wallpaper, already a
/// soft wash of colour, so a blur pass would cost a frame's GPU time for no
/// visible difference. The blur stays on what content slides beneath — the
/// tab bar, headers, sheets.
class GlassPane extends StatelessWidget {
  const GlassPane({
    required this.child,
    required this.borderRadius,
    this.tint,
    this.frost,
    this.shadow = true,
    super.key,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// A colour to wash the pane with (a card given an explicit `color`).
  final Color? tint;

  /// Overrides the default two-tone frost with one flat frost colour.
  final Color? frost;

  /// The ambient glow and contact shadow outside the pane.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final surface = AppSurface.of(context);
    final tone = surface.tone;

    Widget pane = DecoratedBox(
      decoration: BoxDecoration(
        color: frost,
        gradient: frost != null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tone.frostHigh, tone.frostLow],
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
      foregroundPainter: GlassRimPainter(
        borderRadius,
        strength: 0.85 * tone.rimStrength,
        continuous: true,
      ),
      child: pane,
    );
    pane = ClipRSuperellipse(borderRadius: borderRadius, child: pane);
    if (!shadow) return pane;
    return _AmbientLight(
      backdrop: surface.backdrop ?? GlassBackdrop.fallback,
      radius: borderRadius,
      screen: MediaQuery.sizeOf(context),
      child: pane,
    );
  }
}

/// Paints a pane's ambient glow and contact shadow — outside it only, so
/// neither greys the see-through frost — with the glow's colour sampled
/// from the wallpaper at the pane's place on screen.
class _AmbientLight extends SingleChildRenderObjectWidget {
  const _AmbientLight({
    required this.backdrop,
    required this.radius,
    required this.screen,
    super.child,
  });

  final GlassBackdrop backdrop;
  final BorderRadius radius;
  final Size screen;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAmbientLight(backdrop, radius, screen);

  @override
  void updateRenderObject(BuildContext context, _RenderAmbientLight r) => r
    ..backdrop = backdrop
    ..radius = radius
    ..screen = screen;
}

class _RenderAmbientLight extends RenderProxyBox {
  _RenderAmbientLight(this._backdrop, this._radius, this._screen);

  GlassBackdrop _backdrop;
  set backdrop(GlassBackdrop v) {
    if (v == _backdrop) return;
    _backdrop = v;
    markNeedsPaint();
  }

  BorderRadius _radius;
  set radius(BorderRadius v) {
    if (v == _radius) return;
    _radius = v;
    markNeedsPaint();
  }

  Size _screen;
  set screen(Size v) {
    if (v == _screen) return;
    _screen = v;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final rect = offset & size;
    if (!rect.isEmpty) {
      final shape = _radius.toRSuperellipse(rect);
      final tone = _backdrop.tone;
      final glow = _backdrop.ambientAt(
        localToGlobal(size.center(Offset.zero)),
        _screen,
      );
      final outside = Path.combine(
        PathOperation.difference,
        Path()..addRect(rect.inflate(64)),
        Path()..addRSuperellipse(shape),
      );
      final side = size.shortestSide;
      final canvas = context.canvas
        ..save()
        ..clipPath(outside);
      // Ambient light: wide, unshifted, the wallpaper's own colour.
      canvas.drawRSuperellipse(
        shape,
        Paint()
          ..color = glow.withValues(alpha: tone.ambient)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            (side * 0.16).clamp(8.0, 22.0),
          ),
      );
      // Contact shadow: tighter, a touch below — the pane's weight.
      canvas
        ..drawRSuperellipse(
          shape.shift(Offset(0, (side * 0.05).clamp(1.5, 5.0))),
          Paint()
            ..color = Color.fromRGBO(20, 22, 40, tone.shadowOpacity * 0.6)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              (side * 0.07).clamp(3.0, 10.0),
            ),
        )
        ..restore();
    }
    super.paint(context, offset);
  }
}

/// An icon on a glossy tile — iOS Settings' coloured squircle with a white
/// glyph, given a light-catching top and a soft glow of its own colour.
/// Glass's "premium" icon treatment for list rows and transaction rows.
class GlassIconTile extends StatelessWidget {
  const GlassIconTile({
    required this.color,
    required this.child,
    this.extent = 30,
    super.key,
  });

  final Color color;
  final Widget child;
  final double extent;

  /// The colours tiles cycle through when a row gives no colour of its own —
  /// iOS's system palette, minus yellow (white on yellow can't be read).
  static const palette = [
    Color(0xFF0A84FF),
    Color(0xFF30B0C7),
    Color(0xFF34C759),
    Color(0xFFFF9500),
    Color(0xFFFF3B30),
    Color(0xFFAF52DE),
    Color(0xFF5856D6),
    Color(0xFFFF2D55),
    Color(0xFF8E8E93),
  ];

  /// A stable colour for an icon that came without one.
  static Color forIcon(IconData? icon) =>
      palette[(icon?.codePoint ?? 0) % palette.length];

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(extent * 0.28);
    final hsl = HSLColor.fromColor(color);
    final top = hsl
        .withLightness((hsl.lightness + 0.12).clamp(0.0, 0.92))
        .toColor();
    final bottom = hsl
        .withLightness((hsl.lightness - 0.08).clamp(0.05, 1.0))
        .toColor();
    return SizedBox.square(
      dimension: extent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: extent * 0.28,
              offset: Offset(0, extent * 0.06),
            ),
          ],
        ),
        child: ClipRSuperellipse(
          borderRadius: radius,
          child: CustomPaint(
            foregroundPainter: GlassRimPainter(
              radius,
              strength: 0.45,
              continuous: true,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [top, color, bottom],
                  stops: const [0, 0.55, 1],
                ),
              ),
              child: DecoratedBox(
                // The gloss: a soft sheen across the top half.
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
                child: Center(
                  child: IconTheme.merge(
                    data: IconThemeData(
                      color: Colors.white,
                      size: extent * 0.56,
                    ),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(fontSize: extent * 0.52),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
    this.frost,
    this.blur = GlassStyle.controlBlur,
    this.refraction = 18,
    this.band = 22,
    this.shadow = true,
    this.pressed = false,
    super.key,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final Color? tint;

  /// Defaults to the [GlassTone]'s near-clear control frost.
  final Color? frost;
  final double blur;

  /// Lens strength (logical pixels the rim pulls the backdrop inward) and
  /// the width of the curved rim band.
  final double refraction;
  final double band;

  final bool shadow;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final tone = AppSurface.of(context).tone;
    final base = frost ?? tone.controlFrost;
    final fill = tint == null
        ? base
        : Color.alphaBlend(tint!.withValues(alpha: 0.82), base);
    Widget body = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // Thickness: light pools at the top of the slab, a shade at its
          // foot. Brighter while pressed — the glass "lights up" under touch.
          colors: [
            Colors.white.withValues(
              alpha: (pressed ? 0.42 : 0.2) * tone.rimStrength,
            ),
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
    final continuous = borderRadius != null;
    Widget glass = CustomPaint(
      foregroundPainter: GlassRimPainter(
        borderRadius,
        strength: (tint == null ? 1 : 0.7) * tone.rimStrength,
        continuous: continuous,
      ),
      child: body,
    );
    final lens = _LensFilter(
      radius: borderRadius?.topLeft.x,
      blur: blur,
      refraction: refraction,
      band: band,
      dpr: MediaQuery.devicePixelRatioOf(context),
      screen: MediaQuery.sizeOf(context),
      child: glass,
    );
    glass = continuous
        ? ClipRSuperellipse(borderRadius: borderRadius!, child: lens)
        : ClipRRect(clipper: _GlassClipper(borderRadius), child: lens);
    if (!shadow) return glass;
    return CustomPaint(
      painter: GlassShadowPainter(borderRadius, opacity: tone.shadowOpacity),
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
  RRect getClip(Size size) =>
      _resolve(radius, size).toRRect(Offset.zero & size);

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
      (context, offset) =>
          context.pushLayer(_lensLayer.layer!, super.paint, offset),
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
  GlassRimPainter(this.radius, {this.strength = 1, this.continuous = false});

  /// `null` = a capsule.
  final BorderRadius? radius;
  final double strength;

  /// iOS continuous (squircle) corners rather than circular ones.
  final bool continuous;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inner = rect.deflate(0.5);
    final paint = Paint()
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
      );
    final r = _resolve(radius, size);
    if (continuous) {
      canvas.drawRSuperellipse(r.toRSuperellipse(inner), paint);
    } else {
      canvas.drawRRect(r.toRRect(inner), paint);
    }
  }

  @override
  bool shouldRepaint(GlassRimPainter old) =>
      old.radius != radius ||
      old.strength != strength ||
      old.continuous != continuous;
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
