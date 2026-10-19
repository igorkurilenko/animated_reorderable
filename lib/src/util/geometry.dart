import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

extension StateGeometry on State {
  RenderBox? findRenderBox() => mounted ? context.findRenderBox() : null;
}

extension BuildContextGeometry on BuildContext {
  RenderBox? findRenderBox() => findRenderObject() as RenderBox?;
}

extension RenderBoxGeometry on RenderBox {
  Rect getGeometry() => localToGlobal(Offset.zero) & size;
}

extension AxisDirectionOffset on AxisDirection {
  /// [pixels] along this direction, as an offset on the screen.
  Offset offsetOf(double pixels) => switch (this) {
    AxisDirection.down => Offset(0, pixels),
    AxisDirection.up => Offset(0, -pixels),
    AxisDirection.right => Offset(pixels, 0),
    AxisDirection.left => Offset(-pixels, 0),
  };
}

extension ScrollPositionOffset on ScrollPosition {
  /// The scroll offset as the distance the content moved on the screen.
  Offset toRelativeOffset() => axisDirection.offsetOf(pixels);
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
