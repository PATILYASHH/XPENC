import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Pure geometry for the hold-➕ quick-access menu (`AppShell._AddButton`) —
/// split out from the widget so the hit-testing math can be unit tested
/// directly, without needing a full `GoRouter`/`StatefulShellRoute` test
/// harness to pump `AppShell` itself (nothing else in this codebase has one
/// either).

/// Where option [index]'s centre sits, [radius] out from [origin] along
/// [anglesDegrees]\[index\] — screen convention (0° = right, clockwise, so
/// -90° is straight up).
Offset holdMenuOptionCenter(
  Offset origin,
  List<double> anglesDegrees,
  double radius,
  int index,
) {
  final rad = anglesDegrees[index] * math.pi / 180;
  return origin + Offset(math.cos(rad), math.sin(rad)) * radius;
}

/// Which option (if any) the direction from [origin] to [pointer] points
/// toward — angle-based, not distance-based. A user shouldn't have to drag
/// all the way out to wherever an option is actually drawn; a short flick
/// in roughly the right direction should be enough to commit to it. So:
/// once the finger has moved past [activationRadius] — deliberately much
/// smaller than [holdMenuOptionCenter]'s own `radius` — whichever option's
/// angle is *closest* to the finger's current direction is selected,
/// regardless of how far it's actually travelled. `-1` means the finger
/// hasn't moved far enough yet to indicate a direction at all.
int holdMenuHoveredIndex({
  required Offset origin,
  required Offset pointer,
  required List<double> anglesDegrees,
  required double activationRadius,
  required int optionCount,
}) {
  final delta = pointer - origin;
  if (delta.distance < activationRadius) return -1;

  final pointerAngle = math.atan2(delta.dy, delta.dx) * 180 / math.pi;
  var best = -1;
  var bestDiff = double.infinity;
  for (var i = 0; i < optionCount; i++) {
    final diff = _angleDifference(pointerAngle, anglesDegrees[i]);
    if (diff < bestDiff) {
      bestDiff = diff;
      best = i;
    }
  }
  return best;
}

/// Smallest absolute difference between two angles in degrees, correctly
/// wrapping around ±180° (e.g. 170° and -170° are 20° apart, not 340°).
double _angleDifference(double a, double b) {
  var diff = (a - b) % 360;
  if (diff > 180) diff -= 360;
  if (diff < -180) diff += 360;
  return diff.abs();
}
