part of 'app_shell.dart';

// Hold the bottom bar to edit it. A one-second hold "charges" the bar (it
// swells and lifts a little under the finger, so the wait never feels
// stuck); then the page dims and frosts, the bar springs up, and each of
// its four tabs becomes a wheel of modules to scroll through. Picking a
// module that's already on the bar swaps the two, so each is there once;
// More can't leave the bar (it's the way into Settings).

/// How long the bar has to be held before the editor opens.
const kNavHoldToEdit = Duration(seconds: 1);

/// Wraps the bar's tabs: a [kNavHoldToEdit] hold calls [onTriggered] with
/// the wrapped area's on-screen rect. Built on a long-press recognizer, so
/// once the hold wins, the tab under the finger isn't also tapped.
class _NavHoldToEdit extends StatefulWidget {
  const _NavHoldToEdit({
    required this.child,
    required this.enabled,
    required this.onTriggered,
  });

  final Widget child;
  final bool enabled;
  final ValueChanged<Rect> onTriggered;

  @override
  State<_NavHoldToEdit> createState() => _NavHoldToEditState();
}

class _NavHoldToEditState extends State<_NavHoldToEdit>
    with SingleTickerProviderStateMixin {
  late final _charge = AnimationController(
    vsync: this,
    duration: kNavHoldToEdit,
  );

  @override
  void dispose() {
    _charge.dispose();
    super.dispose();
  }

  void _down() => _charge.forward(from: 0);

  void _cancel() => _charge.animateBack(
    0,
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
  );

  void _fire() {
    HapticFeedback.heavyImpact();
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      widget.onTriggered(box.localToGlobal(Offset.zero) & box.size);
    }
    // Settles back under the editor, which draws its own lifted bar.
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _charge.value = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(duration: kNavHoldToEdit),
              (r) => r
                ..onLongPressDown = ((_) => _down())
                ..onLongPressCancel = _cancel
                ..onLongPress = _fire,
            ),
      },
      child: AnimatedBuilder(
        animation: _charge,
        child: widget.child,
        builder: (context, child) {
          // Nothing for the first quarter second, so a plain tap never
          // wobbles the bar; then a steady swell up to the moment it opens.
          final v = Curves.easeInCubic.transform(
            ((_charge.value - 0.2) / 0.8).clamp(0.0, 1.0),
          );
          return Transform.translate(
            offset: Offset(0, -8 * v),
            child: Transform.scale(scale: 1 + 0.05 * v, child: child),
          );
        },
      ),
    );
  }
}

/// Opens the editor over everything, for a bar whose tabs sit in [slots]
/// (on-screen rects, left to right) showing [layout].
void _openNavEditor(
  BuildContext context, {
  required List<String> layout,
  required List<Rect> slots,
  required Rect bar,
  required bool glass,
}) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 560),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, animation, _) => _NavEditor(
        animation: animation,
        layout: layout,
        slots: slots,
        bar: bar,
        glass: glass,
      ),
    ),
  );
}

class _NavEditor extends ConsumerStatefulWidget {
  const _NavEditor({
    required this.animation,
    required this.layout,
    required this.slots,
    required this.bar,
    required this.glass,
  });

  final Animation<double> animation;
  final List<String> layout;
  final List<Rect> slots;
  final Rect bar;
  final bool glass;

  @override
  ConsumerState<_NavEditor> createState() => _NavEditorState();
}

class _NavEditorState extends ConsumerState<_NavEditor> {
  late List<String> _layout = List.of(widget.layout);
  late final List<String> _modules;
  late final List<FixedExtentScrollController> _wheels;

  /// The module under each wheel's lens right now, mid-scroll included.
  late final List<String> _centred = List.of(widget.layout);

  /// Wheels being turned by us (a swap, a bounce-back, Reset), not by a
  /// finger — no tick for those.
  int _driven = 0;

  /// Briefly set when a move was refused, to say why.
  String? _hint;
  int _hintSerial = 0;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    final basic = ref.read(appModeProvider) == AppMode.basic;
    _modules = [
      for (final id in bottomNavModuleIds)
        if (!(basic && basicModeHiddenCatalogIds.contains(id))) id,
    ];
    _wheels = [
      for (final id in _layout)
        FixedExtentScrollController(initialItem: _modules.indexOf(id)),
    ];
  }

  @override
  void dispose() {
    for (final w in _wheels) {
      w.dispose();
    }
    super.dispose();
  }

  double get _itemExtent => widget.bar.height;

  String _moduleAt(int item) =>
      _modules[((item % _modules.length) + _modules.length) % _modules.length];

  /// Turns wheel [slot] the short way round to [id].
  Future<void> _turnTo(int slot, String id) async {
    final wheel = _wheels[slot];
    final n = _modules.length;
    final current = wheel.selectedItem;
    final target = _modules.indexOf(id);
    final base = current - ((current % n) + n) % n;
    var best = base + target;
    for (final c in [base + target - n, base + target + n]) {
      if ((c - current).abs() < (best - current).abs()) best = c;
    }
    if (best == current) return;
    _driven++;
    try {
      await wheel.animateToItem(
        best,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
      );
    } finally {
      _driven--;
    }
  }

  /// A wheel came to rest: commit what it landed on, swapping with the
  /// slot that had it, or bounce back if that would take More off the bar.
  void _settled(int slot) {
    if (_closing) return;
    final id = _moduleAt(_wheels[slot].selectedItem);
    if (id == _layout[slot]) return;
    final next = pickBottomNavModule(_layout, slot, id);
    if (next == null) {
      HapticFeedback.mediumImpact();
      _flashHint(
        tr('More stays on the bar. Move it by picking it in another slot.'),
      );
      _turnTo(slot, _layout[slot]);
      return;
    }
    final before = _layout;
    setState(() => _layout = next);
    for (var i = 0; i < next.length; i++) {
      if (i != slot && next[i] != before[i]) _turnTo(i, next[i]);
    }
  }

  void _flashHint(String text) {
    final serial = ++_hintSerial;
    setState(() => _hint = text);
    Future<void>.delayed(const Duration(milliseconds: 2600), () {
      if (mounted && serial == _hintSerial) setState(() => _hint = null);
    });
  }

  void _reset() {
    HapticFeedback.selectionClick();
    setState(() => _layout = List.of(defaultBottomNavLayout));
    for (var i = 0; i < _layout.length; i++) {
      _turnTo(i, _layout[i]);
    }
  }

  Future<void> _done() async {
    if (_closing) return;
    _closing = true;
    HapticFeedback.mediumImpact();
    final changed = !listEquals(_layout, widget.layout);
    if (changed) await ref.read(dbProvider).setBottomNavLayout(_layout);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final showLabels = ref.watch(showBottomNavLabelsProvider);
    final ext = _itemExtent;
    // Room for two modules under the lens, however low the bar sits.
    final lift = math.max(
      96.0,
      2 * ext - (size.height - widget.bar.bottom) + 16,
    );
    final wheelHeight = ext * 5;

    final appear = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final pop = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    return PopScope(
      // Back cancels: nothing is saved.
      onPopInvokedWithResult: (_, _) => _closing = true,
      child: AnimatedBuilder(
        animation: widget.animation,
        builder: (context, _) {
          final a = appear.value.clamp(0.0, 1.0);
          final up = lift * pop.value;
          final lens = widget.bar.translate(0, -up);
          final lensMid = lens.center.dy;
          return Stack(
            children: [
              // The page dims and frosts; a tap on it is "Done".
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _done,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10 * a, sigmaY: 10 * a),
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.55 * a),
                    ),
                  ),
                ),
              ),
              // The lifted bar: the lens each wheel's choice sits in.
              Positioned.fromRect(
                rect: lens,
                child: Transform.scale(
                  scale: 0.96 + 0.04 * pop.value,
                  child: _lens(context),
                ),
              ),
              for (var i = 0; i < widget.slots.length; i++)
                Positioned(
                  left: widget.slots[i].left,
                  width: widget.slots[i].width,
                  top: lensMid - wheelHeight / 2,
                  height: wheelHeight,
                  child: _wheelIn(i, showLabels),
                ),
              // Title, hint and controls, above the wheels.
              Positioned(
                left: 20,
                right: 20,
                bottom: size.height - (lensMid - wheelHeight / 2) + 8,
                child: Opacity(
                  opacity: a,
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - a)),
                    child: _header(context, showLabels),
                  ),
                ),
              ),
              if (_hint != null)
                Positioned(
                  left: 24,
                  right: 24,
                  top: lens.bottom + ext * 2 + 12 > size.height - 40
                      ? lens.top - ext * 2.5 - 56
                      : lens.bottom + ext * 2 + 12,
                  child: _HintPill(key: ValueKey(_hintSerial), text: _hint!),
                ),
              if (a < 1)
                // Keeps the wheels from being grabbed mid-flight.
                const Positioned.fill(child: AbsorbPointer()),
            ],
          );
        },
      ),
    );
  }

  Widget _lens(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (widget.glass) {
      final tone = AppSurface.of(context).tone;
      return LiquidGlass(
        borderRadius: BorderRadius.circular(32),
        frost: tone.barFrost,
        tint: cs.secondary.withValues(alpha: 0.18),
        child: const SizedBox.expand(),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.secondary.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
    );
  }

  /// Wheel [i], dealt in a beat after the one before it.
  Widget _wheelIn(int i, bool showLabels) {
    final start = 0.12 + 0.08 * i;
    final t = Interval(
      start,
      (start + 0.6).clamp(0.0, 1.0),
      curve: Curves.easeOutBack,
    ).transform(widget.animation.value);
    final fade = widget.animation.status == AnimationStatus.reverse
        ? widget.animation.value
        : t.clamp(0.0, 1.0);
    return Opacity(
      opacity: fade.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.7 + 0.3 * t,
        child: NotificationListener<ScrollEndNotification>(
          onNotification: (_) {
            // After this frame: the wheel's selected item is final by then.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _driven == 0) _settled(i);
            });
            return false;
          },
          child: ListWheelScrollView.useDelegate(
            key: ValueKey('navWheel$i'),
            controller: _wheels[i],
            itemExtent: _itemExtent,
            diameterRatio: 1.7,
            perspective: 0.004,
            overAndUnderCenterOpacity: 0.55,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (item) {
              if (_driven == 0) HapticFeedback.selectionClick();
              setState(() => _centred[i] = _moduleAt(item));
            },
            childDelegate: ListWheelChildLoopingListDelegate(
              children: [
                for (final id in _modules)
                  _ModuleChip(
                    spec: AppShell._modules[id]!,
                    glass: widget.glass,
                    inLens: _centred[i] == id,
                    required: id == bottomNavRequiredId,
                    showLabel: showLabels,
                    // The wheels sit side by side: a slot's lens chip is
                    // as wide as its tab, the rest are discs.
                    width: widget.slots[i].width,
                    height: _itemExtent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, bool showLabels) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tr('Edit bottom bar'),
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('Scroll each tab to choose what goes there.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _EditorPill(
              icon: showLabels
                  ? Icons.text_fields_rounded
                  : Icons.text_fields_outlined,
              label: tr('Labels'),
              selected: showLabels,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(dbProvider).setShowBottomNavLabels(!showLabels);
              },
            ),
            _EditorPill(
              icon: Icons.restart_alt_rounded,
              label: tr('Reset'),
              onTap: listEquals(_layout, defaultBottomNavLayout)
                  ? null
                  : _reset,
            ),
            _EditorPill(
              key: const Key('navEditorDone'),
              icon: Icons.check_rounded,
              label: tr('Done'),
              filled: true,
              onTap: _done,
            ),
          ],
        ),
      ],
    );
  }
}

/// One module on a wheel: in the lens, its tab as it'll look on the bar;
/// above and below, a small disc to scroll past.
class _ModuleChip extends StatelessWidget {
  const _ModuleChip({
    required this.spec,
    required this.glass,
    required this.inLens,
    required this.required,
    required this.showLabel,
    required this.width,
    required this.height,
  });

  final _TabSpec spec;
  final bool glass;
  final bool inLens;
  final bool required;
  final bool showLabel;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = theme.brightness == Brightness.dark
        ? const Color(0xFF8CCBFF)
        : cs.secondary;
    final glyphs = glass ? _glassIcons[spec.branch] : null;
    final icon = inLens
        ? (glyphs?.$2 ?? spec.activeIcon)
        : (glyphs?.$1 ?? spec.icon);
    final color = inLens ? accent : Colors.white.withValues(alpha: 0.9);
    return Semantics(
      label: spec.label,
      selected: inLens,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          width: inLens ? width - 8 : 48,
          height: inLens ? height - 8 : 48,
          decoration: BoxDecoration(
            color: inLens
                ? Colors.white.withValues(alpha: 0)
                : Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: inLens ? 0 : 0.18),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: inLens ? 1.12 : 0.9,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: AppIcon(icon, size: 24, color: color),
                  ),
                  if (required && inLens)
                    Positioned(
                      right: -10,
                      top: -6,
                      child: AppIcon(
                        Icons.lock_rounded,
                        size: 11,
                        color: color.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
              if (showLabel && inLens) ...[
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      spec.label,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorPill extends StatelessWidget {
  const _EditorPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.filled = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final bg = filled
        ? cs.secondary
        : Colors.white.withValues(alpha: selected ? 0.26 : 0.12);
    final fg = Colors.white.withValues(alpha: enabled ? 1 : 0.4);
    return SpringBounce(
      pressedScale: 0.92,
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Why a move was refused: pops in, then fades on its own.
class _HintPill extends StatelessWidget {
  const _HintPill({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * v, child: child),
      ),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}
