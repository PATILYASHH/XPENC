import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/more/more_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> unmount(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('MoreScreen displays search bar when search is active and filters items',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MoreScreen(),
        ),
      ),
    );
    await tester.pump();

    // Inactive by default
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);

    // Activate search
    container.read(moreSearchActiveProvider.notifier).state = true;
    await tester.pump();

    // Now search bar is visible
    expect(find.byType(TextField), findsOneWidget);

    // Filter for "Backup"
    container.read(moreSearchQueryProvider.notifier).state = 'Backup';
    await tester.pump();

    // "Backup & Restore" should be visible
    expect(find.text('Backup & Restore'), findsOneWidget);
    // "Accounts" should be filtered out
    expect(find.text('Accounts'), findsNothing);

    // Filter with non-existent query
    container.read(moreSearchQueryProvider.notifier).state = 'xyznonexistent';
    await tester.pump();
    expect(find.text('No matching options found'), findsOneWidget);

    // Deactivate search
    container.read(moreSearchActiveProvider.notifier).state = false;
    await tester.pump();

    // Search bar hidden, original items restored
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Accounts'), findsOneWidget);

    await unmount(tester);
  });
}
