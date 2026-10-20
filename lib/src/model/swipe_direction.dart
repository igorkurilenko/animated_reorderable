import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../util/gesture_recognizers.dart';
import 'coordinates.dart';

/// The direction an item is swiped in to remove it, and the rules of
/// swiping that way.
enum SwipeDirection {
  left(Axis.horizontal, -1),
  right(Axis.horizontal, 1),
  up(Axis.vertical, -1),
  down(Axis.vertical, 1);

  const SwipeDirection(this.axis, this.sign);

  static SwipeDirection of(AxisDirection direction) => switch (direction) {
    AxisDirection.left => left,
    AxisDirection.right => right,
    AxisDirection.up => up,
    AxisDirection.down => down,
  };

  /// The direction items of a list that scrolls along [scrollDirection]
  /// are swiped in unless told otherwise.
  static SwipeDirection across(Axis scrollDirection) =>
      switch (scrollDirection) {
        Axis.vertical => left,
        Axis.horizontal => down,
      };

  final Axis axis;

  /// 1 if the direction points to larger coordinates, -1 if it does not.
  final int sign;

  /// The part of [offset] along the axis.
  double along(Offset offset) => switch (axis) {
    Axis.horizontal => offset.dx,
    Axis.vertical => offset.dy,
  };

  /// The extent of [size] along the axis.
  double extentOf(Size size) => switch (axis) {
    Axis.horizontal => size.width,
    Axis.vertical => size.height,
  };

  /// An offset of [distance] along the axis.
  Offset onAxis(double distance) => switch (axis) {
    Axis.horizontal => Offset(distance, 0),
    Axis.vertical => Offset(0, distance),
  };

  /// The part of [delta] along the axis, damped to a third while it pulls
  /// an item that is already [swiped] the other way further that way.
  Offset restrict(Offset delta, {required Offset swiped}) {
    final distance = along(delta);
    final damped = distance * sign < 0 && along(swiped) * sign < 0;
    return onAxis(damped ? distance / 3 : distance);
  }

  /// Whether a swipe that went [extent], as a part of the item's extent,
  /// or that ended at [velocity] removes the item.
  bool removes({
    required double extent,
    required Velocity velocity,
    required double minExtent,
    required double minVelocity,
  }) =>
      extent * sign > minExtent ||
      along(velocity.pixelsPerSecond) * sign > minVelocity;

  /// Where a removed item at [position] is thrown to: just outside
  /// [bounds], which it moves in.
  OverlayOffset throwTarget(
    OverlayOffset position, {
    required Size itemSize,
    required Size bounds,
  }) => OverlayOffset(switch (this) {
    left => Offset(-itemSize.width, position.dy),
    right => Offset(bounds.width, position.dy),
    up => Offset(position.dx, -itemSize.height),
    down => Offset(position.dx, bounds.height),
  });

  /// Recognizes drags along the axis.
  MultiDragGestureRecognizer Function(BuildContext context)
  get recognizerFactory => switch (axis) {
    Axis.horizontal => createHorizontalSwipeDragGestureRecognizer,
    Axis.vertical => createVerticalSwipeDragGestureRecognizer,
  };
}
