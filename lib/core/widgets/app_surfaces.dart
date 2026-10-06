import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../theme/glass.dart';
import 'nav_bar_inset.dart';

/// The app's card. Outside Glass it *is* a [Card] — same arguments, same
/// result. Under Glass it becomes a frosted [GlassPane] that blurs the
/// wallpaper behind it.
///
/// Use this instead of [Card] everywhere in `lib/`, or that card stays an
/// opaque slab when Glass is on.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    this.child,
    this.margin,
    this.clipBehavior,
    this.shape,
    this.color,
  });

  final Widget? child;
  final EdgeInsetsGeometry? margin;
  final Clip? clipBehavior;
  final ShapeBorder? shape;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!AppSurface.of(context).isGlass) {
      return Card(
        margin: margin,
        clipBehavior: clipBehavior,
        shape: shape,
        color: color,
        child: child,
      );
    }

    final cardTheme = Theme.of(context).cardTheme;
    final resolved = shape ?? cardTheme.shape;
    final radius = resolved is RoundedRectangleBorder
        ? resolved.borderRadius.resolve(Directionality.of(context))
        : BorderRadius.circular(26);

    return Semantics(
      container: true,
      child: Padding(
        padding: margin ?? cardTheme.margin ?? EdgeInsets.zero,
        child: GlassPane(
          borderRadius: radius,
          tint: color,
          // A transparent Material so ink splashes from the card's
          // InkWells/ListTiles still have somewhere to draw, as on a Card.
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

/// [Icon], with the same arguments. Under Glass, the chrome glyphs swap for
/// their SF-Symbols-style Cupertino counterparts (see [_glassGlyphs]);
/// anything without one — category icons included — stays as given.
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size, this.color});

  final IconData? icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final glyph = icon == null || !AppSurface.of(context).isGlass
        ? null
        : _glassGlyphs[icon];
    if (glyph == null) return Icon(icon, size: size, color: color);
    final (data, scale) = glyph;
    final base = size ?? IconTheme.of(context).size ?? 24;
    // A disclosure chevron is a quiet grey on iOS, never the tint colour —
    // unless the call site asked for a colour of its own.
    final quiet = data == CupertinoIcons.chevron_forward && color == null;
    return Icon(
      data,
      size: base * scale,
      color: quiet ? AppSurface.of(context).tone.quiet : color,
    );
  }
}

/// [ListTile], with the same arguments. Under Glass a leading [AppIcon]
/// sits on a glossy [GlassIconTile], iOS Settings–style; everything else
/// (and every other theme) is a plain ListTile.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.contentPadding,
    this.selected = false,
    this.shape,
    this.dense,
    this.isThreeLine = false,
    this.enabled = true,
  });

  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final EdgeInsetsGeometry? contentPadding;
  final bool selected;
  final ShapeBorder? shape;
  final bool? dense;
  final bool isThreeLine;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: glassLeadingTile(context, leading),
    title: title,
    subtitle: subtitle,
    trailing: trailing,
    onTap: onTap,
    onLongPress: onLongPress,
    contentPadding: contentPadding,
    selected: selected,
    shape: shape,
    dense: dense,
    isThreeLine: isThreeLine,
    enabled: enabled,
  );
}

/// [SwitchListTile], with the same arguments; its [secondary] gets the same
/// Glass tile as [AppListTile]'s leading icon.
class AppSwitchListTile extends StatelessWidget {
  const AppSwitchListTile({
    required this.value,
    required this.onChanged,
    super.key,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    value: value,
    onChanged: onChanged,
    title: title,
    subtitle: subtitle,
    secondary: glassLeadingTile(context, secondary),
    contentPadding: contentPadding,
  );
}

/// Under Glass, a row's leading [AppIcon] on a glossy tile: its own colour
/// when it has a real one, else a stable colour from iOS's system palette
/// (a grey "muted" icon colour would make a column of grey tiles).
Widget? glassLeadingTile(BuildContext context, Widget? leading) {
  if (leading is! AppIcon || !AppSurface.of(context).isGlass) return leading;
  final own = leading.color;
  final vivid = own != null && HSLColor.fromColor(own).saturation > 0.25;
  return GlassIconTile(
    color: vivid ? own : GlassIconTile.forIcon(leading.icon),
    extent: 30,
    child: AppIcon(leading.icon, size: 17, color: Colors.white),
  );
}

/// [AppBar], with the same arguments. Under Glass the actions are gathered
/// into one floating glass capsule (iOS groups toolbar buttons the same
/// way); elsewhere they lay out exactly as on a plain AppBar.
class AppTopBar extends AppBar {
  AppTopBar({
    super.key,
    super.leading,
    super.automaticallyImplyLeading,
    super.title,
    List<Widget>? actions,
    super.bottom,
    super.backgroundColor,
    super.iconTheme,
  }) : super(
         actions: actions == null || actions.isEmpty
             ? actions
             : [GlassActionGroup(children: actions)],
       );
}

/// A row of top-bar actions — one glass capsule under Glass, a plain row
/// otherwise.
class GlassActionGroup extends StatelessWidget {
  const GlassActionGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final row = Row(mainAxisSize: MainAxisSize.min, children: children);
    if (!AppSurface.of(context).isGlass) return row;
    return Padding(
      padding: const EdgeInsets.only(right: 12, left: 4),
      child: Center(
        child: SizedBox(
          height: 42,
          child: LiquidGlass(
            // Top bars sit on the still wallpaper; no backdrop pass needed.
            backdrop: false,
            child: IconButtonTheme(
              data: IconButtonThemeData(
                style: IconButton.styleFrom(
                  iconSize: 21,
                  minimumSize: const Size(40, 40),
                  padding: const EdgeInsets.all(8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: row,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [showModalBottomSheet], with the same arguments. Under Glass the sheet is
/// a floating pane of Liquid Glass inset from the screen edges, as on iOS.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool? showDragHandle,
  bool useRootNavigator = false,
  ShapeBorder? shape,
  bool useSafeArea = false,
}) {
  if (!AppSurface.of(context).isGlass) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      useRootNavigator: useRootNavigator,
      shape: shape,
      useSafeArea: useSafeArea,
    );
  }
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final localizations = MaterialLocalizations.of(context);
  return navigator.push(
    ModalBottomSheetRoute<T>(
      builder: (context) => _FloatingSheet(
        showHandle: showDragHandle ?? false,
        child: builder(context),
      ),
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      isScrollControlled: isScrollControlled,
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.none,
      shape: const RoundedRectangleBorder(),
      modalBarrierColor: AppSurface.of(context).tone.barrier,
      // The pane draws its own handle inside the glass.
      showDragHandle: false,
      useSafeArea: useSafeArea,
      // A longer, softer rise than Material's — easier on the eye — and a
      // quicker drop away.
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 380),
        reverseDuration: Duration(milliseconds: 240),
      ),
    ),
  );
}

/// A sheet's glass body: inset from the sides and the home indicator, with
/// iOS's grabber at the top when asked for.
///
/// It opens as the tab bar transforming: the sheet rises with exactly the
/// tab capsule's width and round ends, then widens into the full sheet as
/// the frost thickens and the content fades in — and folds back the same way
/// on close. The content is laid out once at full width and only its visible
/// window animates, so nothing reflows mid-flight.
class _FloatingSheet extends StatelessWidget {
  const _FloatingSheet({required this.showHandle, required this.child});

  final bool showHandle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottom = math.max(8.0, mq.viewPadding.bottom);
    final tone = AppSurface.of(context).tone;
    final animation =
        ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, bottom),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, pane) {
          final t = Curves.easeOutCubic.transform(
            animation.value.clamp(0.0, 1.0),
          );
          // The tab capsule spans 16 pt from the left edge to 90 pt from
          // the right (the ➕ and its gap beyond it); the sheet, 8 to 8.
          return ClipRRect(
            clipper: _MorphClipper(
              left: 8 * (1 - t),
              right: 82 * (1 - t),
              radius: 32 + 2 * t,
            ),
            child: Opacity(
              opacity: Curves.easeIn.transform(
                ((animation.value - 0.15) / 0.6).clamp(0.0, 1.0),
              ),
              child: pane,
            ),
          );
        },
        child: _sheetPane(context, tone),
      ),
    );
  }

  Widget _sheetPane(BuildContext context, GlassTone tone) {
    return LiquidGlass(
      borderRadius: BorderRadius.circular(34),
      frost: tone.sheetFrost,
      blur: 24,
      // Blur only: on a pane this large the lens is barely seen but its
      // pass is paid on every frame of the sheet's rise.
      refraction: 0,
      child: Material(
        type: MaterialType.transparency,
        // The inset already clears the home indicator.
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHandle)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 14),
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 5,
                      decoration: BoxDecoration(
                        color: tone.grabber,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 10),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sheet's visible window while it morphs out of the tab bar.
class _MorphClipper extends CustomClipper<RRect> {
  _MorphClipper({
    required this.left,
    required this.right,
    required this.radius,
  });

  final double left;
  final double right;
  final double radius;

  @override
  RRect getClip(Size size) => RRect.fromLTRBR(
    left,
    0,
    size.width - right,
    size.height,
    Radius.circular(radius),
  );

  @override
  bool shouldReclip(_MorphClipper old) =>
      old.left != left || old.right != right || old.radius != radius;
}

/// [showDialog], with the same arguments. Under Glass the page behind
/// frosts over while the dialog is open.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  if (!AppSurface.of(context).isGlass) {
    return showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
    );
  }
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push(
    _GlassDialogRoute<T>(
      context: context,
      builder: builder,
      barrierColor:
          Theme.of(context).dialogTheme.barrierColor ??
          AppSurface.of(context).tone.barrier,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
    ),
  );
}

class _GlassDialogRoute<T> extends DialogRoute<T> {
  _GlassDialogRoute({
    required super.context,
    required super.builder,
    super.barrierColor,
    super.barrierDismissible,
    super.barrierLabel,
    super.themes,
  });

  @override
  Widget buildModalBarrier() =>
      _BlurIn(animation: animation!, child: super.buildModalBarrier());

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);

  // iOS's alert: swells in from a touch smaller and settles, fades out.
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final scale = CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.2, 1.2, 0.4, 1),
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1).animate(scale),
        child: child,
      ),
    );
  }
}

/// The page frosting over as a route opens (and clearing as it closes),
/// rather than snapping to full blur on the first frame.
class _BlurIn extends AnimatedWidget {
  const _BlurIn({required Animation<double> animation, required this.child})
    : super(listenable: animation);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeOut.transform(
      (listenable as Animation<double>).value.clamp(0.0, 1.0),
    );
    if (t == 0) return child;
    final sigma = GlassStyle.barrierBlur * t;
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}

/// Material chrome glyphs → their Cupertino (SF Symbols) counterparts, with
/// a size factor where the iOS glyph is drawn larger or smaller than
/// Material's at the same point size. Only icons with a faithful match are
/// listed; everything else keeps its Material glyph.
final Map<IconData, (IconData, double)> _glassGlyphs = {
  Icons.chevron_right_rounded: (CupertinoIcons.chevron_forward, 0.78),
  Icons.chevron_right: (CupertinoIcons.chevron_forward, 0.78),
  Icons.chevron_left_rounded: (CupertinoIcons.chevron_back, 0.86),
  Icons.delete_outline: (CupertinoIcons.trash, 0.92),
  Icons.delete_outline_rounded: (CupertinoIcons.trash, 0.92),
  Icons.delete_forever_outlined: (CupertinoIcons.trash, 0.92),
  Icons.delete_sweep_outlined: (CupertinoIcons.trash, 0.92),
  Icons.edit_outlined: (CupertinoIcons.pencil, 1),
  Icons.edit_note_rounded: (CupertinoIcons.square_pencil, 0.95),
  Icons.south_west_rounded: (CupertinoIcons.arrow_down_left, 0.95),
  Icons.north_east_rounded: (CupertinoIcons.arrow_up_right, 0.95),
  Icons.call_received_rounded: (CupertinoIcons.arrow_down_left, 0.95),
  Icons.call_made_rounded: (CupertinoIcons.arrow_up_right, 0.95),
  Icons.add_rounded: (CupertinoIcons.add, 1),
  Icons.add: (CupertinoIcons.add, 1),
  Icons.add_circle_outline_rounded: (CupertinoIcons.add_circled, 1),
  Icons.remove_rounded: (CupertinoIcons.minus, 1),
  Icons.check_rounded: (CupertinoIcons.checkmark_alt, 1),
  Icons.check_circle_rounded: (CupertinoIcons.checkmark_circle_fill, 1),
  Icons.check_circle_outline_rounded: (CupertinoIcons.checkmark_circle, 1),
  Icons.check_circle_outline: (CupertinoIcons.checkmark_circle, 1),
  Icons.task_alt_rounded: (CupertinoIcons.checkmark_circle, 1),
  Icons.close_rounded: (CupertinoIcons.xmark, 0.86),
  Icons.close: (CupertinoIcons.xmark, 0.86),
  Icons.search_rounded: (CupertinoIcons.search, 0.95),
  Icons.search: (CupertinoIcons.search, 0.95),
  Icons.tune_rounded: (CupertinoIcons.slider_horizontal_3, 0.95),
  Icons.tune_outlined: (CupertinoIcons.slider_horizontal_3, 0.95),
  Icons.autorenew_rounded: (CupertinoIcons.arrow_2_circlepath, 0.95),
  Icons.event_repeat_outlined: (CupertinoIcons.arrow_2_circlepath, 0.95),
  Icons.swap_horiz_rounded: (CupertinoIcons.arrow_right_arrow_left, 0.95),
  Icons.sync_alt_rounded: (CupertinoIcons.arrow_right_arrow_left, 0.95),
  Icons.swap_vert_rounded: (CupertinoIcons.arrow_up_arrow_down, 0.95),
  Icons.receipt_long_outlined: (CupertinoIcons.doc_text, 1),
  Icons.receipt_long_rounded: (CupertinoIcons.doc_text_fill, 1),
  Icons.receipt_outlined: (CupertinoIcons.doc_text, 1),
  Icons.request_quote_outlined: (CupertinoIcons.doc_text, 1),
  Icons.picture_as_pdf_outlined: (CupertinoIcons.doc, 1),
  Icons.storefront_outlined: (CupertinoIcons.bag, 1),
  Icons.storefront_rounded: (CupertinoIcons.bag_fill, 1),
  Icons.shopping_bag_outlined: (CupertinoIcons.bag, 1),
  Icons.shopping_basket_outlined: (CupertinoIcons.cart, 1),
  Icons.shopping_cart_checkout_outlined: (CupertinoIcons.cart, 1),
  Icons.sell_outlined: (CupertinoIcons.tag, 0.95),
  Icons.sell_rounded: (CupertinoIcons.tag_fill, 0.95),
  Icons.calendar_month_outlined: (CupertinoIcons.calendar, 1),
  Icons.calendar_month_rounded: (CupertinoIcons.calendar, 1),
  Icons.calendar_today_outlined: (CupertinoIcons.calendar_today, 1),
  Icons.calendar_today_rounded: (CupertinoIcons.calendar_today, 1),
  Icons.today_rounded: (CupertinoIcons.calendar_today, 1),
  Icons.event_outlined: (CupertinoIcons.calendar, 1),
  Icons.event_rounded: (CupertinoIcons.calendar, 1),
  Icons.date_range_outlined: (CupertinoIcons.calendar, 1),
  Icons.event_available_outlined: (CupertinoIcons.calendar_badge_plus, 1),
  Icons.edit_calendar_outlined: (CupertinoIcons.calendar_badge_plus, 1),
  Icons.pie_chart_outline_rounded: (CupertinoIcons.chart_pie, 1),
  Icons.pie_chart_rounded: (CupertinoIcons.chart_pie_fill, 1),
  Icons.donut_large_rounded: (CupertinoIcons.chart_pie, 1),
  Icons.donut_large_outlined: (CupertinoIcons.chart_pie, 1),
  Icons.insights_outlined: (CupertinoIcons.graph_square, 1),
  Icons.insights_rounded: (CupertinoIcons.graph_square_fill, 1),
  Icons.show_chart_rounded: (CupertinoIcons.graph_square, 1),
  Icons.bar_chart_rounded: (CupertinoIcons.chart_bar, 1),
  Icons.trending_up_rounded: (CupertinoIcons.arrow_up_right, 0.95),
  Icons.trending_down_rounded: (CupertinoIcons.arrow_down_right, 0.95),
  Icons.arrow_upward_rounded: (CupertinoIcons.arrow_up, 0.95),
  Icons.arrow_downward_rounded: (CupertinoIcons.arrow_down, 0.95),
  Icons.person_outline_rounded: (CupertinoIcons.person, 1),
  Icons.person_rounded: (CupertinoIcons.person_fill, 1),
  Icons.person_add_alt_1_outlined: (CupertinoIcons.person_badge_plus, 1),
  Icons.groups_outlined: (CupertinoIcons.person_3, 1.1),
  Icons.groups_2_outlined: (CupertinoIcons.person_3, 1.1),
  Icons.group_outlined: (CupertinoIcons.person_2, 1),
  Icons.people_alt_outlined: (CupertinoIcons.person_2, 1),
  Icons.people_alt_rounded: (CupertinoIcons.person_2_fill, 1),
  Icons.people_outline_rounded: (CupertinoIcons.person_2, 1),
  Icons.people_outline: (CupertinoIcons.person_2, 1),
  Icons.contacts_outlined: (CupertinoIcons.person_crop_circle, 1),
  Icons.call_split_rounded: (CupertinoIcons.arrow_branch, 1),
  Icons.archive_outlined: (CupertinoIcons.archivebox, 1),
  Icons.inventory_2_outlined: (CupertinoIcons.archivebox, 1),
  Icons.inbox_outlined: (CupertinoIcons.tray, 1),
  Icons.qr_code_2_rounded: (CupertinoIcons.qrcode, 1),
  Icons.qr_code_outlined: (CupertinoIcons.qrcode, 1),
  Icons.error_outline_rounded: (CupertinoIcons.exclamationmark_circle, 1),
  Icons.error_outline: (CupertinoIcons.exclamationmark_circle, 1),
  Icons.warning_amber_rounded: (CupertinoIcons.exclamationmark_triangle, 1),
  Icons.info_outline_rounded: (CupertinoIcons.info_circle, 1),
  Icons.notifications_outlined: (CupertinoIcons.bell, 1),
  Icons.link_rounded: (CupertinoIcons.link, 1),
  Icons.credit_card_outlined: (CupertinoIcons.creditcard, 1),
  Icons.undo_rounded: (CupertinoIcons.arrow_uturn_left, 1),
  Icons.schedule_outlined: (CupertinoIcons.clock, 1),
  Icons.access_time_rounded: (CupertinoIcons.clock, 1),
  Icons.history_rounded: (CupertinoIcons.clock, 1),
  Icons.timer_outlined: (CupertinoIcons.timer, 1),
  Icons.hourglass_top_rounded: (CupertinoIcons.hourglass, 1),
  Icons.lock_outline_rounded: (CupertinoIcons.lock, 1),
  Icons.lock_outline: (CupertinoIcons.lock, 1),
  Icons.lock_open_outlined: (CupertinoIcons.lock_open, 1),
  Icons.mail_outline_rounded: (CupertinoIcons.mail, 1),
  Icons.email_outlined: (CupertinoIcons.mail, 1),
  Icons.more_vert_rounded: (CupertinoIcons.ellipsis_vertical, 1),
  Icons.more_vert: (CupertinoIcons.ellipsis_vertical, 1),
  Icons.more_horiz_rounded: (CupertinoIcons.ellipsis, 1),
  Icons.photo_camera_outlined: (CupertinoIcons.camera, 1),
  Icons.camera_alt_outlined: (CupertinoIcons.camera, 1),
  Icons.camera_alt_rounded: (CupertinoIcons.camera_fill, 1),
  Icons.image_outlined: (CupertinoIcons.photo, 1),
  Icons.photo_library_outlined: (CupertinoIcons.photo_on_rectangle, 1),
  Icons.share_rounded: (CupertinoIcons.share, 1),
  Icons.ios_share_rounded: (CupertinoIcons.share, 1),
  Icons.settings_outlined: (CupertinoIcons.settings, 1),
  Icons.settings_rounded: (CupertinoIcons.settings_solid, 1),
  Icons.send_rounded: (CupertinoIcons.paperplane, 1),
  Icons.refresh_rounded: (CupertinoIcons.arrow_clockwise, 1),
  Icons.restore_rounded: (CupertinoIcons.arrow_counterclockwise, 1),
  Icons.restart_alt_rounded: (CupertinoIcons.arrow_counterclockwise, 1),
  Icons.settings_backup_restore_rounded: (
    CupertinoIcons.arrow_counterclockwise,
    1,
  ),
  Icons.open_in_new_rounded: (CupertinoIcons.arrow_up_right_square, 1),
  Icons.download_outlined: (CupertinoIcons.arrow_down_to_line, 1),
  Icons.download_rounded: (CupertinoIcons.arrow_down_to_line, 1),
  Icons.cloud_download_outlined: (CupertinoIcons.cloud_download, 1),
  Icons.backup_outlined: (CupertinoIcons.cloud_upload, 1),
  Icons.content_copy_outlined: (CupertinoIcons.doc_on_doc, 1),
  Icons.copy_rounded: (CupertinoIcons.doc_on_doc, 1),
  Icons.visibility_outlined: (CupertinoIcons.eye, 1),
  Icons.visibility_rounded: (CupertinoIcons.eye_fill, 1),
  Icons.visibility_off_rounded: (CupertinoIcons.eye_slash, 1),
  Icons.backspace_outlined: (CupertinoIcons.delete_left, 1),
  Icons.home_outlined: (CupertinoIcons.house, 1),
  Icons.house_outlined: (CupertinoIcons.house, 1),
  Icons.star_rate_rounded: (CupertinoIcons.star_fill, 1),
  Icons.favorite_outline_rounded: (CupertinoIcons.heart, 1),
  Icons.bookmark_add_outlined: (CupertinoIcons.bookmark, 1),
  Icons.flag_outlined: (CupertinoIcons.flag, 1),
  Icons.place_outlined: (CupertinoIcons.location, 1),
  Icons.map_outlined: (CupertinoIcons.map, 1),
  Icons.phone_iphone_outlined: (CupertinoIcons.device_phone_portrait, 1),
  Icons.chat_bubble_outline: (CupertinoIcons.chat_bubble, 1),
  Icons.forum_outlined: (CupertinoIcons.chat_bubble_2, 1),
  Icons.sms_outlined: (CupertinoIcons.chat_bubble_text, 1),
  Icons.bolt_outlined: (CupertinoIcons.bolt, 1),
  Icons.bolt_rounded: (CupertinoIcons.bolt_fill, 1),
  Icons.flash_on_outlined: (CupertinoIcons.bolt, 1),
  Icons.category_outlined: (CupertinoIcons.square_grid_2x2, 1),
  Icons.category_rounded: (CupertinoIcons.square_grid_2x2_fill, 1),
  Icons.grid_view_rounded: (CupertinoIcons.square_grid_2x2_fill, 1),
  Icons.grid_view_outlined: (CupertinoIcons.square_grid_2x2, 1),
  Icons.dashboard_customize_outlined: (CupertinoIcons.square_grid_2x2, 1),
  Icons.dashboard_outlined: (CupertinoIcons.rectangle_grid_2x2, 1),
  Icons.checklist_outlined: (CupertinoIcons.list_bullet, 1),
  Icons.checklist_rounded: (CupertinoIcons.list_bullet, 1),
  Icons.view_list_rounded: (CupertinoIcons.list_bullet, 1),
  Icons.notes_rounded: (CupertinoIcons.doc_plaintext, 1),
  Icons.notes_outlined: (CupertinoIcons.doc_plaintext, 1),
  Icons.sticky_note_2_outlined: (CupertinoIcons.doc_plaintext, 1),
  Icons.palette_rounded: (CupertinoIcons.paintbrush, 1),
  Icons.light_mode_rounded: (CupertinoIcons.sun_max, 1),
  Icons.dark_mode_rounded: (CupertinoIcons.moon, 1),
  Icons.brightness_auto_rounded: (CupertinoIcons.circle_lefthalf_fill, 1),
  Icons.contrast_rounded: (CupertinoIcons.circle_lefthalf_fill, 1),
  Icons.text_fields_rounded: (CupertinoIcons.textformat, 1),
  Icons.language_rounded: (CupertinoIcons.globe, 1),
  Icons.public_rounded: (CupertinoIcons.globe, 1),
  Icons.shield_outlined: (CupertinoIcons.shield, 1),
  Icons.security_outlined: (CupertinoIcons.shield, 1),
  Icons.verified_user_outlined: (CupertinoIcons.checkmark_shield, 1),
  Icons.file_open_outlined: (CupertinoIcons.folder_open, 1),
  Icons.table_chart_outlined: (CupertinoIcons.table, 1),
  Icons.print_outlined: (CupertinoIcons.printer, 1),
  Icons.dialpad_outlined: (CupertinoIcons.circle_grid_3x3, 1),
  Icons.pause_circle_outline: (CupertinoIcons.pause_circle, 1),
  Icons.play_circle_outline: (CupertinoIcons.play_circle, 1),
  Icons.percent_rounded: (CupertinoIcons.percent, 1),
  Icons.pin_outlined: (CupertinoIcons.pin, 1),
  Icons.push_pin_outlined: (CupertinoIcons.pin, 1),
  Icons.emoji_emotions_outlined: (CupertinoIcons.smiley, 1),
  Icons.code_rounded: (CupertinoIcons.chevron_left_slash_chevron_right, 1),
  Icons.bug_report_outlined: (CupertinoIcons.ant, 1),
  Icons.menu_book_outlined: (CupertinoIcons.book, 1),
  Icons.work_outline_rounded: (CupertinoIcons.briefcase, 1),
  Icons.open_in_full_rounded: (
    CupertinoIcons.arrow_up_left_arrow_down_right,
    1,
  ),
  Icons.fullscreen_exit_rounded: (
    CupertinoIcons.arrow_down_right_arrow_up_left,
    1,
  ),
  Icons.radio_button_checked_rounded: (
    CupertinoIcons.largecircle_fill_circle,
    1,
  ),
  Icons.circle_outlined: (CupertinoIcons.circle, 1),
  Icons.wifi_off_rounded: (CupertinoIcons.wifi_slash, 1),
  Icons.gavel_rounded: (CupertinoIcons.hammer, 1),
};

/// Glass's segmented switch for a [TabController]: the labels in a floating
/// Liquid Glass capsule, with a glass droplet that follows the controller's
/// *live* position — so it tracks a swipe between pages continuously — and
/// stretches mid-way like liquid, as the tab bar's droplet does. Tapping a
/// label glides there.
class GlassTabSwitch extends StatelessWidget {
  const GlassTabSwitch({
    required this.controller,
    required this.labels,
    super.key,
  });

  final TabController controller;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tone = AppSurface.of(context).tone;
    final animation = controller.animation!;
    return SizedBox(
      height: GlassTabbedBody.switchHeight,
      // The pages scroll under it, so it frosts them like the top bar.
      child: LiquidGlass(
        child: LayoutBuilder(
          builder: (context, box) {
            final itemWidth = (box.maxWidth - 8) / labels.length;
            return AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final v = animation.value;
                final frac = v - v.floorToDouble();
                final stretch = 1 + 0.22 * math.sin(math.pi * frac);
                final width = (itemWidth - 4) * stretch;
                final centre = 4 + v * itemWidth + itemWidth / 2;
                return Stack(
                  children: [
                    Positioned(
                      left: centre - width / 2,
                      width: width,
                      top: 4,
                      bottom: 4,
                      child: LiquidGlass(
                        frost: tone.selected,
                        backdrop: false,
                        shadow: false,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          for (var i = 0; i < labels.length; i++)
                            Expanded(
                              child: Semantics(
                                button: true,
                                selected: controller.index == i,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => controller.animateTo(
                                    i,
                                    duration: const Duration(milliseconds: 340),
                                    curve: Curves.easeOutCubic,
                                  ),
                                  child: Center(
                                    child: Text(
                                      labels[i],
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: Color.lerp(
                                              cs.onSurfaceVariant,
                                              cs.onSurface,
                                              (1 - (v - i).abs()).clamp(
                                                0.0,
                                                1.0,
                                              ),
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Glass's paged tab body (Persons' Individual / Group): the
/// [GlassTabSwitch] floats right under the top bar and the pages scroll all
/// the way up, under both. With a switch to hold, the page keeps its title
/// small in the bar — no large-title row to leave a gap — and the bar
/// follows the page on screen (blended between pages mid-swipe).
///
/// Each page gets the room above it as `MediaQuery.paddingOf(context).top`.
class GlassTabbedBody extends StatefulWidget {
  const GlassTabbedBody({
    required this.controller,
    required this.labels,
    required this.children,
    this.underShellBar = true,
    super.key,
  });

  static const double switchHeight = 46;

  final TabController controller;
  final List<String> labels;
  final List<Widget> children;

  /// Under the shell's Glass top bar (a tab), rather than a pushed screen's
  /// own app bar.
  final bool underShellBar;

  @override
  State<GlassTabbedBody> createState() => _GlassTabbedBodyState();
}

class _GlassTabbedBodyState extends State<GlassTabbedBody> {
  final _offsets = <int, double>{};
  double? _reported;

  Animation<double> get _page => widget.controller.animation!;

  @override
  void initState() {
    super.initState();
    _page.addListener(_report);
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void didUpdateWidget(GlassTabbedBody old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.animation!.removeListener(_report);
      _page.addListener(_report);
    }
  }

  @override
  void dispose() {
    _page.removeListener(_report);
    super.dispose();
  }

  void _report() {
    if (!mounted || !widget.underShellBar || inHiddenTab(context)) return;
    final last = widget.children.length - 1;
    final v = _page.value.clamp(0.0, last.toDouble());
    final i = v.floor();
    final a = _offsets[i] ?? 0;
    final b = _offsets[math.min(i + 1, last)] ?? 0;
    final pixels = glassLargeTitleExtent + math.max(0.0, a + (b - a) * (v - i));
    if (pixels == _reported) return;
    _reported = pixels;
    TopBarScrollNotification(pixels).dispatch(context);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // The bar's bottom edge: the large-title row is given back.
    final barBottom = widget.underShellBar
        ? math.max(0.0, mq.padding.top - glassLargeTitleExtent)
        : mq.padding.top;
    final switchTop = barBottom + 2;
    return Stack(
      children: [
        MediaQuery(
          data: mq.copyWith(
            padding: mq.padding.copyWith(
              top: switchTop + GlassTabbedBody.switchHeight + 10,
            ),
          ),
          child: TabBarView(
            controller: widget.controller,
            children: [
              for (var i = 0; i < widget.children.length; i++)
                NotificationListener<Notification>(
                  onNotification: (n) {
                    final (depth, metrics) = switch (n) {
                      ScrollNotification() => (n.depth, n.metrics),
                      ScrollMetricsNotification() => (n.depth, n.metrics),
                      _ => (-1, null),
                    };
                    if (depth == 0 && metrics?.axis == Axis.vertical) {
                      _offsets[i] = metrics!.pixels;
                      _report();
                    }
                    return false;
                  },
                  child: widget.children[i],
                ),
            ],
          ),
        ),
        Positioned(
          top: switchTop,
          left: 16,
          right: 16,
          child: GlassTabSwitch(
            controller: widget.controller,
            labels: widget.labels,
          ),
        ),
      ],
    );
  }
}
