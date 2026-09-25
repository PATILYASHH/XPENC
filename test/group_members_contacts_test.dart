import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/persons/contact_import.dart';
import 'package:xpenc/features/persons/group_member_picker_sheet.dart';

/// Group members can come from archived people and phone contacts; a newly
/// added archived member returns to the Individual list, and an existing
/// person can be linked to a contact for their photo and phone.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<PersonRow> personById(int id) =>
      (db.select(db.persons)..where((p) => p.id.equals(id))).getSingle();

  group('setGroupMembers', () {
    test('adding an archived person to a group brings them back', () async {
      final ravi = await db.addPerson('Ravi');
      await db.archivePerson(ravi);
      final trip = await db.addGroup('Trip');

      await db.setGroupMembers(trip, {ravi});

      expect((await personById(ravi)).isArchived, isFalse);
      expect((await db.watchPersons().first).map((p) => p.id), contains(ravi));
    });

    test('re-saving a group keeps an already-member archived person '
        'archived', () async {
      final ravi = await db.addPerson('Ravi');
      final sita = await db.addPerson('Sita');
      final trip = await db.addGroup('Trip');
      await db.setGroupMembers(trip, {ravi});
      await db.archivePerson(ravi);

      // Only Sita is new here.
      await db.setGroupMembers(trip, {ravi, sita});

      expect((await personById(ravi)).isArchived, isTrue);
    });
  });

  test('linkPersonContact fills phone and photo, keeps the name and never '
      'clears a field it has no value for', () async {
    final id = await db.addPerson('Ravi Bhai', phone: '11111 22222');

    await db.linkPersonContact(id, photoPath: '/photos/ravi.jpg');
    var p = await personById(id);
    expect(p.name, 'Ravi Bhai');
    expect(p.phone, '11111 22222', reason: 'no phone given: left alone');
    expect(p.photoPath, '/photos/ravi.jpg');

    await db.linkPersonContact(id, phone: '+91 98765 43210');
    p = await personById(id);
    expect(p.phone, '+91 98765 43210');
    expect(p.photoPath, '/photos/ravi.jpg');
  });

  group('matchExistingPerson', () {
    PickedContact contact({String? name, String? phone}) =>
        (name: name, phone: phone, photoPath: null, detailsAllowed: true);

    test('matches the same number written differently', () async {
      final id = await db.addPerson('Ravi', phone: '098765 43210');
      final people = await db.watchPersons().first;
      final match = matchExistingPerson(
        contact(name: 'Ravi Kumar', phone: '+91 98765-43210'),
        people,
      );
      expect(match?.id, id);
    });

    test(
      'falls back to the same name, ignoring case, archived included',
      () async {
        final id = await db.addPerson('Sita');
        await db.archivePerson(id);
        final everyone = [
          ...await db.watchPersons().first,
          ...await db.watchArchivedPersons().first,
        ];
        expect(matchExistingPerson(contact(name: 'sita'), everyone)?.id, id);
      },
    );

    test('someone new matches nobody', () async {
      await db.addPerson('Ravi', phone: '9876543210');
      final people = await db.watchPersons().first;
      expect(
        matchExistingPerson(contact(name: 'Amit', phone: '9123456780'), people),
        isNull,
      );
    });
  });

  testWidgets('the member picker lists archived people and returns them '
      'when chosen', (tester) async {
    late int ravi;
    late int sita;
    await tester.runAsync(() async {
      ravi = await db.addPerson('Ravi');
      sita = await db.addPerson('Sita');
      await db.archivePerson(sita);
    });
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Set<int>? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await showModalBottomSheet<Set<int>>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) =>
                          const GroupMemberPickerSheet(initiallySelected: {}),
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Add from contacts'), findsOneWidget);
    expect(find.text('ARCHIVED'), findsOneWidget);
    await tester.tap(find.text('Ravi'));
    await tester.tap(find.text('Sita'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(result, {ravi, sita});
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
