part of 'app_shell.dart';

// Edit the hold-➕ quick actions where they live. While the menu is open a
// ⚙ waits in the top corner; sliding up onto it and letting go keeps the
// bubbles exactly where they are, frosts the page, and lays every action
// out in a tray above them. Tap an action to add it or take it out; tap a
// bubble first to choose what that one opens (an action that's already in
// another bubble trades places with it, as on the bottom-bar editor).
// Reset and Done as there; Back cancels.

/// `_AddButtonState._hoveredIndex` while the thumb is on the ⚙.
const _holdMenuGearIndex = -2;

/// The ⚙ in the top corner while the hold menu is open, captioned "Edit".
/// Purely visual: the hold gesture on the ➕ decides when it's [hovered].
class _HoldMenuGear extends StatelessWidget {
  const _HoldMenuGear({
    required this.centre,
    required this.open,
    required this.hovered,
    required this.glass,
  });

  static const size = 52.0;

  final Offset centre;

  /// The menu's own 0–1 opening, so the ⚙ arrives with the bubbles.
  final double open;
  final bool hovered;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final glyphColor = hovered
        ? Colors.white
        : glass
        ? cs.secondary
        : cs.onSurface;
    final glyph = AnimatedRotation(
      turns: hovered ? 0.25 : 0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      child: AppIcon(Icons.settings_rounded, size: 24, color: glyphColor),
    );
    final Widget disc;
    if (glass) {
      final tone = AppSurface.of(context).tone;
      disc = LiquidGlass(
        backdrop: false,
        frost: tone.isDark ? const Color(0x47FFFFFF) : const Color(0xB3FFFFFF),
        tint: hovered ? cs.secondary : null,
        pressed: hovered,
        child: Center(child: glyph),
      );
    } else {
      disc = AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hovered ? cs.secondary : cs.surfaceContainerHighest,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: glyph),
      );
    }
    const width = 96.0;
    return Positioned(
      left: centre.dx - width / 2,
      top: centre.dy - size / 2,
      width: width,
      child: Opacity(
        opacity: open.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.6 + 0.4 * open,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                key: const ValueKey('holdMenuGear'),
                dimension: size,
                child: AnimatedScale(
                  scale: hovered ? 1.18 : 1,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  child: disc,
                ),
              ),
              const SizedBox(height: 6),
              // Gives way to the bigger "let go" label while it's hovered.
              AnimatedOpacity(
                opacity: hovered ? 0 : 1,
                duration: const Duration(milliseconds: 120),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    child: Text(
                      tr('Edit'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the editor over everything. [anchor] is the ➕'s centre — where
/// Glass's fan hangs from; the classic ring is centred on screen.
void _openQuickActionsEditor(
  BuildContext context, {
  required bool glass,
  required Offset anchor,
}) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 460),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, animation, _) => _QuickActionsEditor(
        animation: animation,
        glass: glass,
        anchor: anchor,
      ),
    ),
  );
}

class _QuickActionsEditor extends ConsumerStatefulWidget {
  const _QuickActionsEditor({
    required this.animation,
    required this.glass,
    required this.anchor,
  });

  final Animation<double> animation;
  final bool glass;
  final Offset anchor;

  @override
  ConsumerState<_QuickActionsEditor> createState() =>
      _QuickActionsEditorState();
}

class _QuickActionsEditorState extends ConsumerState<_QuickActionsEditor> {
  static const _bubble = 56.0;

  static final _defaults = parseHoldMenuSlots(defaultHoldMenuSlotsRaw);

  late final List<String> _initial;
  late List<String> _slots;

  /// The bubble (slot index) whose action the next tap in the tray sets.
  int? _selected;

  String? _hint;
  int _hintSerial = 0;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _initial = List.of(ref.read(holdMenuSlotsProvider));
    _slots = List.of(_initial);
  }

  void _tapBubble(int slot) {
    HapticFeedback.selectionClick();
    setState(() => _selected = _selected == slot ? null : slot);
  }

  /// A tap in the tray: with a bubble picked, that bubble now opens [id];
  /// otherwise [id] goes into the first free spot, or comes out if it's in.
  void _pick(String id, List<QuickActionSpec?> resolved) {
    final selected = _selected;
    if (selected != null) {
      HapticFeedback.selectionClick();
      setState(() {
        _slots = placeQuickAction(_slots, selected, id);
        _selected = null;
      });
      return;
    }
    final at = _slots.indexOf(id);
    if (at != -1) {
      HapticFeedback.selectionClick();
      setState(() => _slots = List.of(_slots)..[at] = '');
      return;
    }
    final free = resolved.indexOf(null);
    if (free == -1) {
      HapticFeedback.mediumImpact();
      _flashHint(tr('All 8 spots are taken. Tap a bubble to swap one out.'));
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _slots = placeQuickAction(_slots, free, id));
  }

  void _removeSelected() {
    final selected = _selected;
    if (selected == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _slots = List.of(_slots)..[selected] = '';
      _selected = null;
    });
  }

  void _reset() {
    HapticFeedback.selectionClick();
    setState(() {
      _slots = List.of(_defaults);
      _selected = null;
    });
  }

  void _flashHint(String text) {
    final serial = ++_hintSerial;
    setState(() => _hint = text);
    Future<void>.delayed(const Duration(milliseconds: 2600), () {
      if (mounted && serial == _hintSerial) setState(() => _hint = null);
    });
  }

  /// A tap on the frosted page: lets go of the picked bubble, or finishes.
  void _tapBackground() {
    if (_selected != null) {
      setState(() => _selected = null);
      return;
    }
    _done();
  }

  Future<void> _done() async {
    if (_closing) return;
    _closing = true;
    HapticFeedback.mediumImpact();
    if (!listEquals(_slots, _initial)) {
      try {
        await ref.read(dbProvider).setHoldMenuSlots(_slots);
      } on ArgumentError catch (e) {
        // Shouldn't happen — every tray id is a valid one — but a refused
        // save must not close the editor as if it had worked.
        _closing = false;
        if (mounted) _flashHint('${e.message}');
        return;
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final templates =
        ref.watch(transactionTemplatesProvider).valueOrNull ?? const [];
    final mode = ref.watch(appModeProvider);
    final india = ref.watch(indiaToolsProvider);
    final resolved = [
      for (final id in _slots)
        resolveQuickAction(
          id,
          templates: templates,
          mode: mode,
          indiaTools: india,
        ),
    ];

    // The tray: the settings picker's sections, templates after Add.
    final templateSpecs = [
      for (final t in templates)
        resolveQuickAction(
          '$quickActionTemplatePrefix${t.id}',
          templates: templates,
          mode: mode,
        ),
    ].whereType<QuickActionSpec>().toList();
    final byGroup = <String, List<QuickActionSpec>>{};
    for (final spec in quickActionCatalog) {
      if (spec.hiddenInBasic && mode == AppMode.basic) continue;
      if (spec.indiaOnly && !india) continue;
      (byGroup[spec.englishGroup] ??= []).add(spec);
    }
    final sections = <(String, List<QuickActionSpec>)>[];
    for (final e in byGroup.entries) {
      sections.add((tr(e.key), e.value));
      if (e.key == 'Add' && templateSpecs.isNotEmpty) {
        sections.add((tr('Templates'), templateSpecs));
      }
    }

    return PopScope(
      // Back cancels: nothing is saved.
      onPopInvokedWithResult: (_, _) => _closing = true,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: widget.animation,
          builder: (context, _) => _layout(context, resolved, sections),
        ),
      ),
    );
  }

  Widget _layout(
    BuildContext context,
    List<QuickActionSpec?> resolved,
    List<(String, List<QuickActionSpec>)> sections,
  ) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final v = widget.animation.value.clamp(0.0, 1.0);
    final status = widget.animation.status;
    final leaving = status == AnimationStatus.reverse;
    final moving = leaving || status == AnimationStatus.forward;
    final enter = Curves.easeOutCubic.transform(v);
    // Bubbles: there from the first frame (they were already on screen);
    // on the way out they fold back into the ➕.
    final presence = leaving ? Curves.easeIn.transform(v) : 1.0;
    // Header and tray come in a beat after the page frosts.
    final chrome = leaving
        ? v
        : Curves.easeOutCubic.transform(((v - 0.15) / 0.85).clamp(0.0, 1.0));

    // Where the bubbles sit, and how far down the tray may reach.
    final List<int> shown;
    final List<Offset> centres;
    final Offset hub;
    double trayBottom;
    if (widget.glass) {
      shown = glassEditableSlots([for (final s in resolved) s != null]);
      hub = widget.anchor;
      centres = [
        for (final c in glassFanCenters(hub, shown.length))
          leaving ? Offset.lerp(hub, c, presence)! : c,
      ];
      // Sized for a full fan, so the tray doesn't jump as bubbles come
      // and go.
      final full = glassFanCenters(hub, holdMenuSlotCount);
      trayBottom = full.map((c) => c.dy).reduce(math.min) - _bubble / 2 - 18;
    } else {
      shown = [for (var i = 0; i < holdMenuSlotCount; i++) i];
      final radius = (size.width * 0.32).clamp(104.0, 140.0);
      // The ring sinks toward the bottom to make room for the tray.
      final from = size.center(Offset.zero);
      final to = Offset(
        from.dx,
        math.max(from.dy, size.height - pad.bottom - 28 - radius - _bubble / 2),
      );
      hub = Offset.lerp(from, to, leaving ? 1 : enter)!;
      centres = [
        for (var i = 0; i < holdMenuSlotCount; i++)
          holdMenuOptionCenter(hub, holdMenuSlotAngles, radius, i),
      ];
      trayBottom = to.dy - radius - _bubble / 2 - 18;
    }
    final top = pad.top + 12;
    trayBottom = math.max(trayBottom, top + 180);
    final compact = trayBottom - top < 320;

    // The page under it: Glass's fan only glows and frosts it, the classic
    // ring dims it — the editor starts from that look and deepens it.
    final tone = AppSurface.of(context).tone;
    final fanDim = widget.glass ? 0.0 : 0.55;
    final fanBlur = widget.glass ? 8.0 : 0.0;
    const editDim = 0.62;
    const editBlur = 14.0;
    final dim = leaving ? editDim * v : ui.lerpDouble(fanDim, editDim, enter)!;
    final blur = leaving
        ? editBlur * v
        : ui.lerpDouble(fanBlur, editBlur, enter)!;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tapBackground,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: Colors.black.withValues(alpha: dim)),
                  if (widget.glass)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(
                            hub.dx / size.width * 2 - 1,
                            hub.dy / size.height * 2 - 1,
                          ),
                          radius: 0.9,
                          colors: [
                            cs.secondary.withValues(
                              alpha: (tone.isDark ? 0.28 : 0.22) * presence,
                            ),
                            cs.secondary.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: top,
          bottom: size.height - trayBottom,
          child: Opacity(
            opacity: chrome,
            child: Transform.translate(
              offset: Offset(0, -16 * (1 - chrome)),
              child: Column(
                children: [
                  _header(context, resolved, compact),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _QuickActionTray(
                      sections: sections,
                      inMenu: {
                        for (var i = 0; i < _slots.length; i++)
                          if (resolved[i] != null) _slots[i],
                      },
                      target: _selected == null ? null : _slots[_selected!],
                      onPick: (id) => _pick(id, resolved),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        for (var k = 0; k < shown.length; k++)
          AnimatedPositioned(
            key: ValueKey('quickSlot${shown[k]}'),
            // Bubbles glide when one comes or goes; during the open/close
            // they follow the animation exactly instead.
            duration: moving
                ? Duration.zero
                : const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            left: centres[k].dx - _bubble / 2,
            top: centres[k].dy - _bubble / 2,
            width: _bubble,
            height: _bubble,
            child: Opacity(
              opacity: presence,
              child: Transform.scale(
                scale: leaving ? 0.35 + 0.65 * presence : 1,
                child: _EditBubble(
                  key: ValueKey('quickBubble:${shown[k]}'),
                  spec: resolved[shown[k]],
                  selected: _selected == shown[k],
                  glass: widget.glass,
                  onTap: () => _tapBubble(shown[k]),
                ),
              ),
            ),
          ),
        _hubDisc(context, hub, enter, leaving ? v : 1.0),
        if (_hint != null)
          Positioned(
            left: 24,
            right: 24,
            top: trayBottom - 52,
            child: _HintPill(key: ValueKey(_hintSerial), text: _hint!),
          ),
        if (moving)
          // Keeps everything from being grabbed mid-flight.
          const Positioned.fill(child: AbsorbPointer()),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    List<QuickActionSpec?> resolved,
    bool compact,
  ) {
    final theme = Theme.of(context);
    final selected = _selected;
    final picked = selected == null ? null : resolved[selected];
    final String hint;
    if (selected != null) {
      hint = picked == null
          ? tr('Now tap what this spot should open.')
          : tr('{0} is picked. Tap what it should open instead.', [
              picked.label,
            ]);
    } else if (resolved.every((s) => s == null)) {
      hint = tr('Tap an action to add it. With none, holding ➕ opens Search.');
    } else {
      hint = tr('Tap an action to add or remove it. Tap a bubble to swap it.');
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tr('Edit quick actions'),
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Text(
              hint,
              key: ValueKey(hint),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (picked != null)
              _EditorPill(
                key: const Key('quickEditorRemove'),
                icon: Icons.remove_circle_outline_rounded,
                label: tr('Remove'),
                onTap: _removeSelected,
              ),
            _EditorPill(
              icon: Icons.restart_alt_rounded,
              label: tr('Reset'),
              onTap: listEquals(_slots, _defaults) ? null : _reset,
            ),
            _EditorPill(
              key: const Key('quickEditorDone'),
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

  /// The ✕ the thumb let go of becomes a ✓ — tapping it is Done.
  Widget _hubDisc(
    BuildContext context,
    Offset hub,
    double enter,
    double opacity,
  ) {
    final cs = Theme.of(context).colorScheme;
    final d = widget.glass ? _LiquidTabBar.height : _bubble;
    final cross = Transform.rotate(
      angle: math.pi / 4,
      child: AppIcon(
        widget.glass ? CupertinoIcons.add : Icons.add_rounded,
        color: widget.glass ? Colors.white : cs.onSurface,
        size: 28,
      ),
    );
    const check = AppIcon(Icons.check_rounded, color: Colors.white, size: 28);
    final glyphs = Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 1 - enter, child: cross),
        Opacity(
          opacity: enter,
          child: Transform.scale(scale: 0.6 + 0.4 * enter, child: check),
        ),
      ],
    );
    final Widget disc;
    if (widget.glass) {
      disc = LiquidGlass(
        backdrop: false,
        tint: Color.lerp(
          cs.secondary.withValues(alpha: 0.55),
          cs.secondary,
          enter,
        ),
        child: Center(child: glyphs),
      );
    } else {
      disc = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.lerp(cs.surfaceContainerHighest, cs.secondary, enter),
        ),
        child: Center(child: glyphs),
      );
    }
    return Positioned(
      left: hub.dx - d / 2,
      top: hub.dy - d / 2,
      width: d,
      height: d,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Semantics(
          button: true,
          label: tr('Done'),
          child: GestureDetector(
            key: const Key('quickEditorHub'),
            behavior: HitTestBehavior.opaque,
            onTap: _done,
            child: Transform.scale(
              scale: widget.glass ? 0.92 + 0.08 * enter : 1,
              child: disc,
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the menu's spots while editing: its action as the menu draws it,
/// or a "+" for a free spot. The picked one swells and fills with accent;
/// a new action landing in it pops.
class _EditBubble extends StatefulWidget {
  const _EditBubble({
    required this.spec,
    required this.selected,
    required this.glass,
    required this.onTap,
    super.key,
  });

  final QuickActionSpec? spec;
  final bool selected;
  final bool glass;
  final VoidCallback onTap;

  @override
  State<_EditBubble> createState() => _EditBubbleState();
}

class _EditBubbleState extends State<_EditBubble>
    with SingleTickerProviderStateMixin {
  // Starts settled: the bubbles were already on screen as the editor opened.
  late final _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: 1,
  );

  @override
  void didUpdateWidget(_EditBubble old) {
    super.didUpdateWidget(old);
    if (old.spec?.id != widget.spec?.id) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final spec = widget.spec;
    final selected = widget.selected;
    final glyphColor = selected
        ? Colors.white
        : spec == null
        ? Colors.white.withValues(alpha: 0.8)
        : widget.glass
        ? cs.secondary
        : cs.onSurface;
    final glyph = AppIcon(
      spec?.icon ?? Icons.add_rounded,
      size: 24,
      color: glyphColor,
    );
    final Widget disc;
    if (widget.glass) {
      final tone = AppSurface.of(context).tone;
      disc = LiquidGlass(
        backdrop: false,
        frost: spec == null
            ? const Color(0x24FFFFFF)
            : tone.isDark
            ? const Color(0x47FFFFFF)
            : const Color(0xB3FFFFFF),
        tint: selected ? cs.secondary : null,
        pressed: selected,
        child: Center(child: glyph),
      );
    } else {
      disc = AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? cs.secondary
              : spec == null
              ? Colors.transparent
              : cs.surfaceContainerHighest,
          border: spec == null && !selected
              ? Border.all(color: Colors.white.withValues(alpha: 0.55))
              : null,
          boxShadow: spec == null
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(child: glyph),
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: spec?.label ?? tr('Empty spot'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: selected ? 1.15 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: AnimatedBuilder(
            animation: _pop,
            child: disc,
            builder: (context, child) => Transform.scale(
              scale: 0.6 + 0.4 * Curves.easeOutBack.transform(_pop.value),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Every action the menu can hold, by section — the ones in it ticked, the
/// picked bubble's own one ringed.
class _QuickActionTray extends StatelessWidget {
  const _QuickActionTray({
    required this.sections,
    required this.inMenu,
    required this.target,
    required this.onPick,
  });

  final List<(String, List<QuickActionSpec>)> sections;
  final Set<String> inMenu;

  /// The picked bubble's action id, if a bubble is picked.
  final String? target;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inner = constraints.maxWidth - 16;
            final columns = math.max(3, (inner / 76).floor());
            final tileWidth = inner / columns;
            return ListView(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              children: [
                for (final (title, specs) in sections) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                    child: Text(
                      title.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  Wrap(
                    children: [
                      for (final spec in specs)
                        SizedBox(
                          width: tileWidth,
                          child: _TrayTile(
                            spec: spec,
                            inMenu: inMenu.contains(spec.id),
                            isTarget: spec.id == target,
                            onTap: () => onPick(spec.id),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TrayTile extends StatelessWidget {
  const _TrayTile({
    required this.spec,
    required this.inMenu,
    required this.isTarget,
    required this.onTap,
  });

  final QuickActionSpec spec;
  final bool inMenu;
  final bool isTarget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      button: true,
      selected: inMenu,
      child: InkWell(
        key: ValueKey('quickTray:${spec.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: inMenu
                          ? cs.secondary
                          : Colors.white.withValues(alpha: 0.12),
                      border: isTarget
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: AppIcon(spec.icon, size: 22, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    right: -3,
                    top: -3,
                    child: AnimatedScale(
                      scale: inMenu ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: AppIcon(
                          Icons.check_rounded,
                          size: 13,
                          color: cs.secondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                spec.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 10.5,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
