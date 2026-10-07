part of 'app_shell.dart';

// The Glass theme's shell chrome: the floating top bar whose large title
// flies into it, and the floating tab bar that can grow into the month
// picker. Everything here runs only under Glass; the classic bars live in
// app_shell.dart.

/// The visible tab's scroll offset, for the collapsing title. One shell, one
/// notifier; per-tab offsets are kept so switching tabs restores each tab's
/// own title state.
final _glassScroll = ValueNotifier<double>(0);
final _glassBranchScroll = <int, double>{};
int? _glassBranch;

/// Whether the tab bar is open as the month picker (Dashboard's month
/// button opens it; a pick, a tap outside, or Back closes it).
final _glassMonthPicker = ValueNotifier<bool>(false);

/// The top bar's capsule, which the pages its buttons open grow out of.
final _glassTopCapsule = GlobalKey(debugLabel: 'glassTopCapsule');

/// Opens [location] from a top-bar button: under Glass the capsule grows
/// down into the page ([pushFromTopBar]); elsewhere a plain push.
void _pushFromTop(BuildContext context, String location) {
  final capsule = _glassTopCapsule.currentContext;
  if (capsule != null && capsule.mounted) {
    pushFromTopBar<void>(capsule, location);
  } else {
    context.push(location);
  }
}

/// Marks the actions inside the top capsule, which draw flat — the capsule
/// is the glass; a disc per button inside it would be glass on glass.
class _GlassCapsuleScope extends InheritedWidget {
  const _GlassCapsuleScope({required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassCapsuleScope>() != null;

  @override
  bool updateShouldNotify(_GlassCapsuleScope old) => false;
}

/// A damped spring, integrated per frame: the glass's "liquid" lag. A little
/// under critical damping, so it settles with one soft overshoot.
class _Spring {
  _Spring(this.value);

  double value;
  double velocity = 0;

  static const double _stiffness = 380;
  static final double _damping = 2 * math.sqrt(_stiffness) * 0.62;

  /// Advances toward [target]; true once it has come to rest there.
  bool step(double target, double dt) {
    final accel = _stiffness * (target - value) - _damping * velocity;
    velocity += accel * dt;
    value += velocity * dt;
    if ((target - value).abs() < 0.0005 && velocity.abs() < 0.002) {
      value = target;
      velocity = 0;
      return true;
    }
    return false;
  }
}

/// Glass's top bar. The tab's actions float in a Liquid Glass capsule, the
/// large title sits below, and the tab scrolls under both to the top of the
/// screen. Scrolling carries the title *into* the bar: one title, riding up
/// with the content while it shrinks from 34 to 18 pt, landing inside the
/// capsule and staying there. The capsule follows on a spring — stretching
/// across a beat behind the title, as though the title pulled the glass
/// with it, and squashing a touch with its own speed — so it moves like
/// liquid rather than a panel on rails. Pulling down past the top swells
/// the large title a little.
///
/// Searching Transactions turns the capsule into the search field: the
/// capsule stretches to the full bar on the same spring and the field takes
/// the title's place inside it.
class _GlassTopBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const _GlassTopBar({required this.currentIndex});

  final int currentIndex;

  static const double _bar = 64;
  static const double _capsule = 52;
  static const double _largeSize = 34;
  static const double _smallSize = 18;
  static const double _lineHeight = 1.15;

  @override
  Size get preferredSize => const Size.fromHeight(_bar + glassLargeTitleExtent);

  @override
  ConsumerState<_GlassTopBar> createState() => _GlassTopBarState();
}

class _GlassTopBarState extends ConsumerState<_GlassTopBar>
    with SingleTickerProviderStateMixin {
  // Made in initState, not lazily: a lazy ticker first touched in
  // dispose() looks up TickerMode on a deactivated element.
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  late final _Spring _liquid = _Spring(_targetFor(_glassScroll.value));

  static double _targetFor(double offset) =>
      (offset / glassLargeTitleExtent).clamp(0.0, 1.0);

  /// Whether the capsule is the search field (Transactions, searching).
  bool _searching = false;

  /// Where the capsule's width is heading: the full bar while searching.
  double get _target => _searching ? 1 : _targetFor(_glassScroll.value);

  /// The title's progress into the capsule. It tracks the finger exactly —
  /// except across a tab switch, when it glides on a spring from where the
  /// old tab had it to where the new tab has it, instead of jumping.
  late final _Spring _title = _Spring(_targetFor(_glassScroll.value));
  bool _switching = false;

  double get _titleProgress =>
      _switching ? _title.value : _targetFor(_glassScroll.value);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _glassScroll.addListener(_onScroll);
    GlassBarMorph.top.progress.addListener(_onHandover);
  }

  @override
  void didUpdateWidget(_GlassTopBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      // The new tab's offset lands just after this frame (see AppShell);
      // the title starts from where it is now.
      _title
        ..value = _titleProgress
        ..velocity = 0;
      _switching = true;
      _wake();
    }
  }

  void _onScroll() {
    if (!mounted) return;
    setState(() {});
    _wake();
  }

  void _onHandover() {
    if (mounted) setState(() {});
  }

  void _wake() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 30);
    _last = elapsed;
    var settled = _liquid.step(_target, dt);
    if (_switching) {
      if (_title.step(_targetFor(_glassScroll.value), dt)) {
        _switching = false;
      } else {
        settled = false;
      }
    }
    setState(() {});
    if (settled) _ticker.stop();
  }

  @override
  void dispose() {
    _glassScroll.removeListener(_onScroll);
    GlassBarMorph.top.progress.removeListener(_onHandover);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tone = AppSurface.of(context).tone;
    final top = MediaQuery.paddingOf(context).top;
    final index = widget.currentIndex;
    final title = _TopBar._titles[index];
    final classic = _TopBar(currentIndex: index);
    final searching = index == 1 && ref.watch(txSearchActiveProvider);
    if (searching != _searching) {
      _searching = searching;
      // The capsule's spring heads for its new width from the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    }
    // A tab switch resizes the capsule to the new tab's buttons on the bar's
    // spring, the old buttons dissolving inside it as it goes and the new
    // ones swelling in — rather than the capsule jumping to its new width.
    Widget swap(Widget child) => AnimatedSize(
      duration: const Duration(milliseconds: 560),
      curve: const GlassBarSpring(),
      alignment: Alignment.centerRight,
      clipBehavior: Clip.none,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
            child: child,
          ),
        ),
        // Only the new buttons size the capsule; the old ones fade out over
        // it, pinned to its right end.
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerRight,
          clipBehavior: Clip.none,
          children: [
            for (final old in previous)
              Positioned(top: 0, bottom: 0, right: 0, child: old),
            ?current,
          ],
        ),
        child: child,
      ),
    );
    // The button at the capsule's end — the Inbox most tabs share, Settled
    // on Persons — stays put across a switch to a tab that has it too; only
    // what changes dissolves. The search field gets the inbox's room while
    // it's up.
    final trailing = index == 2
        ? _TonalIconButton(
            key: const ValueKey('settled'),
            tooltip: 'Settled',
            icon: const AppIcon(Icons.task_alt_rounded),
            onPressed: () => _pushFromTop(context, '/persons/settled'),
          )
        : searching
        ? const SizedBox.shrink(key: ValueKey('none'))
        : _TonalIconButton(
            key: const ValueKey('inbox'),
            tooltip: 'Review Inbox',
            icon: const AppIcon(Icons.inbox_outlined),
            onPressed: () => _pushFromTop(context, '/inbox'),
          );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swap(
          Row(
            key: ValueKey(index),
            mainAxisSize: MainAxisSize.min,
            children: classic._tabActions(context, ref, index),
          ),
        ),
        swap(trailing),
      ],
    );

    const bar = _GlassTopBar._bar;
    const capsule = _GlassTopBar._capsule;
    final offset = _glassScroll.value;
    final pull = offset < 0 ? -offset : 0.0;
    // The title's own progress tracks the finger exactly; the capsule's
    // ([_liquid]) chases it on a spring.
    final c = Curves.easeInOutCubic.transform(_titleProgress.clamp(0.0, 1.0));
    final liquid = _liquid.value;
    final squash = (_liquid.velocity.abs() * 0.03).clamp(0.0, 0.06);
    // A page growing out of the capsule takes its glass over.
    final handover = GlassBarMorph.top.progress.value;
    final ownGlass = handover == null
        ? 1.0
        : 1 -
              Curves.easeIn.transform(
                (handover.clamp(0.0, 1.0) / 0.3).clamp(0.0, 1.0),
              );

    // Where the one title sits: under the bar at rest, inside the capsule
    // when collapsed.
    const lineLarge = _GlassTopBar._largeSize * _GlassTopBar._lineHeight;
    const shrink = _GlassTopBar._smallSize / _GlassTopBar._largeSize;
    final restTop = top + bar + (glassLargeTitleExtent - lineLarge) + pull;
    final landTop =
        top + (bar - capsule) / 2 + capsule / 2 - lineLarge * shrink / 2;
    final titleTop = restTop + (landTop - restTop) * c;
    final titleLeft = 20 + (12 + 5 + 12 - 20) * c;
    final titleScale =
        (1 + (shrink - 1) * c) * (1 + (pull / 600).clamp(0.0, 0.08));

    final veil = tone.isDark
        ? const Color(0xFF000000)
        : const Color(0xFFF4F5FA);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: tone.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The scroll edge: content softens into the top of the screen
          // once there's content under the bar to soften.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + bar + 18,
            child: IgnorePointer(
              child: Opacity(
                opacity: c,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        veil.withValues(alpha: 0.82),
                        veil.withValues(alpha: 0.45),
                        veil.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The capsule: the actions at rest; the whole bar once the title
          // has landed. Width follows the spring; speed squashes it.
          Positioned(
            top: top + (bar - capsule) / 2,
            left: 12,
            right: 12,
            height: capsule,
            child: LayoutBuilder(
              builder: (context, box) => Align(
                alignment: Alignment.centerRight,
                child: Opacity(
                  opacity: ownGlass,
                  child: Transform(
                    alignment: Alignment.centerRight,
                    transform: Matrix4.diagonal3Values(
                      1 + squash * 0.35,
                      1 - squash,
                      1,
                    ),
                    child: LiquidGlass(
                      key: _glassTopCapsule,
                      child: _GlassCapsuleScope(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: SizedBox(
                                  width: box.maxWidth * liquid.clamp(0.0, 1.0),
                                  // Laid out at full width and uncovered as
                                  // the capsule stretches, so it never
                                  // reflows mid-spring.
                                  child: searching
                                      ? ClipRect(
                                          child: OverflowBox(
                                            alignment: Alignment.centerLeft,
                                            minWidth: 0,
                                            maxWidth: box.maxWidth,
                                            child: const _GlassTxSearch(),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              actions,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The one title, on top: riding the content, then flying into
          // the capsule and staying there.
          Positioned(
            left: titleLeft,
            top: titleTop,
            child: IgnorePointer(
              child: AnimatedOpacity(
                // The search field takes the title's place.
                opacity: searching ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                child: Transform.scale(
                  scale: titleScale,
                  alignment: Alignment.topLeft,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.18),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    // Both titles from the same left edge: the default
                    // centres the shorter one on the longer while they
                    // cross-fade, then it jumps left.
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topLeft,
                      clipBehavior: Clip.none,
                      children: [...previous, ?current],
                    ),
                    child: Text(
                      title,
                      key: ValueKey(index),
                      maxLines: 1,
                      softWrap: false,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontSize: _GlassTopBar._largeSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2 + 0.8 * c,
                        height: _GlassTopBar._lineHeight,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Transactions search, inside the top capsule: its own controller,
/// seeded from (and writing to) the shared query, so leaving the tab and
/// coming back finds the search as it was.
class _GlassTxSearch extends ConsumerStatefulWidget {
  const _GlassTxSearch();

  @override
  ConsumerState<_GlassTxSearch> createState() => _GlassTxSearchState();
}

class _GlassTxSearchState extends ConsumerState<_GlassTxSearch> {
  late final _controller = TextEditingController(
    text: ref.read(txSearchQueryProvider),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fades in as the capsule stretches to take it.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(12 * (1 - v), 0),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: GlassSearchField(
          controller: _controller,
          hint: 'Search transactions',
          onChanged: (v) => ref.read(txSearchQueryProvider.notifier).state = v,
        ),
      ),
    );
  }
}

/// Glass's tab bar, after iOS: a floating Liquid Glass capsule of tabs with
/// a droplet that slides to the selected one, and the ➕ as its own disc.
///
/// The bar can also *become* the month picker: on a spring it grows up
/// into a card — the tab icons dissolving as "‹ year ›" and the month grid
/// form in their place, the ➕ sliding away — and folds back into the bar
/// when a month is picked. Every sheet opened from the shell grows out of it
/// the same way ([GlassSheetRoute]): while one is up the bar hands its glass
/// over to the sheet ([GlassBarMorph]), dissolving its tabs and sliding the
/// ➕ away in step with the sheet's spring.
///
/// The ➕'s blue lights the near end of the capsule, the way a bright object
/// beside glass colours it.
class _LiquidTabBar extends StatefulWidget {
  const _LiquidTabBar({
    required this.tabs,
    required this.currentBranch,
    required this.showLabels,
    required this.onSelect,
    required this.add,
  });

  static const double height = kGlassBarHeight;
  static const double _panel = 286;

  final List<_TabSpec> tabs;
  final int currentBranch;
  final bool showLabels;
  final ValueChanged<int> onSelect;
  final Widget add;

  @override
  State<_LiquidTabBar> createState() => _LiquidTabBarState();
}

class _LiquidTabBarState extends State<_LiquidTabBar>
    with SingleTickerProviderStateMixin {
  // Unbounded: the spring may carry it a hair past 0 or 1.
  late final _morph = AnimationController.unbounded(
    vsync: this,
    value: _glassMonthPicker.value ? 1 : 0,
  );

  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 240,
    ratio: 0.78,
  );

  @override
  void initState() {
    super.initState();
    _glassMonthPicker.addListener(_toggle);
  }

  void _toggle() {
    _morph.animateWith(
      SpringSimulation(
        _spring,
        _morph.value,
        _glassMonthPicker.value ? 1 : 0,
        _morph.velocity,
      ),
    );
  }

  @override
  void didUpdateWidget(_LiquidTabBar old) {
    super.didUpdateWidget(old);
    // Switching tabs puts the bar back — after this frame, since this runs
    // mid-build and the notifier has listeners of its own to rebuild.
    if (old.currentBranch != widget.currentBranch && _glassMonthPicker.value) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _glassMonthPicker.value = false,
      );
    }
  }

  @override
  void dispose() {
    _glassMonthPicker.removeListener(_toggle);
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.tabs.indexWhere(
      (t) => t.branch == widget.currentBranch,
    );
    final accent = Theme.of(context).colorScheme.secondary;
    return RepaintBoundary(
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kGlassBarSide),
          child: AnimatedBuilder(
            animation: Listenable.merge([_morph, GlassBarMorph.progress]),
            builder: (context, _) {
              final t = _morph.value;
              final open = t.clamp(0.0, 1.0);
              // A sheet grown out of the bar: the bar's glass hands over to
              // the sheet's (fading out as that fades in), and the tabs and
              // the ➕ clear away.
              final sheet = GlassBarMorph.progress.value;
              final handedOver = sheet != null;
              final sheetOpen = (sheet ?? 0).clamp(0.0, 1.0);
              final away = math.max(open, sheetOpen);
              final ownGlass = handedOver
                  ? 1 - Curves.easeIn.transform((sheetOpen / 0.3).clamp(0, 1))
                  : 1.0;
              final height =
                  _LiquidTabBar.height +
                  (_LiquidTabBar._panel - _LiquidTabBar.height) * t;
              final tabsOut = Curves.easeOut.transform(
                (away * 1.8).clamp(0.0, 1.0),
              );
              final panelIn = Curves.easeOut.transform(
                ((open - 0.3) / 0.7).clamp(0.0, 1.0),
              );
              final body = Stack(
                children: [
                  // The ➕'s light on the capsule's near end.
                  if (away < 1)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(1.05, 0.15),
                              radius: 2.2,
                              colors: [
                                accent.withValues(alpha: 0.3 * (1 - away)),
                                accent.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (tabsOut < 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: _LiquidTabBar.height,
                      child: Opacity(
                        opacity: 1 - tabsOut,
                        child: Transform.scale(
                          scale: 1 - 0.18 * tabsOut,
                          child: _tabs(context, selected),
                        ),
                      ),
                    ),
                  if (panelIn > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: _LiquidTabBar._panel,
                      child: Opacity(
                        opacity: panelIn,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - panelIn)),
                          child: const _GlassMonthPanel(),
                        ),
                      ),
                    ),
                ],
              );
              const addExtent = _LiquidTabBar.height + kGlassAddGap;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: height,
                      child: ownGlass <= 0
                          ? body
                          : Opacity(
                              opacity: ownGlass,
                              child: LiquidGlass(
                                borderRadius: BorderRadius.circular(
                                  32 - 4 * open,
                                ),
                                child: body,
                              ),
                            ),
                    ),
                  ),
                  // The ➕ slides away while the bar is the picker or a sheet.
                  ClipRect(
                    child: SizedBox(
                      width: addExtent * (1 - away),
                      height: _LiquidTabBar.height,
                      child: away >= 1
                          ? null
                          : OverflowBox(
                              alignment: Alignment.centerRight,
                              minWidth: addExtent,
                              maxWidth: addExtent,
                              child: Opacity(
                                opacity: 1 - away,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: kGlassAddGap,
                                  ),
                                  child: widget.add,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _tabs(BuildContext context, int selected) {
    return LayoutBuilder(
      builder: (context, box) {
        final itemWidth = box.maxWidth / widget.tabs.length;
        return Stack(
          children: [
            if (selected >= 0)
              _LiquidDroplet(
                index: selected,
                itemWidth: itemWidth,
                color: AppSurface.of(context).tone.selected,
              ),
            Row(
              children: [
                for (var i = 0; i < widget.tabs.length; i++)
                  Expanded(
                    child: _LiquidTab(
                      tab: widget.tabs[i],
                      selected: i == selected,
                      showLabel: widget.showLabels,
                      onTap: () => widget.onSelect(widget.tabs[i].branch),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The month picker the tab bar grows into: "‹ year ›" over a 4×3 grid of
/// months, and a way back to this month.
class _GlassMonthPanel extends ConsumerStatefulWidget {
  const _GlassMonthPanel();

  @override
  ConsumerState<_GlassMonthPanel> createState() => _GlassMonthPanelState();
}

class _GlassMonthPanelState extends ConsumerState<_GlassMonthPanel> {
  late int _year = ref.read(selectedMonthProvider).year;

  void _pick(DateTime month) {
    HapticFeedback.selectionClick();
    ref.read(selectedMonthProvider.notifier).state = month;
    _glassMonthPicker.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selected = ref.watch(selectedMonthProvider);
    final startDay = ref.watch(budgetStartDayProvider);
    final current = budgetPeriodAnchorFor(DateTime.now(), startDay);
    final canGoForward = _year < current.year;

    Widget chevron(IconData icon, String tip, VoidCallback? onTap) =>
        IconButton(
          tooltip: tip,
          onPressed: onTap,
          icon: AppIcon(icon, size: 22),
          style: IconButton.styleFrom(foregroundColor: cs.onSurface),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              chevron(
                Icons.chevron_left_rounded,
                'Previous year',
                () => setState(() => _year--),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.85, end: 1).animate(a),
                      child: child,
                    ),
                  ),
                  child: Text(
                    '$_year',
                    key: ValueKey(_year),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              chevron(
                Icons.chevron_right_rounded,
                'Next year',
                canGoForward ? () => setState(() => _year++) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var row = 0; row < 3; row++) ...[
            if (row > 0) const SizedBox(height: 8),
            Row(
              children: [
                for (var col = 0; col < 4; col++) ...[
                  if (col > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _monthCell(
                      context,
                      DateTime(_year, row * 4 + col + 1),
                      selected: selected,
                      current: current,
                    ),
                  ),
                ],
              ],
            ),
          ],
          const Spacer(),
          SizedBox(
            height: 40,
            width: double.infinity,
            child: TextButton.icon(
              onPressed: selected == current ? null : () => _pick(current),
              icon: const AppIcon(Icons.today_rounded, size: 18),
              label: const Text('This month'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthCell(
    BuildContext context,
    DateTime month, {
    required DateTime selected,
    required DateTime current,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tone = AppSurface.of(context).tone;
    final isSelected = month == selected;
    final isCurrent = month == current;
    final disabled = month.isAfter(current);
    return SizedBox(
      height: 42,
      child: Material(
        color: isSelected ? cs.secondary : tone.fill,
        shape: StadiumBorder(
          side: isCurrent && !isSelected
              ? BorderSide(color: cs.secondary, width: 1.4)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: disabled ? null : () => _pick(month),
          child: Center(
            child: Text(
              DateFormat('MMM').format(month),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : disabled
                    ? cs.onSurface.withValues(alpha: 0.3)
                    : cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// While the tab bar is the month picker: a dim over the page that folds it
/// back on a tap anywhere, and Back folds it too.
class _GlassMonthScrim extends StatelessWidget {
  const _GlassMonthScrim();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _glassMonthPicker,
      builder: (context, open, _) => PopScope(
        canPop: !open,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _glassMonthPicker.value = false;
        },
        child: IgnorePointer(
          ignoring: !open,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _glassMonthPicker.value = false,
            child: AnimatedOpacity(
              opacity: open ? 1 : 0,
              duration: const Duration(milliseconds: 240),
              child: const ColoredBox(
                color: Color(0x59000000),
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
