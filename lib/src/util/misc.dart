import 'package:flutter/widgets.dart';

bool Function(dynamic) returnTrue = (_) => true;
bool Function(dynamic) returnFalse = (_) => false;
dynamic Function(dynamic) returnNull = (_) => null;

void addPostFrame(VoidCallback cb) =>
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) => cb());

extension StateExtension on State {
  bool contains(Offset point) =>
      findRenderBox()?.getGeometry().contains(point) ?? false;
  RenderBox? findRenderBox() =>
      mounted ? context.findRenderObject() as RenderBox? : null;
  Rect? computeGeometry([Offset offset = Offset.zero]) =>
      findRenderBox()?.getGeometry(offset);
}

extension RenderBoxExtension on RenderBox {
  Rect getGeometry([Offset offset = Offset.zero]) =>
      localToGlobal(offset) & size;
}

extension ScrollPositionExtension on ScrollPosition {
  bool get reverse => axisDirection.reverse;
  bool get vertical => axisDirection.vertical;
  Axis get axis => axisDirection.axis;
  double get relativePixels => reverse ? -pixels : pixels;
  Offset toRelativeOffset() =>
      vertical ? Offset(0, relativePixels) : Offset(relativePixels, 0);
}

extension AxisDirectionExtension on AxisDirection {
  Axis get axis => axisDirectionToAxis(this);
  bool get vertical => axis == Axis.vertical;
  bool get reverse => this == AxisDirection.up || this == AxisDirection.left;
}

extension ScrollControllerExtension on ScrollController {
  ScrollableState? get scrollableState =>
      hasClients ? position.context as ScrollableState : null;
  RenderBox? findScrollableRenderBox() => scrollableState?.findRenderBox();
  Offset? get scrollableLocation =>
      findScrollableRenderBox()?.localToGlobal(Offset.zero);
  Offset? get scrollOffset => position.toRelativeOffset();
  bool get reverse => position.reverse;
  bool get vertical => position.vertical;
  AxisDirection get axisDirection => position.axisDirection;
  Axis get axis => position.axis;
}
