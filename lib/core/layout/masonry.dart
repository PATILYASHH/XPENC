import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Children in [columns] equal columns, each placed in whichever column is
/// shortest so far — so a child that turns out empty (a dashboard widget
/// with nothing to show) costs no room, and the columns stay even however
/// tall each child is. Order is kept as far as that allows: the first child
/// goes top left, the next to the shorter side, and so on.
class Masonry extends MultiChildRenderObjectWidget {
  const Masonry({
    required super.children,
    this.columns = 2,
    this.gap = 0,
    super.key,
  }) : assert(columns > 0);

  final int columns;

  /// Horizontal space between columns.
  final double gap;

  @override
  RenderMasonry createRenderObject(BuildContext context) =>
      RenderMasonry(columns: columns, gap: gap);

  @override
  void updateRenderObject(BuildContext context, RenderMasonry renderObject) {
    renderObject
      ..columns = columns
      ..gap = gap;
  }
}

class MasonryParentData extends ContainerBoxParentData<RenderBox> {}

class RenderMasonry extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, MasonryParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MasonryParentData> {
  RenderMasonry({required int columns, required double gap})
    : _columns = columns,
      _gap = gap;

  int _columns;
  int get columns => _columns;
  set columns(int value) {
    if (value == _columns) return;
    _columns = value;
    markNeedsLayout();
  }

  double _gap;
  double get gap => _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MasonryParentData) {
      child.parentData = MasonryParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final columnWidth = math.max(0.0, (width - gap * (columns - 1)) / columns);
    final heights = List.filled(columns, 0.0);
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as MasonryParentData;
      child.layout(
        BoxConstraints.tightFor(width: columnWidth),
        parentUsesSize: true,
      );
      var shortest = 0;
      for (var c = 1; c < columns; c++) {
        if (heights[c] < heights[shortest]) shortest = c;
      }
      data.offset = Offset(shortest * (columnWidth + gap), heights[shortest]);
      heights[shortest] += child.size.height;
      child = data.nextSibling;
    }
    size = constraints.constrain(Size(width, heights.reduce(math.max)));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
