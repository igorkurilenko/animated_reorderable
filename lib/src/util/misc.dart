import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

void addPostFrame(VoidCallback cb) =>
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) => cb());

extension AnimationStatusExtension on AnimationStatus {
  bool get idle => !animating;
  bool get animating =>
      this == AnimationStatus.forward || this == AnimationStatus.reverse;
}

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
  bool get reverse => axisDirection.reverse;
  bool get vertical => axisDirection.vertical;
  double get relativePixels => reverse ? -pixels : pixels;
  Offset toRelativeOffset() =>
      vertical ? Offset(0, relativePixels) : Offset(relativePixels, 0);
}

extension AxisDirectionExtension on AxisDirection {
  Axis get axis => axisDirectionToAxis(this);
  bool get vertical => axis == Axis.vertical;
  bool get reverse => this == AxisDirection.up || this == AxisDirection.left;
}

extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
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

MultiDragGestureRecognizer createHorizontalSwipeToRemoveDragGestureRecognizer(
  BuildContext context,
) =>
    HorizontalMultiDragGestureRecognizer()
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);

MultiDragGestureRecognizer createVerticalSwipeToRemoveGestureRecognizer(
  BuildContext context,
) =>
    VerticalMultiDragGestureRecognizer()
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);

MultiDragGestureRecognizer createImmediateGestureRecognizer(
  BuildContext context,
) =>
    ImmediateMultiDragGestureRecognizer()
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
