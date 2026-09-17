import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/features/persons/person_avatar.dart';

/// `personInitials` used to be duplicated (identically) between
/// `persons_screen.dart` and `archived_persons_screen.dart`; this pins the
/// single shared implementation's behavior. `PersonAvatar` itself is
/// exercised for the two paths that matter after photo import (GitHub
/// #132-adjacent feature): no path falls back to initials, and a path
/// pointing at nothing on disk (e.g. a backup restored on another phone
/// missing the photo file) does too rather than crashing.
void main() {
  group('personInitials', () {
    test('two words takes the first letter of each', () {
      expect(personInitials('Rahul Kumar'), 'RK');
    });

    test('a single word takes just its first letter', () {
      expect(personInitials('Ram'), 'R');
    });

    test('extra whitespace is ignored', () {
      expect(personInitials('  Rahul   Kumar  '), 'RK');
    });

    test('an empty name falls back to a placeholder', () {
      expect(personInitials(''), '?');
      expect(personInitials('   '), '?');
    });
  });

  group('PersonAvatar', () {
    testWidgets('falls back to initials when there is no photo', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: PersonAvatar(name: 'Rahul Kumar')),
      );
      expect(find.text('RK'), findsOneWidget);
    });

    testWidgets('falls back to initials when the photo file is missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PersonAvatar(
            name: 'Rahul Kumar',
            photoPath: '${Directory.systemTemp.path}/does_not_exist_123.jpg',
          ),
        ),
      );
      expect(find.text('RK'), findsOneWidget);
    });
  });
}
