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

/// Which option (if any) [pointer] currently sits within [hitRadius] of,
/// out of [optionCount] options arranged per [holdMenuOptionCenter]. `-1`
/// means none — the finger hasn't reached any option yet (including while
/// still near [origin], the starting point).
int holdMenuHoveredIndex({
  required Offset origin,
  required Offset pointer,
  required List<double> anglesDegrees,
  required double radius,
  required double hitRadius,
  required int optionCount,
}) {
  for (var i = 0; i < optionCount; i++) {
    final center = holdMenuOptionCenter(origin, anglesDegrees, radius, i);
    if ((pointer - center).distance <= hitRadius) return i;
  }
  return -1;
}
