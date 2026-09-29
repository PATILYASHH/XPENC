import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/routing/hold_menu_geometry.dart';
import 'package:xpenc/core/routing/quick_actions.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

void main() {
  group('parseHoldMenuSlots', () {
    test('an 8-slot value passes through unchanged', () {
      final raw = 'stats,,calc-gst,,,,template:4,';
      expect(parseHoldMenuSlots(raw), raw.split(','));
    });

    test('a pre-radial 3-item value maps into the upper slots', () {
      final slots = parseHoldMenuSlots('calendar,budgets,stats');
      expect(slots, hasLength(holdMenuSlotCount));
      expect(slots[7], 'calendar'); // up-left
      expect(slots[0], 'budgets'); // up
      expect(slots[1], 'stats'); // up-right
      expect(slots.where((s) => s.isNotEmpty), hasLength(3));
    });

    test('anything else falls back to all empty', () {
      expect(parseHoldMenuSlots(''), List.filled(holdMenuSlotCount, ''));
      expect(parseHoldMenuSlots('a,b'), List.filled(holdMenuSlotCount, ''));
    });
  });

  group('resolveQuickAction', () {
    final template = TransactionTemplateRow(
      id: 4,
      name: 'Rent',
      type: TxType.expense,
      amount: Money.fromRupees(12000),
      accountId: 1,
      createdAt: DateTime(2026),
    );

    test('module and calculator ids resolve to their routes', () {
      expect(
        resolveQuickAction('stats', templates: const [], mode: AppMode.pro)
            ?.route,
        '/more/stats',
      );
      expect(
        resolveQuickAction('calc-gst', templates: const [], mode: AppMode.pro)
            ?.route,
        '/more/calculators/gst',
      );
    });

    test('a template id opens Add prefilled from it', () {
      final spec = resolveQuickAction(
        'template:4',
        templates: [template],
        mode: AppMode.pro,
      );
      expect(spec?.label, 'Rent');
      expect(spec?.route, '/add?template=4');
    });

    test('empty, unknown, deleted-template and Basic-hidden are empty', () {
      for (final id in ['', 'nope', 'template:99']) {
        expect(
          resolveQuickAction(id, templates: [template], mode: AppMode.pro),
          isNull,
          reason: id,
        );
      }
      expect(
        resolveQuickAction('budgets', templates: const [], mode: AppMode.basic),
        isNull,
      );
    });

    test('every catalog id is unique', () {
      final ids = quickActionCatalog.map((s) => s.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  group('radial hit-testing', () {
    const origin = Offset(200, 800);
    int hovered(Offset delta) => holdMenuHoveredIndex(
      origin: origin,
      pointer: origin + delta,
      anglesDegrees: holdMenuSlotAngles,
      activationRadius: 22,
      optionCount: holdMenuSlotCount,
    );

    test('each compass direction picks its own slot', () {
      expect(hovered(const Offset(0, -40)), 0); // up
      expect(hovered(const Offset(30, -30)), 1); // up-right
      expect(hovered(const Offset(40, 0)), 2); // right
      expect(hovered(const Offset(30, 30)), 3); // down-right
      expect(hovered(const Offset(0, 40)), 4); // down
      expect(hovered(const Offset(-30, 30)), 5); // down-left
      expect(hovered(const Offset(-40, 0)), 6); // left
      expect(hovered(const Offset(-30, -30)), 7); // up-left
    });

    test('staying near the start is the centre (cancel)', () {
      expect(hovered(const Offset(5, -10)), -1);
    });
  });

  group('setHoldMenuSlots', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('stores 8 slots, empties included', () async {
      final slots = ['stats', '', 'calc-gst', '', '', '', 'template:4', ''];
      await db.setHoldMenuSlots(slots);
      final s = await db.select(db.settings).getSingle();
      expect(parseHoldMenuSlots(s.holdMenuSlots), slots);
    });

    test('rejects the wrong count, duplicates and malformed ids', () {
      expect(() => db.setHoldMenuSlots(['stats']), throwsArgumentError);
      expect(
        () => db.setHoldMenuSlots(['stats', 'stats', '', '', '', '', '', '']),
        throwsArgumentError,
      );
      expect(
        () => db.setHoldMenuSlots(['Bad Id', '', '', '', '', '', '', '']),
        throwsArgumentError,
      );
    });
  });
}
