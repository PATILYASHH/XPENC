import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/app_icons.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/platform/outgoing_file.dart';
import 'package:xpenc/data/built_in_category_templates.dart';
import 'package:xpenc/data/category_template_file.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/categories/category_templates_screen.dart';

/// #187: category templates travel as files — share one, import one — and
/// 50/30/20 comes ready-made.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<CategoryRow>> active(CategoryKind kind) =>
      db.watchCategories(kind).first;

  group('the file', () {
    test('a saved template survives a round trip as a file', () async {
      final food = (await active(
        CategoryKind.expense,
      )).firstWhere((c) => c.name == 'Food').id;
      await db.addCategory(
        name: 'Eating out',
        kind: CategoryKind.expense,
        colorValue: 0xFFF97316,
        iconKey: 'pizza',
        parentId: food,
      );
      final id = await db.saveCategoriesAsTemplate('Mine');
      final text = (await db.exportCategoryTemplate(id)).encode();

      final copy = CategoryTemplateFile.decode(text);
      expect(copy.name, 'Mine');
      final foodCopy = copy.expense.firstWhere((c) => c.name == 'Food');
      expect(foodCopy.children.single.name, 'Eating out');
      expect(foodCopy.children.single.iconKey, 'pizza');
      expect(foodCopy.children.single.colorValue, 0xFFF97316);
      expect(copy.income.map((c) => c.name), contains('Salary'));

      final importedId = await db.importCategoryTemplate(copy);
      final before = await db.watchCategoryTemplateItems(id).first;
      final after = await db.watchCategoryTemplateItems(importedId).first;
      expect(after.length, before.length);
    });

    test('it carries the structure and nothing else', () async {
      final id = await db.saveCategoriesAsTemplate('Mine');
      final json =
          jsonDecode((await db.exportCategoryTemplate(id)).encode()) as Map;
      expect(json.keys.toSet(), {
        'format',
        'version',
        'name',
        'income',
        'expense',
      });
      final first = (json['expense'] as List).first as Map;
      expect(first.keys.toSet(), {'name', 'icon', 'color'});
      expect(first['color'], matches(RegExp(r'^#[0-9A-F]{6}$')));
    });

    test('anything that isn\'t a template is turned away', () {
      void rejects(String text, String message) => expect(
        () => CategoryTemplateFile.decode(text),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(message),
          ),
        ),
      );
      rejects('not json', "isn't an XPENC category template");
      rejects('{"format":"xpenc-backup"}', "isn't an XPENC category template");
      rejects(
        '{"format":"xpenc-category-template","version":9,"expense":[]}',
        'newer XPENC',
      );
      rejects(
        '{"format":"xpenc-category-template","version":1}',
        'no categories',
      );
      rejects(
        '{"format":"xpenc-category-template","version":1,"expense":'
            '[{"name":"A","children":[{"name":"B","children":[{"name":"C"}]}]}]}',
        'two levels',
      );
      rejects(
        '{"format":"xpenc-category-template","version":1,"expense":[{}]}',
        'needs a name',
      );
    });

    test('a missing icon or colour falls back instead', () {
      final file = CategoryTemplateFile.decode(
        '{"format":"xpenc-category-template","version":1,'
        '"expense":[{"name":"Pets","color":"teal"}]}',
      );
      expect(file.name, 'Shared template');
      expect(file.expense.single.iconKey, 'other');
      expect(file.expense.single.colorValue, 0xFF64748B);
    });
  });

  group('50/30/20', () {
    final template = kBuiltInCategoryTemplates.single;

    test('uses only icons XPENC has', () {
      final known = AppIcons.allKeys.toSet();
      for (final c in [...template.income, ...template.expense]) {
        expect(known, contains(c.iconKey), reason: c.name);
        for (final child in c.children) {
          expect(known, contains(child.iconKey), reason: child.name);
        }
      }
    });

    test('switching to it moves the categories you have into place', () async {
      final rent = (await active(
        CategoryKind.expense,
      )).firstWhere((c) => c.name == 'Rent');
      final cash = (await db.watchAccounts().first).single.id;
      final txId = await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(12000),
        accountId: cash,
        categoryId: rent.id,
        date: DateTime(2026, 11, 1),
      );
      final incomeBefore = {
        for (final c in await active(CategoryKind.income)) c.id,
      };

      final id = await db.importCategoryTemplate(template);
      await db.applyCategoryTemplate(id);

      final expense = await active(CategoryKind.expense);
      final needs = expense.firstWhere((c) => c.name == 'Needs');
      final rents = expense.where((c) => c.name == 'Rent').toList();
      expect(rents, hasLength(1), reason: 'no second Rent');
      expect(rents.single.id, rent.id, reason: 'the same Rent, moved');
      expect(rents.single.parentId, needs.id);
      expect((await db.transactionById(txId))!.categoryId, rent.id);
      expect({
        for (final c in await active(CategoryKind.income)) c.id,
      }, incomeBefore);
    });
  });

  group('the screen', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: const MaterialApp(home: CategoryTemplatesScreen()),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    Future<void> unmount(WidgetTester tester) async {
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a ready-made template is a tap away', (tester) async {
      await pump(tester);
      expect(find.text('50/30/20'), findsOneWidget);
      // Scrolled clear of the ➕, as on a phone.
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 150));
      }
      final saved = await tester.runAsync(
        () => db.watchCategoryTemplates().first,
      );
      expect(saved!.single.name, '50/30/20');
      // Saved, not switched to.
      final rent = await tester.runAsync(
        () async => (await active(
          CategoryKind.expense,
        )).firstWhere((c) => c.name == 'Rent'),
      );
      expect(rent!.parentId, isNull);
      await unmount(tester);
    });

    testWidgets('More templates opens xpenc.in/templates', (tester) async {
      await pump(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      await tester.tap(find.text('More templates on xpenc.in'));
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 150));
      }
      // No browser in a test, so openLink falls back to copying the link.
      expect(find.text('Copied — https://xpenc.in/templates'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Share as file hands over the template\'s JSON', (
      tester,
    ) async {
      await tester.runAsync(() => db.saveCategoriesAsTemplate('Mine'));
      OutgoingFile? sent;
      OutgoingFile.debugDeliver = (file, _) async => sent = file;
      addTearDown(() => OutgoingFile.debugDeliver = null);
      await pump(tester);

      await tester.tap(
        find.byWidgetPredicate((w) => w is PopupMenuButton).first,
      );
      // Let the menu finish opening.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Share as file'));
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 150));
      }

      expect(sent, isNotNull);
      expect(sent!.name, 'Mine - XPENC categories.json');
      final file = CategoryTemplateFile.decode(utf8.decode(sent!.bytes));
      expect(file.name, 'Mine');
      await unmount(tester);
    });
  });
}
