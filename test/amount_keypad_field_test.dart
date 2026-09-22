import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/widgets/amount_keypad_field.dart';

/// GitHub #135: every `Money` amount field should open this in-app keypad
/// instead of the OS keyboard. These tests cover the widget's own behavior
/// (buffer editing already has its own coverage in amount_buffer_test.dart);
/// long-press-repeat backspace timing is asserted loosely (a range, not an
/// exact tick count) since exact `Timer` fire counts inside one big
/// `pump(duration)` leap aren't worth pinning to a specific Flutter version.
void main() {
  Future<void> pumpField(
    WidgetTester tester, {
    required AmountKeypadController controller,
    List<FocusNode> yieldTo = const [],
    bool autofocus = false,
    FocusNode? otherFieldFocus,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AmountKeypadField(
                controller: controller,
                label: 'Amount',
                autofocus: autofocus,
                yieldTo: yieldTo,
                displayKey: const Key('amountDisplay'),
              ),
              if (otherFieldFocus != null) TextField(focusNode: otherFieldFocus),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('tapping the field opens the keypad', (tester) async {
    final controller = AmountKeypadController();
    await pumpField(tester, controller: controller);

    expect(find.text('1'), findsNothing);
    await tester.tap(find.byKey(const Key('amountDisplay')));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('digit taps append to the buffer and update the display', (
    tester,
  ) async {
    final controller = AmountKeypadController();
    await pumpField(tester, controller: controller, autofocus: true);

    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('5'));
    await tester.pump();

    expect(controller.text, '15');
    expect(find.text('15'), findsOneWidget);
  });

  testWidgets('decimal point caps at two fraction digits', (tester) async {
    final controller = AmountKeypadController();
    await pumpField(tester, controller: controller, autofocus: true);

    for (final k in ['1', '2', '.', '3', '4', '5']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }

    expect(controller.text, '12.34');
  });

  testWidgets('backspace key removes the last character', (tester) async {
    final controller = AmountKeypadController(text: '12');
    await pumpField(tester, controller: controller, autofocus: true);

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();

    expect(controller.text, '1');
  });

  testWidgets('holding backspace auto-repeats, releasing stops it', (
    tester,
  ) async {
    final controller = AmountKeypadController(text: '123456789012');
    await pumpField(tester, controller: controller, autofocus: true);
    final before = controller.text.length;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.backspace_outlined)),
    );
    // Past long-press recognition (~500ms) + initial repeat delay (~400ms)
    // + a few 120ms repeat ticks — comfortably enough for several deletes.
    await tester.pump(const Duration(milliseconds: 1400));
    await gesture.up();
    await tester.pump();

    final after = controller.text.length;
    expect(
      after,
      lessThan(before - 1),
      reason: 'holding should delete more than a single tap would',
    );
    expect(
      after,
      greaterThan(0),
      reason: 'the repeat timer must stop on release, not run forever',
    );

    // No extra delete from the tap-recognizer firing on release after a
    // long press was already recognized.
    final afterRelease = controller.text.length;
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.text.length, afterRelease);
  });

  testWidgets('setAmount marks the buffer fresh so the next tap replaces it', (
    tester,
  ) async {
    final controller = AmountKeypadController()
      ..setAmount(const Money.fromPaise(1544)); // "15.44", GitHub #45
    await pumpField(tester, controller: controller, autofocus: true);

    await tester.tap(find.text('7'));
    await tester.pump();

    expect(controller.text, '7');
  });

  testWidgets('focusing a yieldTo field collapses the keypad', (tester) async {
    final controller = AmountKeypadController();
    final noteFocus = FocusNode();
    addTearDown(noteFocus.dispose);

    await pumpField(
      tester,
      controller: controller,
      autofocus: true,
      yieldTo: [noteFocus],
      otherFieldFocus: noteFocus,
    );
    expect(find.text('1'), findsOneWidget);

    noteFocus.requestFocus();
    await tester.pump();

    expect(find.text('1'), findsNothing);
  });

  testWidgets('tapping the field again after yielding reopens the keypad', (
    tester,
  ) async {
    final controller = AmountKeypadController();
    final noteFocus = FocusNode();
    addTearDown(noteFocus.dispose);

    await pumpField(
      tester,
      controller: controller,
      autofocus: true,
      yieldTo: [noteFocus],
      otherFieldFocus: noteFocus,
    );
    noteFocus.requestFocus();
    await tester.pump();
    expect(find.text('1'), findsNothing);

    await tester.tap(find.byKey(const Key('amountDisplay')));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  group('AmountKeypadFieldGroup — sheets with more than one money field', () {
    Future<void> pumpTwoFields(
      WidgetTester tester, {
      required AmountKeypadController first,
      required AmountKeypadController second,
      required AmountKeypadFieldGroup group,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AmountKeypadField(
                  controller: first,
                  label: 'Amount',
                  group: group,
                  displayKey: const Key('firstDisplay'),
                ),
                AmountKeypadField(
                  controller: second,
                  label: 'Promo amount',
                  group: group,
                  displayKey: const Key('secondDisplay'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('opening one field closes the other', (tester) async {
      final first = AmountKeypadController();
      final second = AmountKeypadController();
      final group = AmountKeypadFieldGroup();
      addTearDown(group.dispose);

      await pumpTwoFields(tester, first: first, second: second, group: group);

      await tester.tap(find.byKey(const Key('firstDisplay')));
      await tester.pump();
      expect(find.byType(AmountKeypadGrid), findsOneWidget);

      await tester.tap(find.byKey(const Key('secondDisplay')));
      await tester.pump();
      expect(find.byType(AmountKeypadGrid), findsOneWidget);

      // Digits now land in the second field, not the first.
      await tester.tap(find.text('9'));
      await tester.pump();
      expect(second.text, '9');
      expect(first.text, '');
    });
  });
}
