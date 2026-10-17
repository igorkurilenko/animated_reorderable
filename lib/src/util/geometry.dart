import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

extension StateGeometry on State {
  bool contains(Offset point) =>
      findRenderBox()?.getGeometry().contains(point) ?? false;
  RenderBox? findRenderBox() => mounted ? context.findRenderBox() : null;
}

extension BuildContextGeometry on BuildContext {
  RenderBox? findRenderBox() => findRenderObject() as RenderBox?;
}

extension RenderBoxGeometry on RenderBox {
  Rect getGeometry() => localToGlobal(Offset.zero) & size;
}

extension ScrollPositionOffset on ScrollPosition {
  /// The scroll offset as the distance the content moved on the screen.
  Offset toRelativeOffset() {
    final pixels = axisDirectionIsReversed(axisDirection)
        ? -this.pixels
        : this.pixels;
    return switch (axisDirectionToAxis(axisDirection)) {
      Axis.vertical => Offset(0, pixels),
      Axis.horizontal => Offset(pixels, 0),
    };
  }
}

extension SliverGridGeometrySize on SliverGridGeometry {
  Size toSize(Axis axis) => axis == Axis.vertical
      ? Size(crossAxisExtent, mainAxisExtent)
      : Size(mainAxisExtent, crossAxisExtent);
}

extension SliverGridLayoutChildSize on SliverGridLayout {
  Size getChildSize(int index, Axis axis) =>
      getGeometryForChildIndex(index).toSize(axis);
}
