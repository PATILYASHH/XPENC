import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/layout/masonry.dart';

/// The PC dashboard's two columns (see `_DesktopDashboard`): each widget goes
/// to the shorter side, so widgets that turn out empty — most of them, on a
/// new ledger — never leave one column bare.
void main() {
  Future<List<Rect>> layout(
    WidgetTester tester,
    List<double> heights, {
    double width = 800,
  }) async {
    final keys = [for (var i = 0; i < heights.length; i++) GlobalKey()];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: Masonry(
              gap: 20,
              children: [
                for (var i = 0; i < heights.length; i++)
                  SizedBox(key: keys[i], height: heights[i]),
              ],
            ),
          ),
        ),
      ),
    );
    return [for (final k in keys) tester.getRect(find.byKey(k))];
  }

  testWidgets('two equal columns split by the gap', (tester) async {
    final rects = await layout(tester, [100, 100]);
    expect(rects[0], const Rect.fromLTWH(0, 0, 390, 100));
    expect(rects[1], const Rect.fromLTWH(410, 0, 390, 100));
  });

  testWidgets('each child takes the shorter column', (tester) async {
    final rects = await layout(tester, [300, 100, 100, 100]);
    // Left is taller after the first, so the next two stack on the right.
    expect(rects[1].left, 410);
    expect(rects[2], const Rect.fromLTWH(410, 100, 390, 100));
    expect(rects[3], const Rect.fromLTWH(410, 200, 390, 100));
  });

  testWidgets('empty children cost no room and unbalance nothing', (
    tester,
  ) async {
    // Alternating left/right would have put both real widgets on the right.
    final rects = await layout(tester, [0, 120, 0, 120]);
    expect(rects[1].top, 0);
    expect(rects[3].top, 0);
    expect({rects[1].left, rects[3].left}, {0.0, 410.0});
  });

  testWidgets('is as tall as its tallest column', (tester) async {
    await layout(tester, [300, 100, 50]);
    expect(tester.getSize(find.byType(Masonry)).height, 300);
  });
}
