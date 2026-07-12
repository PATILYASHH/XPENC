import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'app_info.dart';

/// The XPENC mark, drawn rather than shipped as an asset.
///
/// The geometry below is the same definition `tool/generate_icons.py` rasterises
/// into the launcher icons — the numbers are duplicated, not shared, because one
/// side is Python and the other Dart. If you change a constant here, change it
/// there too and re-run the generator, or the in-app logo and the home-screen
/// icon will quietly stop being the same shape.
///
/// Vector, so it stays sharp at any size and picks up the theme's colours; an
/// asset would need a light and a dark copy at five densities.
class BrandGeometry {
  const BrandGeometry._();

  /// Fractions of the canvas width.
  static const barLength = 0.560;
  static const thickness = 0.128;

  /// The transparent gap where the ascending stroke crosses the descending one.
  /// Without it the two bars merge into a blob below about 40 dp.
  static const seam = 0.030;

  /// Superellipse exponent. 2 is an ellipse, ∞ is a square, 4.4 is the squircle.
  static const squircleN = 4.4;
  static const inset = 0.02;
}

/// A squircle tile with the X knocked into it.
///
/// Defaults invert with the theme — a black tile in light mode, a white tile in
/// dark — so the mark always sits at full contrast against the page. Pass [tile]
/// and [ink] to force the true brand colours instead (see [BrandMark.icon]).
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 40,
    this.tile,
    this.ink,
    this.radiusRim = true,
  });

  /// The literal launcher icon: near-black tile, white X, hairline rim.
  const BrandMark.icon({super.key, this.size = 40})
      : tile = const Color(0xFF0E0E10),
        ink = Colors.white,
        radiusRim = true;

  final double size;
  final Color? tile;
  final Color? ink;

  /// A faint edge so a black tile stays visible on a black page.
  final bool radiusRim;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MarkPainter(
          tile: tile ?? cs.onSurface,
          ink: ink ?? cs.surface,
          rim: radiusRim,
        ),
        isComplex: false,
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.tile, required this.ink, required this.rim});

  final Color tile;
  final Color ink;
  final bool rim;

  @override
  void paint(Canvas canvas, Size size) {
    final tilePath = _squircle(size);
    canvas.drawPath(tilePath, Paint()..color = tile);

    if (rim) {
      canvas.drawPath(
        tilePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, size.width * 0.008)
          ..color = ink.withValues(alpha: 0.10),
      );
    }

    canvas.drawPath(_mark(size), Paint()..color = ink..isAntiAlias = true);
  }

  /// |x/a|^n + |y/a|^n = 1, walked as a polygon.
  Path _squircle(Size size) {
    const n = BrandGeometry.squircleN;
    final a = size.width * (0.5 - BrandGeometry.inset);
    final c = size.width / 2;
    const e = 2.0 / n;
    const steps = 144;

    final path = Path();
    for (var i = 0; i < steps; i++) {
      final t = 2 * math.pi * i / steps;
      final ct = math.cos(t), st = math.sin(t);
      final x = c + a * _copySignPow(ct, e);
      final y = c + a * _copySignPow(st, e);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    return path..close();
  }

  static double _copySignPow(double v, double e) =>
      math.pow(v.abs(), e).toDouble() * (v.isNegative ? -1 : 1);

  /// `(descending − widenedAscending) ∪ ascending`, which is what carves the
  /// seam and puts the ascending stroke visually on top.
  Path _mark(Size size) {
    final t = size.width * BrandGeometry.thickness;
    final gap = size.width * BrandGeometry.seam;

    final descending = _bar(size, math.pi / 4, t);
    final ascending = _bar(size, -math.pi / 4, t);
    final ascendingWide = _bar(size, -math.pi / 4, t + 2 * gap);

    return Path.combine(
      PathOperation.union,
      Path.combine(PathOperation.difference, descending, ascendingWide),
      ascending,
    );
  }

  /// A stadium of the brand's bar length, rotated about the canvas centre.
  Path _bar(Size size, double angle, double thickness) {
    final c = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: c,
      width: size.width * BrandGeometry.barLength,
      height: thickness,
    );
    final bar = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(thickness / 2)));
    return bar.transform(_rotationAbout(angle, c));
  }

  /// Column-major 4×4 rotation about [c]. Hand-rolled to keep this file free of
  /// a `vector_math` import for what is ultimately six numbers.
  static Float64List _rotationAbout(double angle, Offset c) {
    final cos = math.cos(angle), sin = math.sin(angle);
    final m = Float64List(16);
    m[0] = cos;
    m[1] = sin;
    m[4] = -sin;
    m[5] = cos;
    m[10] = 1;
    m[12] = c.dx - c.dx * cos + c.dy * sin;
    m[13] = c.dy - c.dx * sin - c.dy * cos;
    m[15] = 1;
    return m;
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.tile != tile || old.ink != ink || old.rim != rim;
}

/// `XPENC`, set the way the brand sets it: heavy, tight, all caps.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.fontSize = 26, this.color});

  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppInfo.name,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: fontSize * 0.06,
        height: 1.1,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

/// Mark and wordmark locked together, for headers and the About screen.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 34, this.fontSize = 24});

  final double markSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: markSize),
        SizedBox(width: markSize * 0.34),
        BrandWordmark(fontSize: fontSize),
      ],
    );
  }
}
