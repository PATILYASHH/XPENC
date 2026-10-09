import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/app_icons.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/widgets/app_surfaces.dart';
import 'package:xpenc/core/widgets/custom_icon_badge.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/accounts/add_account_sheet.dart';
import 'package:xpenc/features/categories/categories_screen.dart';

/// GitHub #102: Categories (and anywhere else an icon is chosen) should offer
/// every icon in `AppIcons`, filterable by search, with recently-picked icons
/// surfaced up top. Covers the shared `showIconPickerSheet` sheet through
/// both callers that wire it up.
///
/// Follows the three rules from test/smoke_test.dart: DB work inside
/// `runAsync`, never `pumpAndSettle`, unmount before the test ends.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> settleSheet(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets(
    'Add Account sheet: the icon field searches, picks, and remembers '
    'frequently used icons',
    (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showAddAccountSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);

      // Open the icon picker from the account sheet's own "Icon" field.
      await tester.tap(find.text('Tap to change'));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Search icons'), findsOneWidget);

      // Emoji are a category-only option — nothing that draws an account
      // icon knows how to render one.
      expect(find.byKey(const Key('iconPickerAddEmoji')), findsNothing);

      // No icon has ever been picked yet, so there's nothing to surface.
      expect(find.text('Frequently used'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('iconPickerSearch')),
        'coffee',
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Results'), findsOneWidget);
      expect(find.byIcon(Icons.coffee_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.coffee_outlined));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);

      // Back on the account sheet, the field now previews the chosen icon.
      expect(find.text('Search icons'), findsNothing);
      expect(find.byIcon(Icons.coffee_outlined), findsOneWidget);

      await tester.runAsync(() async {
        final settings = await db.getSettings();
        expect(settings.frequentIconKeys, 'coffee');
      });

      // Reopening the picker now surfaces coffee under "Frequently used".
      await tester.tap(find.text('Tap to change'));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Frequently used'), findsOneWidget);
      // 3, not 2: the "Frequently used" row, the "All icons" row, and the
      // account sheet's own field preview underneath — still mounted below
      // this stacked modal sheet.
      expect(find.byIcon(Icons.coffee_outlined), findsNWidgets(3));

      await unmount(tester);
    },
  );

  testWidgets(
    'Category editor: the icon field opens the same searchable picker',
    (tester) async {
      await pump(tester, const CategoriesScreen());
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('New category'));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('New category'), findsOneWidget);

      await tester.tap(find.text('Tap to change'));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Search icons'), findsOneWidget);
      expect(find.text('All icons'), findsOneWidget);

      await unmount(tester);
    },
  );

  test('AppIcons: an emoji key round-trips and never reads as an icon', () {
    final key = AppIcons.encodeEmoji('🍕');
    expect(AppIcons.emojiOf(key), '🍕');
    expect(AppIcons.emojiOf('coffee'), isNull);
    expect(AppIcons.emojiOf('emoji:'), isNull);
    expect(AppIcons.emojiOf(null), isNull);
    expect(AppIcons.resolve(key), AppIcons.fallback);
  });

  testWidgets(
    'Category editor: an emoji typed in the picker becomes the category icon',
    (tester) async {
      await pump(tester, const CategoriesScreen());

      await tester.tap(find.byTooltip('New category'));
      await settleSheet(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Pizza');

      await tester.tap(find.text('Tap to change'));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Emoji'), findsOneWidget);

      await tester.tap(find.byKey(const Key('iconPickerAddEmoji')));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byKey(const Key('emojiInputField')), '🍕');
      await tester.pump();
      await tester.tap(find.text('Done'));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);

      // Both sheets are gone and the editor's icon field previews the emoji.
      expect(find.text('Search icons'), findsNothing);
      expect(find.text('🍕'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);

      await tester.runAsync(() async {
        final all = await db.watchAllCategories().first;
        expect(all.singleWhere((c) => c.name == 'Pizza').iconKey, 'emoji:🍕');
        final settings = await db.getSettings();
        expect(settings.frequentIconKeys, 'emoji:🍕');
      });

      await unmount(tester);
    },
  );

  testWidgets('KeyIcon and IconWell.forKey draw an emoji key as the emoji', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Column(
            children: [
              KeyIcon('emoji:🍕', size: 20),
              KeyIcon('coffee', size: 20),
            ],
          ),
        ),
      ),
    );
    expect(find.text('🍕'), findsOneWidget);
    expect(find.byIcon(Icons.coffee_outlined), findsOneWidget);
    expect(tester.getSize(find.byType(EmojiGlyph)), const Size(20, 20));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: IconWell.forKey('emoji:🧾', size: 22)),
      ),
    );
    expect(find.text('🧾'), findsOneWidget);
    expect(find.byIcon(AppIcons.fallback), findsNothing);
  });
}
