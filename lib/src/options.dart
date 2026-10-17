import 'package:flutter/widgets.dart' hide ReorderCallback;

import 'animated_reorderable.dart';
import 'const.dart';
import 'model/model.dart'
    show AnimatedItemDecorator, defaultDraggedItemDecorator;

/// How items move to their new places when items are inserted, removed or
/// reordered.
@immutable
class MotionOptions {
  const MotionOptions({
    this.duration = defaultMotionAnimationDuration,
    this.curve = defaultMotionAnimationCurve,
  });

  /// The time it takes an item to move to its new place.
  final Duration duration;

  /// The curve an item moves to its new place along.
  final Curve curve;
}

/// An animated decoration around an item while it is held.
@immutable
class ItemDecoration {
  const ItemDecoration({
    this.decorator = defaultDraggedItemDecorator,
    this.duration = defaultDraggedItemDecorationAnimationDuration,
  });

  /// No decoration.
  static const none = ItemDecoration(decorator: null);

  /// Builds the decoration, or null for none. By default the item scales
  /// up a little and fades a little.
  final AnimatedItemDecorator? decorator;

  /// The time it takes the decoration to appear or to go.
  final Duration duration;
}

/// Callbacks for the drags or the swipes of items.
@immutable
class ItemDragCallbacks {
  const ItemDragCallbacks({this.onStart, this.onUpdate, this.onEnd});

  /// Called when a drag or swipe of an item starts.
  final ItemDragStartCallback? onStart;

  /// Called when the pointer moves while an item is dragged or swiped.
  final ItemDragUpdateCallback? onUpdate;

  /// Called when a drag or swipe of an item ends.
  final ItemDragEndCallback? onEnd;
}

/// How items are dragged and reordered.
@immutable
class ReorderOptions {
  const ReorderOptions({
    this.onReorder,
    this.draggableGetter,
    this.reorderableGetter,
    this.gestureRecognizerFactory,
    this.autoScrollerVelocityScalar = defaultAutoScrollVelocityScalar,
    this.decoration = const ItemDecoration(),
    this.callbacks = const ItemDragCallbacks(),
  });

  /// Called when items are reordered. Without it, items can still be
  /// dragged, but do not take each other's places.
  final ReorderCallback? onReorder;

  /// Whether the item at an index can be dragged. All can by default.
  final BoolGetter? draggableGetter;

  /// Whether the item at an index can take another's place, or be taken.
  /// All can by default.
  final BoolGetter? reorderableGetter;

  /// A factory function that creates a [MultiDragGestureRecognizer] for handling
  /// reordering gestures in an [AnimatedReorderable].
  ///
  /// By default, it uses [DelayedMultiDragGestureRecognizer], which introduces a delay
  /// to detect a long press before initiating the drag. This behavior is useful in cases where
  /// you want to distinguish between simple taps and drag gestures.
  ///
  /// Users can override this factory to:
  /// - Customize the default delay for initiating drag gestures (e.g., changing the delay duration).
  /// - Use different types of gesture recognizers (e.g., for specific user interactions or input devices).
  ///
  /// Default implementation:
  /// ```dart
  /// MultiDragGestureRecognizer createReorderDragGestureRecognizer(
  ///   BuildContext context,
  /// ) =>
  ///   DelayedMultiDragGestureRecognizer()
  ///     ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
  /// ```
  ///
  /// Example of customizing the delay duration to 250ms using [DelayedMultiDragGestureRecognizer]:
  /// ```dart
  /// gestureRecognizerFactory: (BuildContext context) {
  ///   final recognizer = DelayedMultiDragGestureRecognizer()
  ///     ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
  ///
  ///   // Customize the delay duration to 250ms
  ///   recognizer.delay = const Duration(milliseconds: 250);
  ///
  ///   return recognizer;
  /// }
  /// ```
  ///
  /// This factory allows for fine-tuned control over the gesture recognition system,
  /// providing flexibility for various user interactions and devices.
  final MultiDragGestureRecognizerFactory? gestureRecognizerFactory;

  /// {@macro flutter.widgets.EdgeDraggingAutoScroller.velocityScalar}
  final double autoScrollerVelocityScalar;

  /// The decoration of a dragged item.
  final ItemDecoration decoration;

  /// The callbacks of each drag.
  final ItemDragCallbacks callbacks;
}

/// How items are swiped away to remove them.
@immutable
class SwipeToRemoveOptions {
  const SwipeToRemoveOptions({
    this.onSwipeToRemove,
    this.directionGetter,
    this.extent = defaultSwipeToRemoveExtent,
    this.velocity = defaultSwipeToRemoveVelocity,
    this.springDescription = defaultFlingSpringDescription,
    this.decoration = const ItemDecoration(),
    this.callbacks = const ItemDragCallbacks(),
  });

  /// Called with the index of an item that is swiped away, to remove it.
  /// Without it, items cannot be swiped.
  final SwipeToRemoveCallback? onSwipeToRemove;

  /// The direction the item at an index is swiped in, or null for an item
  /// that cannot be swiped. By default items are swiped left in a
  /// vertical list and down in a horizontal one.
  final AxisDirectionGetter? directionGetter;

  /// How far an item must be swiped to be removed, as a part of its
  /// extent along the swipe.
  final double extent;

  /// How fast an item must be flung to be removed, in logical pixels per
  /// second.
  final double velocity;

  /// The spring an item flies out with, or back to its place.
  final SpringDescription springDescription;

  /// The decoration of a swiped item.
  final ItemDecoration decoration;

  /// The callbacks of each swipe.
  final ItemDragCallbacks callbacks;
}
