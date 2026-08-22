import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/features/reports/chart_widgets.dart';

class _Rgb {
  const _Rgb(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;
}

/// Verifies the dashboard's budget pie draws what was asked for: a wedge
/// sized by *budget* share, coloured in from the centre only up to the
/// spent/budget fraction of its *area* — not its radius. A category spending
/// exactly half its budget (₹1500 of ₹3000) must have its filled radius at
/// sqrt(0.5) ≈ 70.7% of the wedge's outer radius, not 50%; a naive
/// linear-radius fill would fail this.
void main() {
  const categoryColor = Color(0xFFFF6600);

  /// [RenderRepaintBoundary.toImage] and [ui.Image.toByteData] perform real
  /// GPU/software rasterisation — work the fake clock `testWidgets` runs
  /// under cannot drive. Called directly they never resolve: it hangs
  /// forever (both locally and in CI) instead of failing fast. Running them
  /// through [WidgetTester.runAsync] steps outside the fake async zone so
  /// they can actually complete.
  Future<({ui.Image image, ByteData bytes})> renderSingleSlice(
    WidgetTester tester, {
    required Money budget,
    required Money spent,
  }) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          // Scaffold.backgroundColor paints on the Scaffold's own render
          // object — a sibling of RepaintBoundary's subtree, not a
          // descendant of it — so it never reaches the captured raster.
          // Without this ColoredBox, toImage() captures a transparent
          // backdrop; reading its raw RGBA (ignoring alpha) then reads every
          // unpainted pixel as solid black instead of white.
          body: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: Colors.white,
              child: Center(
                child: BudgetRadialChart(
                  slices: [
                    (
                      label: 'Food',
                      budget: budget,
                      spent: spent,
                      color: categoryColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );

    final result = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (image: image, bytes: bytes!);
    });
    return result!;
  }

  _Rgb pixelAt(ByteData bytes, ui.Image image, Offset p) {
    final x = p.dx.round().clamp(0, image.width - 1);
    final y = p.dy.round().clamp(0, image.height - 1);
    final index = (y * image.width + x) * 4;
    return _Rgb(
      bytes.getUint8(index),
      bytes.getUint8(index + 1),
      bytes.getUint8(index + 2),
    );
  }

  _Rgb rgbOf(Color c) =>
      _Rgb((c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round());

  /// Sum of how far each channel sits from white — 0 for a pixel identical
  /// to the (white) background, large for a fully saturated category colour.
  int distanceFromWhite(_Rgb c) => (255 - c.r) + (255 - c.g) + (255 - c.b);

  final fullColorDistance = distanceFromWhite(rgbOf(categoryColor));

  testWidgets('half-spent budget colours ~71% of the wedge radius, not 50%', (
    tester,
  ) async {
    final (:image, :bytes) = await renderSingleSlice(
      tester,
      budget: Money.fromRupees(3000),
      spent: Money.fromRupees(1500),
    );

    final area = tester.getRect(find.byKey(const Key('budgetRadialPaintArea')));
    final center = area.center;
    final outerRadius = area.shortestSide / 2 - 2;

    // Sample straight down from centre (angle π/2): well inside the single
    // wedge, clear of its start-angle gap.
    _Rgb sampleAtFraction(double f) =>
        pixelAt(bytes, image, center + Offset(0, outerRadius * f));

    final at40pct = sampleAtFraction(0.40);
    final at60pct = sampleAtFraction(0.60); // > 50%, still < sqrt(0.5)≈70.7%
    final at90pct = sampleAtFraction(0.90);

    // Inside the filled radius: solid category colour.
    expect(
      distanceFromWhite(at40pct),
      closeTo(fullColorDistance, 5),
      reason: '40% of the way out should be fully coloured',
    );

    // Past 50% but still under sqrt(0.5) ≈ 70.7% — a linear-radius fill
    // would have stopped colouring by now; the area-correct fill hasn't.
    expect(
      distanceFromWhite(at60pct),
      closeTo(fullColorDistance, 5),
      reason:
          '60% of the way out is still spent budget by area (sqrt(0.5) '
          '≈ 70.7%), so it must still be fully coloured',
    );

    // Past the filled radius: faint tint, nowhere near the solid colour.
    expect(
      distanceFromWhite(at90pct),
      lessThan(fullColorDistance ~/ 3),
      reason:
          '90% of the way out is unspent budget — a faint tint, not '
          'the solid colour',
    );
  });

  testWidgets('fully spent budget colours the whole wedge', (tester) async {
    final (:image, :bytes) = await renderSingleSlice(
      tester,
      budget: Money.fromRupees(2000),
      spent: Money.fromRupees(2000),
    );

    final area = tester.getRect(find.byKey(const Key('budgetRadialPaintArea')));
    final center = area.center;
    final outerRadius = area.shortestSide / 2 - 2;

    final nearEdge = pixelAt(bytes, image, center + Offset(0, outerRadius * 0.95));
    expect(
      distanceFromWhite(nearEdge),
      closeTo(fullColorDistance, 5),
      reason:
          'a budget spent exactly to its cap should colour all the way '
          'to the outer edge',
    );
  });

  testWidgets('no budgeted categories renders the empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BudgetRadialChart(slices: [])),
      ),
    );
    await tester.pump();

    expect(find.text('No data yet'), findsOneWidget);
  });
}
