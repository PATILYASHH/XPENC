import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

/// Shared motion. Every animation here is one-shot and cheap: no controllers to
/// leak, and each one respects the platform "reduce motion" setting.

/// A one-shot entrance — fade in while rising a few pixels.
///
/// `index` staggers siblings so a screen assembles top-down instead of popping
/// in all at once. The stagger is folded into a single tween via [Interval],
/// so there is no timer and no controller to dispose.
class Reveal extends StatelessWidget {
  const Reveal({required this.child, this.index = 0, super.key});

  final Widget child;

  /// Position among siblings. Each step delays the entrance by [_stagger].
  final int index;

  static const _duration = Duration(milliseconds: 380);
  static const _stagger = Duration(milliseconds: 60);
  static const _rise = 18.0;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final delay = _stagger * index;
    final total = _duration + delay;
    final start = delay.inMicroseconds / total.inMicroseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * _rise),
          child: child,
        ),
      ),
    );
  }
}

/// Shrinks its child while a finger is down, giving a card the same physical
/// give a button has.
///
/// Uses [Listener] rather than [GestureDetector] on purpose: it observes raw
/// pointer events without entering the gesture arena, so an [InkWell] beneath
/// still gets its tap and its ripple.
class PressScale extends StatefulWidget {
  const PressScale({required this.child, this.scale = 0.97, super.key});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;
  Offset _origin = Offset.zero;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  /// A scroll is not a press. Once the finger travels past the touch slop the
  /// gesture belongs to the scrollable, and no tap-cancel is coming — so let go
  /// of the card ourselves rather than holding it shrunk for the whole drag.
  void _onMove(PointerMoveEvent event) {
    if (_down && (event.position - _origin).distance > kTouchSlop) _set(false);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _origin = event.position;
        _set(true);
      },
      onPointerMove: _onMove,
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A rounded progress bar whose fill grows into place.
///
/// Prefer this over [LinearProgressIndicator] for anything that shows a
/// *value* — its rounded fill sits in a visible groove and it animates whenever
/// the value changes, not just on first build.
class AnimatedBar extends StatelessWidget {
  const AnimatedBar({
    required this.fraction,
    required this.color,
    this.track,
    this.height = 8,
    this.duration = const Duration(milliseconds: 700),
    super.key,
  });

  /// Clamped to 0..1 — an overspent budget fills the bar, it does not overflow.
  final double fraction;
  final Color color;

  /// The unfilled remainder. Defaults to the theme's recessed groove; pass a
  /// colour when the remainder itself means something (income vs expense).
  final Color? track;
  final double height;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = fraction.clamp(0.0, 1.0).toDouble();
    final animate = !MediaQuery.disableAnimationsOf(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: ColoredBox(
          color: track ?? theme.colorScheme.surfaceContainerHighest,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: animate ? 0 : target, end: target),
            duration: animate ? duration : Duration.zero,
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
