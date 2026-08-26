import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/routing/hold_menu_geometry.dart';

void main() {
  // Matches AppShell._AddButton's actual constants — kept literal here
  // (not imported, `_AddButtonState`'s fields are private) so a change to
  // either has to be a deliberate edit in both places, not a silent drift.
  const angles = [-150.0, -90.0, -30.0];
  const radius = 150.0;
  const activationRadius = 26.0;
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

  /// A point [distance] out from [origin], along [angleDegrees].
  Offset pointAt(double angleDegrees, double distance) {
    final rad = angleDegrees * math.pi / 180;
    return origin + Offset(math.cos(rad), math.sin(rad)) * distance;
  }

  group('holdMenuHoveredIndex', () {
    test(
      'within the activation radius of origin, no direction is committed '
      'yet',
      () {
        final justInside = pointAt(-90, activationRadius - 1);
        final hovered = holdMenuHoveredIndex(
          origin: origin,
          pointer: justInside,
          anglesDegrees: angles,
          activationRadius: activationRadius,
          optionCount: 3,
        );
        expect(hovered, -1);
      },
    );

    test('right at the origin, no direction is committed', () {
      final hovered = holdMenuHoveredIndex(
        origin: origin,
        pointer: origin,
        anglesDegrees: angles,
        activationRadius: activationRadius,
        optionCount: 3,
      );
      expect(hovered, -1);
    });

    test(
      'a short move just past the activation radius, in an option\'s exact '
      'direction, selects it — the finger never has to reach anywhere near '
      'where the option is actually drawn (radius=$radius)',
      () {
        final justPast = pointAt(-90, activationRadius + 1);
        final hovered = holdMenuHoveredIndex(
          origin: origin,
          pointer: justPast,
          anglesDegrees: angles,
          activationRadius: activationRadius,
          optionCount: 3,
        );
        expect(hovered, 1); // -90° is option 1
      },
    );

    test('a short move toward the upper-left selects option 0', () {
      final hovered = holdMenuHoveredIndex(
        origin: origin,
        pointer: pointAt(-150, activationRadius + 5),
        anglesDegrees: angles,
        activationRadius: activationRadius,
        optionCount: 3,
      );
      expect(hovered, 0);
    });

    test('a short move toward the upper-right selects option 2', () {
      final hovered = holdMenuHoveredIndex(
        origin: origin,
        pointer: pointAt(-30, activationRadius + 5),
        anglesDegrees: angles,
        activationRadius: activationRadius,
        optionCount: 3,
      );
      expect(hovered, 2);
    });

    test(
      'exactly between two options selects the nearer one, never "no '
      'selection" — every direction past the activation radius resolves to '
      'something',
      () {
        // Halfway between option 0 (-150°) and option 1 (-90°) is -120°,
        // equidistant — the algorithm's stable tie-break (first match by
        // iteration order) picks option 0.
        final hovered = holdMenuHoveredIndex(
          origin: origin,
          pointer: pointAt(-120, activationRadius + 5),
          anglesDegrees: angles,
          activationRadius: activationRadius,
          optionCount: 3,
        );
        expect(hovered, anyOf(0, 1));
      },
    );

    test('far past any option\'s own drawn radius still resolves correctly '
        '— distance never matters once past the activation threshold', () {
      final farPast = pointAt(-30, radius * 3);
      final hovered = holdMenuHoveredIndex(
        origin: origin,
        pointer: farPast,
        anglesDegrees: angles,
        activationRadius: activationRadius,
        optionCount: 3,
      );
      expect(hovered, 2);
    });

    test('optionCount limits which options are even considered', () {
      final hovered = holdMenuHoveredIndex(
        origin: origin,
        pointer: pointAt(-30, activationRadius + 5), // would be option 2
        anglesDegrees: angles,
        activationRadius: activationRadius,
        optionCount: 2, // option 2 excluded — nearest of the remaining 2
      );
      expect(hovered, isNot(2));
    });
  });
}
