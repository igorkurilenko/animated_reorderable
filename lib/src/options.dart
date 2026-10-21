import 'package:flutter/widgets.dart';

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
  ///
  /// When the place moves again while the item is on such a move, the item
  /// heads for the new place at the speed it has, and gets there [duration]
  /// after the place moved.
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

  /// The time it takes the decoration to appear or to go. An item flung
  /// back to its place that gets there sooner loses it as it lands, though
  /// in no less than 100 ms.
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
    this.springDescription = defaultFlingSpringDescription,
    this.callbacks = const ItemDragCallbacks(),
    this.groupId,
  });

  /// The id of the list in the [AnimatedReorderableGroup] above it, which
  /// the group's callbacks get as an [ItemPlace]'s `list`. With it, and
  /// with [onReorder], items can be dragged to and from the group's other
  /// lists.
  final Object? groupId;

  /// Called when items are reordered. Without it, items can still be
  /// dragged, but do not take each other's places.
  ///
  /// With it, screen readers can also move each item that can be dragged
  /// and reordered, as [ReorderableList] lets them: to the start, one place
  /// back or forward, or to the end, and in a grid a row back or forward. A
  /// move goes as [AnimatedReorderableState.reorderItem] does, and calls
  /// this.
  final ItemMovesCallback? onReorder;

  /// Whether the item at an index can be dragged. All can by default.
  final BoolGetter? draggableGetter;

  /// Whether the item at an index can take another's place, or be taken.
  /// All can by default.
  final BoolGetter? reorderableGetter;

  /// Creates the recognizer of the gesture that starts a drag.
  ///
  /// By default, a [DelayedMultiDragGestureRecognizer] starts a drag after a
  /// long press, so a tap on an item, or a scroll of the list, still works:
  ///
  /// ```dart
  /// (context) => DelayedMultiDragGestureRecognizer()
  ///   ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
  /// ```
  ///
  /// A shorter press, of 250 ms, starts a drag with this one. A recognizer
  /// takes its delay as it's created, and the multi-drag recognizers come
  /// from `package:flutter/gestures.dart`, which `material.dart` doesn't
  /// export:
  ///
  /// ```dart
  /// gestureRecognizerFactory: (context) => DelayedMultiDragGestureRecognizer(
  ///   delay: const Duration(milliseconds: 250),
  /// )..gestureSettings = MediaQuery.maybeGestureSettingsOf(context),
  /// ```
  ///
  /// An [ImmediateMultiDragGestureRecognizer] starts a drag at once, as a
  /// mouse does on the example's kanban board.
  final MultiDragGestureRecognizerFactory? gestureRecognizerFactory;

  /// {@macro flutter.widgets.EdgeDraggingAutoScroller.velocityScalar}
  final double autoScrollerVelocityScalar;

  /// The decoration of a dragged item.
  final ItemDecoration decoration;

  /// The spring an item flies back to its place with as it is let go,
  /// starting at the speed it is let go at.
  ///
  /// The default doesn't bounce, and takes an item let go at rest most of
  /// the way in a fifth of a second. A spring that doesn't bounce stops an
  /// item flung at its place there, however fast; a bouncy one takes it
  /// past and back.
  final SpringDescription springDescription;

  /// The callbacks of each drag.
  final ItemDragCallbacks callbacks;
}

/// Builds what a dragged item shows as it flies from the look of the list
/// it leaves to the look of the list it goes to, as a hero_here flight's
/// shuttle builder does.
///
/// [from] is the old look, as it last showed, and [to] the new one. Each is
/// laid out as it is, and fitted to the shuttle. [animation] runs from 0 at
/// [from] to 1 at [to].
typedef ItemFlightShuttleBuilder = Widget Function(
  BuildContext context,
  Animation<double> animation,
  Widget from,
  Widget to,
);

/// How a dragged item flies from the look of one list of an
/// [AnimatedReorderableGroup] to another's, as it goes from one list to the
/// other. It grows or shrinks to the new list's slots around the point the
/// pointer holds.
@immutable
class FlightOptions {
  const FlightOptions({
    this.duration = defaultFlightDuration,
    this.curve = defaultFlightCurve,
    this.shuttleBuilder = crossFadeShuttleBuilder,
  });

  /// No flight: an item shows its new list's look at once.
  static const none = FlightOptions(duration: Duration.zero);

  /// The time a flight takes. A zero duration flies no flight.
  final Duration duration;

  /// The curve a flight runs along.
  final Curve curve;

  /// Builds what a flying item shows. By default it fades the old look out
  /// and the new one in.
  final ItemFlightShuttleBuilder shuttleBuilder;

  /// Fades [from] out and [to] in as [animation] runs.
  static Widget crossFadeShuttleBuilder(
    BuildContext context,
    Animation<double> animation,
    Widget from,
    Widget to,
  ) => Stack(
    fit: StackFit.expand,
    children: [
      FadeTransition(opacity: ReverseAnimation(animation), child: from),
      FadeTransition(opacity: animation, child: to),
    ],
  );
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

  /// Called with the index of an item that is swiped away, as it flies off,
  /// to remove it from the app's data and from the list with
  /// [AnimatedReorderableState.removeItem], as [SwipeToRemoveCallback] shows.
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

  /// The spring an item flies back to its place with as it is let go, when
  /// the swipe doesn't remove it, starting at the speed it is let go at.
  ///
  /// The default doesn't bounce, and takes an item let go at rest most of
  /// the way in a fifth of a second. A spring that doesn't bounce stops an
  /// item flung at its place there, however fast; a bouncy one takes it
  /// past and back.
  ///
  /// An item swiped away flies off with no spring, at the speed it is let
  /// go at. It speeds up evenly only if it would take longer than a quarter
  /// of a second to get out of sight.
  final SpringDescription springDescription;

  /// The decoration of a swiped item.
  final ItemDecoration decoration;

  /// The callbacks of each swipe.
  final ItemDragCallbacks callbacks;
}
