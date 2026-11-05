import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Marks [child] as something a page can zoom out of — a card, a list row.
/// [AppCard] and [AppListTile] wear one already; a custom row that opens a
/// page can wrap itself in one too. See `pushZoom`.
class ZoomSource extends SingleChildRenderObjectWidget {
  const ZoomSource({required this.radius, super.child, super.key});

  /// The source's corner radius, so the page starts as its exact shape.
  final double radius;

  @override
  RenderZoomSource createRenderObject(BuildContext context) =>
      RenderZoomSource(radius);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderZoomSource renderObject,
  ) => renderObject.radius = radius;
}

class RenderZoomSource extends RenderProxyBox {
  RenderZoomSource(this.radius);

  double radius;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    ZoomOrigin._track();
  }
}

/// Where a zoom starts: the global rect and corner radius of a [ZoomSource].
typedef ZoomFrom = ({Rect rect, double radius});

/// Finds the [ZoomSource] the user just touched. Taps reach `onTap` with no
/// position, so the last pointer-down anywhere is remembered and the zoom
/// source under it looked up — the innermost one, so a row inside a grouped
/// card zooms out of the row, not the whole card.
class ZoomOrigin {
  const ZoomOrigin._();

  static bool _tracking = false;
  static Offset? _lastDown;
  static int _lastView = 0;

  static void _track() {
    if (_tracking) return;
    _tracking = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute((event) {
      if (event is PointerDownEvent) {
        _lastDown = event.position;
        _lastView = event.viewId;
      }
    });
  }

  /// The source under the last touch, or null — no touch yet (a keyboard or
  /// screen-reader activation), or nothing zoomable under it.
  static ZoomFrom? lastTouched() {
    final at = _lastDown;
    if (at == null) return null;
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, at, _lastView);
    // Deepest first: the innermost source wins.
    for (final entry in result.path) {
      final target = entry.target;
      if (target is! RenderZoomSource || !target.attached || !target.hasSize) {
        continue;
      }
      final rect = MatrixUtils.transformRect(
        target.getTransformTo(null),
        Offset.zero & target.size,
      );
      if (rect.isEmpty) return null;
      return (rect: rect, radius: target.radius);
    }
    return null;
  }

  @visibleForTesting
  static void debugReset() => _lastDown = null;
}
