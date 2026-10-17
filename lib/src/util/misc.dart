import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

void addPostFrame(VoidCallback cb) =>
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) => cb());

extension StateExtension on State {
  bool contains(Offset point) =>
      findRenderBox()?.getGeometry().contains(point) ?? false;
  RenderBox? findRenderBox() => mounted ? context.findRenderBox() : null;
  void rebuild([VoidCallback? cb]) {
    if (!mounted) return;
    // ignore: invalid_use_of_protected_member
    setState(() => cb?.call());
  }
}

extension BuildContextExtension on BuildContext {
  RenderBox? findRenderBox() => findRenderObject() as RenderBox?;
}

extension RenderBoxExtension on RenderBox {
  Rect getGeometry() => localToGlobal(Offset.zero) & size;
}

extension ScrollPositionExtension on ScrollPosition {
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

extension SliverGridGeometryExtension on SliverGridGeometry {
  Size toSize(Axis axis) => axis == Axis.vertical
      ? Size(crossAxisExtent, mainAxisExtent)
      : Size(mainAxisExtent, crossAxisExtent);
}

extension SliverGridLayoutExtension on SliverGridLayout {
  Size getChildSize(int index, Axis axis) =>
      getGeometryForChildIndex(index).toSize(axis);
}

Widget defaultDraggedItemDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) => ScaleTransition(
  scale: animation
      .drive(CurveTween(curve: Curves.easeInOut))
      .drive(Tween(begin: 1.0, end: 1.05)),
  child: FadeTransition(
    opacity: animation.drive(Tween(begin: 1, end: 0.7)),
    child: child,
  ),
);

MultiDragGestureRecognizer createReorderDragGestureRecognizer(
  BuildContext context,
) =>
    DelayedMultiDragGestureRecognizer()
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);

MultiDragGestureRecognizer createHorizontalSwipeDragGestureRecognizer(
  BuildContext context,
) =>
    HorizontalMultiDragGestureRecognizer()
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);

MultiDragGestureRecognizer createVerticalSwipeDragGestureRecognizer(
  BuildContext context,
) =>
    VerticalMultiDragGestureRecognizer()
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);

MultiDragGestureRecognizer createImmediateDragGestureRecognizer(
  BuildContext context,
) =>
    ImmediateMultiDragGestureRecognizer()
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
