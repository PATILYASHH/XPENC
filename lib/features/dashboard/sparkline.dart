import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// A small, axis-less trend line with a gradient wash beneath it.
///
/// It answers one question — "which way is this going?" — so it carries no
/// labels, no grid and no scale. Read the number above it for the value.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.values,
    required this.color,
    required this.background,
    this.height = 64,
    super.key,
  });

  /// Oldest first. Fewer than two points draws nothing: a single point is not
  /// a trend.
  final List<double> values;
  final Color color;

  /// Painted behind the leading dot so the line never touches it.
  final Color background;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height);

    if (MediaQuery.disableAnimationsOf(context)) {
      return SizedBox(height: height, child: _paint(1));
    }

    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => _paint(t),
      ),
    );
  }

  Widget _paint(double t) => CustomPaint(
        size: Size.infinite,
        painter: _SparklinePainter(
          values: values,
          color: color,
          background: background,
          progress: t,
        ),
      );
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.background,
    required this.progress,
  });

  final List<double> values;
  final Color color;
  final Color background;

  /// 0 → nothing drawn, 1 → the whole line. Sweeps left to right.
  final double progress;

  static const _padX = 6.0;
  static const _padTop = 10.0;
  static const _padBottom = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final points = _points(size);
    if (points.length < 2) return;

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final p = points[i];
      // Control points share the midpoint's x, which flattens the tangent at
      // every sample — the curve eases between values without overshooting them.
      final midX = (prev.dx + p.dx) / 2;
      line.cubicTo(midX, prev.dy, midX, p.dy, p.dx, p.dy);
    }

    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.26),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    canvas.restore();

    // The head of the line, faded in only once the sweep has nearly reached it.
    final dot = ((progress - 0.8) / 0.2).clamp(0.0, 1.0);
    if (dot > 0) {
      final head = points.last;
      canvas.drawCircle(
          head, 5.5 * dot, Paint()..color = background.withValues(alpha: dot));
      canvas.drawCircle(
          head, 3.5 * dot, Paint()..color = color.withValues(alpha: dot));
    }
  }

  List<Offset> _points(Size size) {
    var min = values.first;
    var max = values.first;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }

    final usableW = size.width - _padX * 2;
    final usableH = size.height - _padTop - _padBottom;
    final span = max - min;
    final stepX = usableW / (values.length - 1);

    return [
      for (var i = 0; i < values.length; i++)
        Offset(
          _padX + stepX * i,
          // A flat series has no shape to show, so it rides the middle.
          span == 0
              ? _padTop + usableH / 2
              : _padTop + usableH * (1 - (values[i] - min) / span),
        ),
    ];
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.background != background ||
      !listEquals(old.values, values);
}
