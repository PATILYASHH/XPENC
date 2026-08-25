import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/routing/hold_menu_geometry.dart';

void main() {
  // Matches AppShell._AddButton's actual constants — kept literal here
  // (not imported, `_AddButtonState`'s fields are private) so a change to
  // either has to be a deliberate edit in both places, not a silent drift.
  const angles = [-150.0, -90.0, -30.0];
  const radius = 92.0;
  const hitRadius = 34.0;
  const origin = Offset(200, 800);

  group('holdMenuOptionCenter', () {
    test('straight up (-90°) sits directly above origin', () {
      final center = holdMenuOptionCenter(origin, angles, radius, 1);
      expect(center.dx, closeTo(origin.dx, 0.001));
      expect(center.dy, closeTo(origin.dy - radius, 0.001));
    });

    test('upper-left and upper-right are symmetric around straight-up', () {
      final left = holdMenuOptionCenter(origin, angles, radius, 0);
      final right = holdMenuOptionCenter(origin, angles, radius, 2);
      expect(left.dx, closeTo(origin.dx - (right.dx - origin.dx), 0.001));
      expect(left.dy, closeTo(right.dy, 0.001));
      expect(left.dx, lessThan(origin.dx));
      expect(right.dx, greaterThan(origin.dx));
    });

    test('every option sits exactly radius away from origin', () {
      for (var i = 0; i < angles.length; i++) {
        final center = holdMenuOptionCenter(origin, angles, radius, i);
        expect((center - origin).distance, closeTo(radius, 0.001));
      }
    });
  });

  group('holdMenuHoveredIndex', () {
    test('right on an option\'s centre hits that option', () {
      final center = holdMenuOptionCenter(origin, angles, radius, 1);
      final hovered = holdMenuHoveredIndex(
        origin: origin,
        pointer: center,
        anglesDegrees: angles,
        radius: radius,
        hitRadius: hitRadius,
        optionCount: 3,
      );
      expect(hovered, 1);
    });

    test('at the origin (finger hasn\'t moved yet) hits nothing', () {
      final hovered = holdMenuHoveredIndex(
        origin: origin,
        pointer: origin,
        anglesDegrees: angles,
        radius: radius,
        hitRadius: hitRadius,
        optionCount: 3,
      );
      expect(hovered, -1);
    });

    test('exactly between two options, closer to neither, hits nothing', () {
      // Roughly halfway along the arc between option 0 (-150°) and option 1
      // (-90°) is well outside both hit circles at this radius/hitRadius.
      final midAngleCenter = holdMenuOptionCenter(origin, [-120.0], radius, 0);
      final hovered = holdMenuHoveredIndex(
        origin: origin,
        pointer: midAngleCenter,
        anglesDegrees: angles,
        radius: radius,
        hitRadius: hitRadius,
        optionCount: 3,
      );
      expect(hovered, -1);
    });

    test('just inside an option\'s hit radius still counts', () {
      final center = holdMenuOptionCenter(origin, angles, radius, 2);
      final justInside = center + const Offset(hitRadius - 1, 0);
      final hovered = holdMenuHoveredIndex(
        origin: origin,
        pointer: justInside,
        anglesDegrees: angles,
        radius: radius,
        hitRadius: hitRadius,
        optionCount: 3,
      );
      expect(hovered, 2);
    });

    test('just outside an option\'s hit radius misses', () {
      final center = holdMenuOptionCenter(origin, angles, radius, 2);
      final justOutside = center + const Offset(hitRadius + 5, 0);
      final hovered = holdMenuHoveredIndex(
        origin: origin,
        pointer: justOutside,
        anglesDegrees: angles,
        radius: radius,
        hitRadius: hitRadius,
        optionCount: 3,
      );
      expect(hovered, -1);
    });

    test('optionCount limits which options are even considered', () {
      final center = holdMenuOptionCenter(origin, angles, radius, 2);
      final hovered = holdMenuHoveredIndex(
        origin: origin,
        pointer: center,
        anglesDegrees: angles,
        radius: radius,
        hitRadius: hitRadius,
        optionCount: 2, // option 2 excluded
      );
      expect(hovered, -1);
    });
  });
}
