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

// ── Glass: the corner fan ────────────────────────────────────────────────

/// Glass's quick-action fan: [count] bubbles on two arcs opening up and to
/// the left of [anchor] (the ➕ in the bottom-right corner) — an inner arc
/// of up to three, an outer arc of the rest. Screen convention, as above:
/// the arcs run from just short of straight up (-92°) to straight left
/// (-178°), so nothing falls off the right or bottom edge.
List<Offset> glassFanCenters(
  Offset anchor,
  int count, {
  double innerRadius = 118,
  double outerRadius = 204,
}) {
  if (count <= 0) return const [];
  final inner = count <= 3 ? count : (count <= 4 ? 2 : 3);
  final outer = count - inner;
  final centres = <Offset>[];
  void arc(int k, double radius) {
    for (var i = 0; i < k; i++) {
      final t = k == 1 ? 0.5 : i / (k - 1);
      final degrees = -92 - 86 * t;
      final rad = degrees * math.pi / 180;
      centres.add(anchor + Offset(math.cos(rad), math.sin(rad)) * radius);
    }
  }

  arc(inner, innerRadius);
  arc(outer, outerRadius);
  return centres;
}

/// The bubble the thumb is over: the nearest of [centres] within
/// [hitRadius] of [pointer], or `-1` — which also covers the thumb resting
/// back on the ➕ (within [cancelRadius] of [anchor]), a release there being
/// a cancel.
int glassFanHoveredIndex({
  required Offset anchor,
  required Offset pointer,
  required List<Offset> centres,
  double hitRadius = 52,
  double cancelRadius = 40,
}) {
  if ((pointer - anchor).distance < cancelRadius) return -1;
  var best = -1;
  var bestDistance = hitRadius;
  for (var i = 0; i < centres.length; i++) {
    final d = (pointer - centres[i]).distance;
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }
  return best;
}
