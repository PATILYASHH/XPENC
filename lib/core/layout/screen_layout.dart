import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Which of XPENC's three layouts a screen gets.
///
/// - [phone]: the bottom bar across the foot, every page full width.
/// - [tablet]: a touch screen with room — a tablet, an unfolded foldable.
///   The tab bar floats as a compact capsule in the bottom-right corner,
///   within reach of the thumb holding the tablet; a ☰ in the top-left
///   corner opens every page the app has (see `showNavDrawer`).
/// - [desktop]: a PC — XPENC web in a desktop browser, mostly. A sidebar
///   beside every page (see `DesktopFrame`).
enum ScreenLayout { phone, tablet, desktop }

/// Below this width a PC window gets the phone layout.
const desktopMinWidth = 1024.0;

/// From this shortest side up, a touch screen gets the tablet layout. A
/// 7-inch tablet (600) stays a phone: the corner bar needs room beside it
/// to read as a corner bar rather than a phone bar pushed off-centre.
const tabletMinShortestSide = 640.0;

/// From this width a tablet's page has room for its wide layout — the
/// dashboard's columns (landscape, and the big tablets upright).
const tabletWideMinWidth = 900.0;

/// A tablet's tab bar is a vertical rail in the bottom-right corner: this
/// wide, each tab this tall, standing this far off the window's edge.
const tabletRailWidth = 76.0;
const tabletRailTabExtent = 64.0;
const tabletRailMargin = 16.0;

/// The strip down a tablet's right side every tab keeps clear, so the rail
/// never sits over the page: its margin, its width, and a gap.
const tabletRailGutter = tabletRailMargin + tabletRailWidth + 12;

/// Whether this platform is driven by touch: Android and iOS, including XPENC
/// web opened on one (Flutter reads the browser's platform there).
bool get isTouchPlatform => switch (defaultTargetPlatform) {
  TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => true,
  _ => false,
};

/// The layout a window of [size] gets. A touch screen is a tablet by its
/// shortest side, so rotating one keeps the tablet layout; a PC goes by width.
ScreenLayout screenLayoutFor(Size size) {
  if (isTouchPlatform) {
    return size.shortestSide >= tabletMinShortestSide
        ? ScreenLayout.tablet
        : ScreenLayout.phone;
  }
  return size.width >= desktopMinWidth
      ? ScreenLayout.desktop
      : ScreenLayout.phone;
}

/// Which layout the screen has — see [ScreenLayout]. Put over the app's
/// navigator by [DesktopFrame].
class DesktopLayout extends InheritedWidget {
  const DesktopLayout({required this.layout, required super.child, super.key});

  final ScreenLayout layout;

  bool get isDesktop => layout == ScreenLayout.desktop;

  static ScreenLayout layoutOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesktopLayout>()?.layout ??
      ScreenLayout.phone;

  /// Whether the screen is laid out for a PC — the sidebar, a mouse.
  static bool of(BuildContext context) =>
      layoutOf(context) == ScreenLayout.desktop;

  /// Whether the screen is laid out for a tablet — the corner bar, the ☰.
  static bool isTablet(BuildContext context) =>
      layoutOf(context) == ScreenLayout.tablet;

  /// Whether the page has room for its wide layout (the dashboard's
  /// columns): always on a PC; on a tablet once the page is
  /// [tabletWideMinWidth] across.
  static bool wideContent(BuildContext context) => switch (layoutOf(context)) {
    ScreenLayout.desktop => true,
    ScreenLayout.tablet =>
      MediaQuery.sizeOf(context).width >= tabletWideMinWidth,
    ScreenLayout.phone => false,
  };

  @override
  bool updateShouldNotify(DesktopLayout oldWidget) =>
      oldWidget.layout != layout;
}
