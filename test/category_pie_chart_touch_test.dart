import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/features/reports/chart_widgets.dart';

// GitHub #192: on the Dashboard's Spending donut, tapping a wedge didn't
// reliably show its name in the centre, and small wedges never did.

const _slices = <({String label, Money value, Color color, int? id})>[
  (label: 'Rent', value: Money(800000), color: Colors.red, id: 1),
  (label: 'Food', value: Money(90000), color: Colors.orange, id: 2),
  (label: 'Fun', value: Money(70000), color: Colors.pink, id: 3),
  (label: 'Bus', value: Money(40000), color: Colors.green, id: 4),
];

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        // The Dashboard puts the donut inside a vertical scroll view, whose
        // drag recognizer competes for every touch on the chart.
        body: ListView(
          children: const [
            SizedBox(height: 120),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: CategoryPieChart(showLegend: false, slices: _slices),
            ),
            SizedBox(height: 1200),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A point inside wedge [index], [radius] px from the donut's centre. The
/// wedges run clockwise from 3 o'clock in the order of [_slices] (already
/// sorted largest first).
Offset _pointIn(WidgetTester tester, int index, {double radius = 80}) {
  final box = tester.getRect(find.byType(CategoryPieChart));
  final center = Offset(box.center.dx, box.top + 110);
  final total = _slices.fold<int>(0, (s, e) => s + e.value.paise).toDouble();
  var start = 0.0;
  for (var i = 0; i < index; i++) {
    start += _slices[i].value.paise / total * 360;
  }
  final mid = start + _slices[index].value.paise / total * 360 / 2;
  final rad = mid * math.pi / 180;
  return center + Offset(math.cos(rad), math.sin(rad)) * radius;
}

void main() {
  testWidgets('a tap on each wedge, big or small, names it in the centre', (
    tester,
  ) async {
    await _pump(tester);
    for (var i = 0; i < _slices.length; i++) {
      await tester.tapAt(_pointIn(tester, i));
      await tester.pumpAndSettle();
      expect(
        find.text(_slices[i].label),
        findsOneWidget,
        reason: 'tapping ${_slices[i].label} should show it',
      );
    }
  });

  testWidgets('picking a wedge doesn\'t shrink the tappable area', (
    tester,
  ) async {
    await _pump(tester);
    final chart = find.byType(CategoryPieChart);
    final area = find.descendant(
      of: chart,
      matching: find.byType(GestureDetector),
    );
    final before = tester.getRect(area);
    await tester.tapAt(_pointIn(tester, 0));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsOneWidget);
    // It used to collapse to the 84px centre label's width.
    expect(tester.getRect(area), before);
    expect(before.width, tester.getRect(chart).width);
  });

  testWidgets('the label stays after the finger lifts', (tester) async {
    await _pump(tester);
    final gesture = await tester.startGesture(_pointIn(tester, 0));
    await tester.pump(const Duration(milliseconds: 60));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsOneWidget);
  });

  testWidgets('a slow tap (finger held a moment) still sticks', (tester) async {
    await _pump(tester);
    final gesture = await tester.startGesture(_pointIn(tester, 2));
    await tester.pump(const Duration(milliseconds: 250));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Fun'), findsOneWidget);
  });

  testWidgets('a slightly wobbly tap still selects', (tester) async {
    await _pump(tester);
    final p = _pointIn(tester, 1);
    final gesture = await tester.startGesture(p);
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.moveBy(const Offset(3, 4));
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsOneWidget);
  });

  testWidgets('tapping the same wedge again keeps it; the hole clears it', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tapAt(_pointIn(tester, 0));
    await tester.pumpAndSettle();
    await tester.tapAt(_pointIn(tester, 0));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsOneWidget);

    await tester.tapAt(_pointIn(tester, 0, radius: 10));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsNothing);
  });

  testWidgets('a tap just past a thin wedge\'s edge still lands on it', (
    tester,
  ) async {
    await _pump(tester);
    // Bus is ~4% (≈14°). Aim at its outer rim, where a finger usually lands,
    // and a few degrees past its far edge.
    final box = tester.getRect(find.byType(CategoryPieChart));
    final center = Offset(box.center.dx, box.top + 110);
    const deg = 362.0; // Bus ends at 360°; 2° past it, into Rent's start.
    final rad = deg * math.pi / 180;
    await tester.tapAt(center + Offset(math.cos(rad), math.sin(rad)) * 112);
    await tester.pumpAndSettle();
    expect(find.text('Bus'), findsOneWidget);
  });

  testWidgets('dragging across the chart scrolls instead of selecting', (
    tester,
  ) async {
    await _pump(tester);
    await tester.dragFrom(_pointIn(tester, 0), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsNothing);
  });
}
