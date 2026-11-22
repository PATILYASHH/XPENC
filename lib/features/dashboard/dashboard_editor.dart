import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../accounts/arrange_accounts_sheet.dart';
import 'dashboard_layout.dart';

/// How long a Dashboard widget is held before the Dashboard turns editable —
/// the same second as the bottom bar and the Add page's account strip.
const kDashboardHoldToEdit = Duration(seconds: 1);

/// The theme stretches buttons full width; these sit in rows.
final _rowButton = TextButton.styleFrom(minimumSize: const Size(0, 40));

/// Wraps one Dashboard widget so holding it for [kDashboardHoldToEdit] calls
/// [onHold]. It swells a touch as it charges, so the wait never feels stuck;
/// a tap, a scroll or a swipe inside it cancels and works as before.
class DashboardHold extends StatefulWidget {
  const DashboardHold({required this.onHold, required this.child, super.key});

  final VoidCallback onHold;
  final Widget child;

  @override
  State<DashboardHold> createState() => _DashboardHoldState();
}

class _DashboardHoldState extends State<DashboardHold>
    with SingleTickerProviderStateMixin {
  // In initState, never lazily — see `_AccountStripState._wiggle`.
  late final AnimationController _charge;

  @override
  void initState() {
    super.initState();
    _charge = AnimationController(vsync: this, duration: kDashboardHoldToEdit);
  }

  @override
  void dispose() {
    _charge.dispose();
    super.dispose();
  }

  void _cancel() => _charge.animateBack(
    0,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOutCubic,
  );

  void _fire() {
    widget.onHold();
    _charge.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(duration: kDashboardHoldToEdit),
              (r) => r
                ..onLongPressDown = ((_) => _charge.forward(from: 0))
                ..onLongPressCancel = _cancel
                ..onLongPress = _fire,
            ),
      },
      child: AnimatedBuilder(
        animation: _charge,
        child: widget.child,
        builder: (context, child) {
          // Nothing for the first fifth, so a tap never wobbles.
          final v = Curves.easeInCubic.transform(
            ((_charge.value - 0.2) / 0.8).clamp(0.0, 1.0),
          );
          return Transform.scale(scale: 1 + 0.025 * v, child: child);
        },
      ),
    );
  }
}

/// The Dashboard while it's being edited, in place: every widget on it as a
/// framed live preview that wiggles — drag one (or hold it and drag) to
/// move it, ✕ to take it off, ⚙ (or a tap) for its options — then
/// "Add widget" and Done floating above the bottom bar. Every change saves
/// as it's made; Done, or Back, finishes.
class DashboardEditView extends ConsumerStatefulWidget {
  const DashboardEditView({
    required this.sectionBuilder,
    required this.onDone,
    this.openAddOnStart = false,
    super.key,
  });

  /// The widget as the Dashboard draws it, for the preview.
  final Widget Function(DashboardWidget widget) sectionBuilder;
  final VoidCallback onDone;

  /// Opens the add-widget sheet straight away — for an empty dashboard,
  /// where there's nothing to hold.
  final bool openAddOnStart;

  @override
  ConsumerState<DashboardEditView> createState() => _DashboardEditViewState();
}

class _DashboardEditViewState extends ConsumerState<DashboardEditView>
    with SingleTickerProviderStateMixin {
  /// Held here as well as in the database, so a drag lands where it was
  /// dropped this frame rather than snapping back until the write echoes.
  late List<DashboardSlot> _slots = ref.read(dashboardLayoutProvider);
  late final AnimationController _wiggle;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!MediaQuery.disableAnimationsOf(context)) _wiggle.repeat();
      if (widget.openAddOnStart) _openAdd();
    });
  }

  @override
  void dispose() {
    _wiggle.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _apply(List<DashboardSlot> next) {
    setState(() => _slots = next);
    ref.read(dbProvider).setDashboardLayout(encodeDashboardLayout(next));
  }

  void _remove(DashboardWidget w) {
    HapticFeedback.selectionClick();
    _apply(setDashboardWidgetVisible(_slots, w, visible: false));
  }

  void _add(DashboardWidget w) {
    HapticFeedback.selectionClick();
    _apply(setDashboardWidgetVisible(_slots, w, visible: true));
    // It joins the bottom of what's shown: bring it into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _openAdd() async {
    final picked = await showAppSheet<DashboardWidget>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _AddWidgetSheet(
        hidden: [
          for (final s in _slots)
            if (!s.visible) s.widget,
        ],
      ),
    );
    if (picked != null && mounted) _add(picked);
  }

  void _openOptions(DashboardWidget w) =>
      showDashboardWidgetOptions(context, w, onRemove: () => _remove(w));

  @override
  Widget build(BuildContext context) {
    // A restore, or a change from Settings, can land underneath us.
    ref.listen(dashboardLayoutProvider, (_, next) {
      setState(() => _slots = next);
    });
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mode = ref.watch(appModeProvider);
    final rtaOn = ref.watch(rtaEnabledProvider);
    final options = ref.watch(dashboardOptionsProvider);
    final accountsStyle = ref.watch(dashboardAccountsStyleProvider);
    final shown = [
      for (final s in _slots)
        if (s.visible) s.widget,
    ];
    final anyHidden = _slots.any((s) => !s.visible);
    final isDefault =
        encodeDashboardLayout(_slots) ==
            encodeDashboardLayout(defaultDashboardLayout) &&
        options.isEmpty;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    String summaryOf(DashboardWidget w) {
      final note = w.unavailableNote(mode: mode, rtaOn: rtaOn);
      if (note != null) return note;
      final picked = [
        if (w == DashboardWidget.accounts)
          accountsStyle == DashboardAccountsStyle.slider
              ? tr('Slider')
              : tr('One card'),
        for (final o in w.options)
          if (options[w]?[o.key] != null)
            '${o.label}: ${o.labelOf(options[w]![o.key]!)}',
      ];
      return picked.isEmpty ? w.description : picked.join(' · ');
    }

    return PopScope(
      // Back finishes editing before it leaves the Dashboard.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onDone();
      },
      child: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.paddingOf(context).top + 8),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tr(
                              'Edit dashboard',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Tr(
                              'Drag to reorder · tap a widget for its options',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isDefault)
                        TextButton(
                          style: _rowButton,
                          onPressed: () async {
                            final ok = await _confirmReset(context);
                            if (!ok || !mounted) return;
                            _apply(defaultDashboardLayout);
                            await ref
                                .read(dbProvider)
                                .setDashboardWidgetOptions('');
                          },
                          child: const Tr('Reset'),
                        ),
                    ],
                  ),
                ),
              ),
              if (shown.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: Tr(
                      'Nothing on your dashboard — add a widget below.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                sliver: SliverReorderableList(
                  itemCount: shown.length,
                  onReorder: (from, to) {
                    HapticFeedback.selectionClick();
                    _apply(reorderDashboardWidgets(_slots, from, to));
                  },
                  onReorderStart: (_) => HapticFeedback.mediumImpact(),
                  proxyDecorator: (child, _, animation) => AnimatedBuilder(
                    animation: animation,
                    child: child,
                    builder: (context, child) {
                      final v = Curves.easeOut.transform(animation.value);
                      return Transform.scale(
                        scale: 1 + 0.03 * v,
                        child: Material(
                          type: MaterialType.transparency,
                          elevation: 12 * v,
                          shadowColor: Colors.black54,
                          borderRadius: BorderRadius.circular(22),
                          child: child,
                        ),
                      );
                    },
                  ),
                  itemBuilder: (context, i) {
                    final w = shown[i];
                    return Padding(
                      key: ValueKey(w),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ReorderableDelayedDragStartListener(
                        index: i,
                        child: AnimatedBuilder(
                          animation: _wiggle,
                          builder: (context, child) => Transform.rotate(
                            angle:
                                math.sin(
                                  (_wiggle.value + i * 0.37) * 2 * math.pi,
                                ) *
                                0.005,
                            child: child,
                          ),
                          child: _EditFrame(
                            widget: w,
                            index: i,
                            summary: summaryOf(w),
                            unavailable:
                                w.unavailableNote(mode: mode, rtaOn: rtaOn) !=
                                null,
                            preview: widget.sectionBuilder(w),
                            onOptions: () => _openOptions(w),
                            onRemove: () => _remove(w),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (anyHidden)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  sliver: SliverToBoxAdapter(child: _AddTile(onTap: _openAdd)),
                ),
              SliverToBoxAdapter(child: SizedBox(height: 96 + bottomInset)),
            ],
          ),
          // Always in reach, however long the dashboard is.
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + bottomInset,
            child: Align(
              heightFactor: 1,
              child: Material(
                elevation: 6,
                shadowColor: Colors.black38,
                color: cs.surfaceContainerHigh,
                shape: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (anyHidden) ...[
                        Flexible(
                          child: TextButton.icon(
                            key: const Key('dashboard-edit-add'),
                            // The theme stretches buttons full width.
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                            ),
                            onPressed: _openAdd,
                            icon: const AppIcon(Icons.add_rounded, size: 20),
                            label: const Tr(
                              'Add widget',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: FilledButton.icon(
                          key: const Key('dashboard-edit-done'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          onPressed: widget.onDone,
                          icon: const AppIcon(Icons.check_rounded, size: 20),
                          label: const Tr(
                            'Done',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
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

Future<bool> _confirmReset(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Tr('Reset the dashboard?'),
        content: const Tr(
          'Puts back the original widgets in their original order, each with '
          'its original options.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Tr('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Tr('Reset'),
          ),
        ],
      ),
    ) ??
    false;

/// One widget in edit mode: a toolbar (drag handle, name, what's picked,
/// ⚙ and ✕) over a live, untouchable preview, clipped and faded when tall.
class _EditFrame extends StatelessWidget {
  const _EditFrame({
    required this.widget,
    required this.index,
    required this.summary,
    required this.unavailable,
    required this.preview,
    required this.onOptions,
    required this.onRemove,
  });

  final DashboardWidget widget;
  final int index;
  final String summary;
  final bool unavailable;
  final Widget preview;
  final VoidCallback onOptions;
  final VoidCallback onRemove;

  static const _previewMaxHeight = 190.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final background = Color.alphaBlend(
      cs.secondary.withValues(alpha: 0.05),
      theme.cardTheme.color ?? cs.surface,
    );
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Semantics(
      key: ValueKey('dashboard-edit-${widget.name}'),
      container: true,
      label: widget.title,
      child: Material(
        color: background,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: cs.secondary.withValues(alpha: 0.35)),
        ),
        child: InkWell(
          onTap: onOptions,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 6, 4, 6),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: AppIcon(
                          Icons.drag_indicator_rounded,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.secondary.withValues(alpha: 0.12),
                      ),
                      child: AppIcon(
                        widget.icon,
                        size: 17,
                        color: cs.secondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: unavailable
                                  ? (theme.brightness == Brightness.dark
                                        ? Colors.amber
                                        : Colors.orange.shade800)
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: ValueKey('dashboard-options-${widget.name}'),
                      tooltip: tr('{0} options', [widget.title]),
                      onPressed: onOptions,
                      icon: AppIcon(Icons.tune_rounded, color: cs.secondary),
                    ),
                    IconButton(
                      key: ValueKey('dashboard-remove-${widget.name}'),
                      tooltip: tr('Remove {0}', [widget.title]),
                      onPressed: onRemove,
                      icon: AppIcon(
                        Icons.remove_circle_rounded,
                        color: AppColors.expense,
                      ),
                    ),
                  ],
                ),
              ),
              // The widget itself, a little smaller: drawn at the screen's
              // width then fitted to the frame, so it looks as it will.
              IgnorePointer(
                child: ExcludeSemantics(
                  child: _ClampedHeight(
                    maxHeight: _previewMaxHeight,
                    fade: background,
                    child: FittedBox(
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      child: SizedBox(width: screenWidth, child: preview),
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

/// Sizes to its child's height up to [maxHeight]; past that it clips, and
/// fades the last stretch into [fade] so it reads as "more below".
class _ClampedHeight extends SingleChildRenderObjectWidget {
  const _ClampedHeight({
    required this.maxHeight,
    required this.fade,
    super.child,
  });

  final double maxHeight;
  final Color fade;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderClampedHeight(maxHeight, fade);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderClampedHeight renderObject,
  ) {
    renderObject
      ..maxHeight = maxHeight
      ..fade = fade;
  }
}

class _RenderClampedHeight extends RenderProxyBox {
  _RenderClampedHeight(this._maxHeight, this._fade);

  double _maxHeight;
  set maxHeight(double v) {
    if (v == _maxHeight) return;
    _maxHeight = v;
    markNeedsLayout();
  }

  Color _fade;
  set fade(Color v) {
    if (v == _fade) return;
    _fade = v;
    markNeedsPaint();
  }

  bool _clipped = false;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(
      BoxConstraints(maxWidth: constraints.maxWidth),
      parentUsesSize: true,
    );
    final h = math.min(child.size.height, _maxHeight);
    _clipped = child.size.height > h + 0.5;
    size = constraints.constrain(Size(constraints.maxWidth, h));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    if (!_clipped) {
      super.paint(context, offset);
      return;
    }
    context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      super.paint,
    );
    const fadeHeight = 48.0;
    final rect = Rect.fromLTWH(
      offset.dx,
      offset.dy + size.height - fadeHeight,
      size.width,
      fadeHeight,
    );
    context.canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_fade.withValues(alpha: 0), _fade],
        ).createShader(rect),
    );
  }
}

/// A dashed-looking "＋ Add widget" slot at the foot of the list.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: cs.outline, width: 1.2),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(Icons.add_circle_outline_rounded, color: cs.secondary),
              const SizedBox(width: 8),
              Tr(
                'Add widget',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: cs.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every widget not on the dashboard; picking one pops with it.
class _AddWidgetSheet extends ConsumerWidget {
  const _AddWidgetSheet({required this.hidden});

  final List<DashboardWidget> hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mode = ref.watch(appModeProvider);
    final rtaOn = ref.watch(rtaEnabledProvider);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Tr(
              'Add a widget',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                for (final w in hidden)
                  () {
                    final note = w.unavailableNote(mode: mode, rtaOn: rtaOn);
                    return AppListTile(
                      key: ValueKey('dashboard-add-${w.name}'),
                      onTap: () => Navigator.pop(context, w),
                      leading: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.secondary.withValues(alpha: 0.12),
                        ),
                        child: AppIcon(w.icon, size: 20, color: cs.secondary),
                      ),
                      title: Text(w.title),
                      subtitle: Text(
                        note ?? w.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: note == null
                              ? cs.onSurfaceVariant
                              : (theme.brightness == Brightness.dark
                                    ? Colors.amber
                                    : Colors.orange.shade800),
                        ),
                      ),
                      trailing: AppIcon(
                        Icons.add_circle_rounded,
                        color: AppColors.income,
                      ),
                    );
                  }(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// [widget]'s options: each a row of two or three choices, applied the
/// moment one is picked (the Dashboard behind updates live). [onRemove],
/// when given, adds "Remove from dashboard".
Future<void> showDashboardWidgetOptions(
  BuildContext context,
  DashboardWidget widget, {
  VoidCallback? onRemove,
}) {
  HapticFeedback.selectionClick();
  return showAppSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) =>
        _OptionsSheet(widget: widget, onRemove: onRemove, host: context),
  );
}

class _OptionsSheet extends ConsumerStatefulWidget {
  const _OptionsSheet({
    required this.widget,
    required this.host,
    this.onRemove,
  });

  final DashboardWidget widget;
  final VoidCallback? onRemove;

  /// Where the sheet was opened from — what opens a sheet in its place.
  final BuildContext host;

  @override
  ConsumerState<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends ConsumerState<_OptionsSheet> {
  /// Held here so quick taps build on each other, not on a stale read.
  late DashboardOptions _options = ref.read(dashboardOptionsProvider);

  void _set(String key, String value) {
    HapticFeedback.selectionClick();
    setState(
      () => _options = setDashboardOption(_options, widget.widget, key, value),
    );
    ref
        .read(dbProvider)
        .setDashboardWidgetOptions(encodeDashboardOptions(_options));
  }

  void _resetMine() {
    var next = _options;
    for (final o in widget.widget.options) {
      next = setDashboardOption(next, widget.widget, o.key, o.defaultValue);
    }
    setState(() => _options = next);
    ref
        .read(dbProvider)
        .setDashboardWidgetOptions(encodeDashboardOptions(next));
  }

  Widget _row(String label, Widget control) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: double.infinity, child: control),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final w = widget.widget;
    final mine = _options[w] ?? const <String, String>{};
    final note = w.unavailableNote(
      mode: ref.watch(appModeProvider),
      rtaOn: ref.watch(rtaEnabledProvider),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.secondary.withValues(alpha: 0.12),
                ),
                child: IconWell(w.icon, size: 21, color: cs.secondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      note ?? w.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (w == DashboardWidget.accounts)
            _row(
              tr('Layout'),
              SegmentedButton<DashboardAccountsStyle>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: DashboardAccountsStyle.slider,
                    icon: AppIcon(Icons.view_carousel_outlined),
                    label: Tr('Slider'),
                  ),
                  ButtonSegment(
                    value: DashboardAccountsStyle.oneCard,
                    icon: AppIcon(Icons.view_agenda_outlined),
                    label: Tr('One card'),
                  ),
                ],
                selected: {ref.watch(dashboardAccountsStyleProvider)},
                onSelectionChanged: (s) {
                  HapticFeedback.selectionClick();
                  ref.read(dbProvider).setDashboardAccountsStyle(s.first);
                },
              ),
            ),
          for (final o in w.options)
            _row(
              o.label,
              SegmentedButton<String>(
                key: ValueKey('dashboard-option-${w.name}-${o.key}'),
                showSelectedIcon: false,
                segments: [
                  for (final c in o.choices)
                    ButtonSegment(
                      value: c.$1,
                      label: Text(
                        c.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                selected: {o.resolve(mine[o.key])},
                onSelectionChanged: (s) => _set(o.key, s.first),
              ),
            ),
          // Where a widget's contents are chosen elsewhere, a way there.
          if (w == DashboardWidget.accounts)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                // One sheet at a time: this one gives way to the other.
                onPressed: () {
                  Navigator.pop(context);
                  if (widget.host.mounted) {
                    showArrangeAccountsSheet(widget.host);
                  }
                },
                icon: const AppIcon(Icons.swap_vert_rounded, size: 18),
                label: const Tr('Arrange accounts'),
              ),
            ),
          if (w == DashboardWidget.shortcuts)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/more/settings/quick-actions');
                },
                icon: const AppIcon(Icons.apps_rounded, size: 18),
                label: const Tr('Choose shortcuts'),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (mine.isNotEmpty)
                Flexible(
                  child: TextButton.icon(
                    style: _rowButton,
                    onPressed: _resetMine,
                    icon: const AppIcon(Icons.restart_alt_rounded, size: 18),
                    label: const Tr(
                      'Default options',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              const Spacer(),
              if (widget.onRemove != null)
                TextButton.icon(
                  key: const Key('dashboard-options-remove'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    foregroundColor: AppColors.expense,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onRemove!();
                  },
                  icon: const AppIcon(Icons.remove_circle_outline, size: 18),
                  label: const Tr('Remove'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
