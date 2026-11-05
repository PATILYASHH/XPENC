import 'package:flutter/material.dart';

/// WhatsApp's mark — the phone in a speech bubble — as a vector, so the
/// share screen's WhatsApp button wears the real logo without an icon-font
/// dependency. Drawn from the 24×24 glyph published by Simple Icons (CC0),
/// its arcs pre-converted to cubics.
class WhatsAppGlyph extends StatelessWidget {
  const WhatsAppGlyph({this.size = 24, this.color = Colors.white, super.key});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _WhatsAppPainter(color)),
  );
}

class _WhatsAppPainter extends CustomPainter {
  const _WhatsAppPainter(this.color);

  final Color color;

  static final Path _glyph = Path()
    ..moveTo(17.472, 14.382)
    ..cubicTo(17.175, 14.233, 15.714, 13.515, 15.442, 13.415)
    ..cubicTo(15.169, 13.316, 14.971, 13.267, 14.772, 13.565)
    ..cubicTo(14.575, 13.862, 14.005, 14.531, 13.832, 14.729)
    ..cubicTo(13.659, 14.928, 13.485, 14.952, 13.188, 14.804)
    ..cubicTo(12.891, 14.654, 11.933, 14.341, 10.798, 13.329)
    ..cubicTo(9.915, 12.541, 9.318, 11.568, 9.145, 11.27)
    ..cubicTo(8.972, 10.973, 9.127, 10.812, 9.275, 10.664)
    ..cubicTo(9.409, 10.531, 9.573, 10.317, 9.721, 10.144)
    ..cubicTo(9.87, 9.97, 9.919, 9.846, 10.019, 9.647)
    ..cubicTo(10.118, 9.449, 10.069, 9.276, 9.994, 9.127)
    ..cubicTo(9.919, 8.978, 9.325, 7.515, 9.078, 6.92)
    ..cubicTo(8.836, 6.341, 8.591, 6.42, 8.409, 6.41)
    ..cubicTo(8.236, 6.402, 8.038, 6.4, 7.839, 6.4)
    ..cubicTo(7.641, 6.4, 7.319, 6.474, 7.047, 6.772)
    ..cubicTo(6.775, 7.069, 6.007, 7.788, 6.007, 9.251)
    ..cubicTo(6.007, 10.713, 7.072, 12.126, 7.22, 12.325)
    ..cubicTo(7.369, 12.523, 9.316, 15.525, 12.297, 16.812)
    ..cubicTo(13.006, 17.118, 13.559, 17.301, 13.991, 17.437)
    ..cubicTo(14.703, 17.664, 15.351, 17.632, 15.862, 17.555)
    ..cubicTo(16.433, 17.47, 17.62, 16.836, 17.868, 16.142)
    ..cubicTo(18.116, 15.448, 18.116, 14.853, 18.041, 14.729)
    ..cubicTo(17.967, 14.605, 17.769, 14.531, 17.471, 14.382)
    ..moveTo(12.05, 21.785)
    ..lineTo(12.046, 21.785)
    ..cubicTo(10.276, 21.785, 8.538, 21.309, 7.015, 20.407)
    ..lineTo(6.654, 20.193)
    ..lineTo(2.913, 21.175)
    ..lineTo(3.911, 17.527)
    ..lineTo(3.676, 17.153)
    ..cubicTo(2.686, 15.577, 2.163, 13.754, 2.166, 11.893)
    ..cubicTo(2.167, 6.443, 6.602, 2.009, 12.054, 2.009)
    ..cubicTo(14.694, 2.009, 17.176, 3.039, 19.042, 4.907)
    ..cubicTo(20.902, 6.758, 21.943, 9.277, 21.935, 11.901)
    ..cubicTo(21.932, 17.351, 17.498, 21.785, 12.05, 21.785)
    ..moveTo(20.463, 3.488)
    ..cubicTo(18.237, 1.248, 15.208, -0.008, 12.05, -0)
    ..cubicTo(5.495, 0, 0.16, 5.335, 0.157, 11.892)
    ..cubicTo(0.157, 13.988, 0.704, 16.034, 1.745, 17.837)
    ..lineTo(0.057, 24)
    ..lineTo(6.362, 22.346)
    ..cubicTo(8.106, 23.296, 10.059, 23.794, 12.045, 23.794)
    ..lineTo(12.05, 23.794)
    ..cubicTo(18.604, 23.794, 23.94, 18.459, 23.943, 11.901)
    ..cubicTo(23.953, 8.745, 22.7, 5.715, 20.463, 3.488)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 24, size.height / 24)
      ..drawPath(_glyph, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_WhatsAppPainter old) => old.color != color;
}
