import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_surfaces.dart';
import 'screen_security.dart';

// NCT — "non-capturable transaction" (GitHub #143).
//
// Android never lets an app touch a screenshot or a recording after the
// fact, so an NCT transaction can't be blurred *in* one. Instead it is never
// on screen in the clear unless the user is deliberately looking at it:
//
// * wherever it's listed, [NctVeil] draws a frosted stand-in — not a blur of
//   the real row, which a known font lets someone reverse — so any capture
//   taken at rest shows the stand-in. Holding the row shows it, and the
//   window turns secure first, so a capture during that peek comes out black;
// * a screen that has to show it in full (its detail page, the editor)
//   wraps itself in [SecureWhile], keeping captures blocked while it's open.

/// Frosts an NCT transaction's row until it's held. A tap still reaches the
/// row underneath (it opens the transaction as usual); a hold shows the real
/// row for as long as the finger stays down. A row inside this must not have
/// a long-press action of its own — this one would compete with it.
class NctVeil extends StatefulWidget {
  const NctVeil({required this.active, required this.child, super.key});

  /// Off for an ordinary transaction: [child] is returned untouched.
  final bool active;
  final Widget child;

  @override
  State<NctVeil> createState() => _NctVeilState();
}

class _NctVeilState extends State<NctVeil> {
  /// A [ScreenSecurity.hold] is open for this peek.
  bool _held = false;
  bool _peeking = false;

  Future<void> _peek() async {
    if (_held) return;
    _held = true;
    HapticFeedback.mediumImpact();
    // Secure first, then draw: the clear row must never reach a frame the
    // window could still hand to a recorder.
    await ScreenSecurity.hold();
    if (!mounted || !_held) return;
    setState(() => _peeking = true);
  }

  void _unpeek() {
    if (!_held) return;
    _held = false;
    if (_peeking) setState(() => _peeking = false);
    // After the frosted frame is queued, not before it.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ScreenSecurity.release(),
    );
  }

  @override
  void didUpdateWidget(NctVeil old) {
    super.didUpdateWidget(old);
    if (!widget.active) _unpeek();
  }

  @override
  void dispose() {
    if (_held) ScreenSecurity.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    final veiled = !_peeking;
    return GestureDetector(
      onLongPressStart: (_) => _peek(),
      onLongPressEnd: (_) => _unpeek(),
      onLongPressCancel: _unpeek,
      child: Semantics(
        label: veiled ? 'Hidden transaction. Touch and hold to view.' : null,
        child: Stack(
          children: [
            // Keeps the row's size and its tap, but draws none of it —
            // a fully transparent layer isn't painted at all. (Not a
            // Visibility keeping size and taps: toggling one trips a
            // semantics assertion.)
            Opacity(
              opacity: veiled ? 0 : 1,
              child: ExcludeSemantics(excluding: veiled, child: widget.child),
            ),
            // Always present, only hidden: the Stack keeps one shape, so
            // a peek changes what's drawn, never the tree around it.
            Positioned.fill(
              child: Visibility(visible: veiled, child: const _Frost()),
            ),
          ],
        ),
      ),
    );
  }
}

/// The stand-in: the shape of a row — a leading circle, two lines, an amount
/// — in faint bars that never say anything, and a note on how to see it.
class _Frost extends StatelessWidget {
  const _Frost();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bar = cs.onSurface.withValues(alpha: 0.07);
    Widget line(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bar,
        borderRadius: BorderRadius.circular(height),
      ),
    );

    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          // A compact row (a linked transaction's one line) has no room for
          // the leading circle; the note alone says what this is.
          builder: (context, constraints) => Padding(
            padding: EdgeInsets.symmetric(
              horizontal: constraints.maxHeight < 44 ? 0 : 16,
            ),
            child: Row(
              children: [
                if (constraints.maxHeight >= 44) ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: bar,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(
                          Icons.visibility_off_outlined,
                          size: 15,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Hidden · hold to view',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                line(56, 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps captures blocked while [active] and this is on screen — for a
/// screen that shows an NCT transaction in full and can't frost it: its
/// detail page, or the editor once the NCT switch is on.
class SecureWhile extends StatefulWidget {
  const SecureWhile({
    required this.active,
    required this.child,
    this.holdBack = true,
    super.key,
  });

  final bool active;
  final Widget child;

  /// When this first appears already [active], draw nothing of [child]
  /// until the window is confirmed secure — a detail page's content shows
  /// up together with it. Turning [active] on later never blanks anything:
  /// that content was on screen a moment ago anyway, so it would only flash.
  final bool holdBack;

  @override
  State<SecureWhile> createState() => _SecureWhileState();
}

class _SecureWhileState extends State<SecureWhile> {
  bool _held = false;
  late bool _waiting = widget.holdBack && widget.active;

  Future<void> _sync() async {
    if (widget.active == _held) return;
    _held = widget.active;
    if (!_held) {
      await ScreenSecurity.release();
      return;
    }
    await ScreenSecurity.hold();
    if (mounted && _waiting) setState(() => _waiting = false);
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SecureWhile old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    if (_held) ScreenSecurity.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Laid out, never painted or touched, until it's safe to show.
    return IgnorePointer(
      ignoring: _waiting,
      child: Opacity(
        opacity: _waiting ? 0 : 1,
        child: ExcludeSemantics(excluding: _waiting, child: widget.child),
      ),
    );
  }
}
