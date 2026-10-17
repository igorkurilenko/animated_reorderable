import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'animated_reorderable_controller.dart';
import 'const.dart';
import 'model/model.dart' as model;
import 'model/permutations.dart';
import 'options.dart';
import 'util/anchored_scroll_physics.dart';
import 'util/overridden_sliver_child_builder_delegate.dart';
import 'util/sliver_grid_layout_notifier.dart';
import 'widget/cross_axis_resize_listener.dart';
import 'widget/items_layer.dart';
import 'widget/overlayed_items_layer.dart';

/// A function utilized by [AnimatedReorderable] to obtain the unique key
/// for the item at the specified [index] within the list or grid.
typedef KeyGetter = Key Function(int index);

/// A function signature to get the bool property
/// of the item at the specified [index].
typedef BoolGetter = bool Function(int index);

/// A function that determines the axis direction
/// associated with an item at a given [index].
typedef AxisDirectionGetter = AxisDirection? Function(int index);

/// A callback function that is called when the items are reordered.
///
/// Implementations should apply the [permutations] to the collection of items.
///
/// ```dart
/// final List<MyDataObject> items = <MyDataObject>[/* ... */];
///
/// void handleReorder(Permutations permutations) =>
///   permutations.apply(items);
/// ```
typedef ReorderCallback = void Function(Permutations permutations);

/// A callback function that is called when an item is swiped for removal.
///
/// Implementations should remove the corresponding collection item at [index].
///
/// ```dart
/// final List<MyDataObject> items = <MyDataObject>[/* ... */];
///
/// void onSwipedToRemove(int index) =>
///   items.removeAt(index);
/// ```
typedef SwipeToRemoveCallback = void Function(int index);

/// A callback function that is called when dragging of an item starts.
///
/// The [index] parameter of the callback is the index of the dragged item.
/// Note: If the item is reordered, the [index] will be updated accordingly.
typedef ItemDragStartCallback = void Function(
  DragStartDetails details,
  int index,
);

/// A callback function that is called when dragging of an item is updated.
///
/// The [index] parameter of the callback is the index of the dragged item.
/// Note: If the item is reordered, the [index] will be updated accordingly.
typedef ItemDragUpdateCallback = void Function(
  DragUpdateDetails details,
  int index,
);

/// A callback function that is called when dragging of an item ends.
///
/// The [index] parameter of the callback is the index of the item at the time it was dropped.
/// Note: If the item is reordered, the [index] will reflect the new position where the item was dropped.
typedef ItemDragEndCallback = void Function(DragEndDetails details, int index);

/// A factory function that creates a [MultiDragGestureRecognizer]
/// for handling drag gestures
typedef MultiDragGestureRecognizerFactory = MultiDragGestureRecognizer Function(
  BuildContext context,
);

/// The [AnimatedReorderable] wrapper makes [ListView] or [GridView] animated,
/// adds reordering and swiping capabilities.
///
/// - It animates item insertions, removals, and reordering with customizable animations.
/// - It allows users to interactively reorder items with drag-and-drop gestures.
/// - It supports swiping to remove items with customizable swipe actions.
///
/// This widget's [AnimatedReorderableState] can be used to dynamically insert,
/// remove or reorder items. To refer to the [AnimatedReorderableState] either provide a
/// [GlobalKey] or use the static [of] method from an item's input callback.
abstract class AnimatedReorderable extends StatefulWidget {
  /// Creates an [AnimatedReorderable] for a [ListView].
  ///
  /// [motion], [reorder] and [swipeToRemove] configure it. The other
  /// parameters are deprecated, and are ignored where the options they
  /// belong to are given.
  factory AnimatedReorderable.list({
    Key? key,
    required KeyGetter keyGetter,
    MotionOptions? motion,
    ReorderOptions? reorder,
    SwipeToRemoveOptions? swipeToRemove,
    @Deprecated(
      'Use motion: MotionOptions(duration: …) instead. It goes in 2.0.',
    )
    Duration motionAnimationDuration = defaultMotionAnimationDuration,
    @Deprecated('Use motion: MotionOptions(curve: …) instead. It goes in 2.0.')
    Curve motionAnimationCurve = defaultMotionAnimationCurve,
    @Deprecated(
      'Use reorder: ReorderOptions(autoScrollerVelocityScalar: …) instead. It goes in 2.0.',
    )
    double autoScrollerVelocityScalar = defaultAutoScrollVelocityScalar,
    @Deprecated(
      'Use reorder: ReorderOptions(draggableGetter: …) instead. It goes in 2.0.',
    )
    BoolGetter? draggableGetter,
    @Deprecated(
      'Use reorder: ReorderOptions(reorderableGetter: …) instead. It goes in 2.0.',
    )
    BoolGetter? reorderableGetter,
    @Deprecated(
      'Use reorder: ReorderOptions(onReorder: …) instead. It goes in 2.0.',
    )
    ReorderCallback? onReorder,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(directionGetter: …) instead. It goes in 2.0.',
    )
    AxisDirectionGetter? swipeToRemoveDirectionGetter,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(extent: …) instead. It goes in 2.0.',
    )
    double swipeToRemoveExtent = defaultSwipeToRemoveExtent,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(velocity: …) instead. It goes in 2.0.',
    )
    double swipeToRemoveVelocity = defaultSwipeToRemoveVelocity,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(springDescription: …) instead. It goes in 2.0.',
    )
    SpringDescription swipeToRemoveSpringDescription =
        defaultFlingSpringDescription,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(onSwipeToRemove: …) instead. It goes in 2.0.',
    )
    SwipeToRemoveCallback? onSwipeToRemove,
    @Deprecated(
      'Use reorder: ReorderOptions(decoration: ItemDecoration(decorator: …)) instead. It goes in 2.0.',
    )
    model.AnimatedItemDecorator? draggedItemDecorator =
        model.defaultDraggedItemDecorator,
    @Deprecated(
      'Use reorder: ReorderOptions(decoration: ItemDecoration(duration: …)) instead. It goes in 2.0.',
    )
    Duration draggedItemDecorationAnimationDuration =
        defaultDraggedItemDecorationAnimationDuration,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(decoration: ItemDecoration(decorator: …)) instead. It goes in 2.0.',
    )
    model.AnimatedItemDecorator? swipedItemDecorator =
        model.defaultDraggedItemDecorator,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(decoration: ItemDecoration(duration: …)) instead. It goes in 2.0.',
    )
    Duration swipedItemDecorationAnimationDuration =
        defaultSwipedItemDecorationAnimationDuration,
    @Deprecated(
      'Use reorder: ReorderOptions(callbacks: ItemDragCallbacks(onStart: …)) instead. It goes in 2.0.',
    )
    ItemDragStartCallback? onItemDragStart,
    @Deprecated(
      'Use reorder: ReorderOptions(callbacks: ItemDragCallbacks(onUpdate: …)) instead. It goes in 2.0.',
    )
    ItemDragUpdateCallback? onItemDragUpdate,
    @Deprecated(
      'Use reorder: ReorderOptions(callbacks: ItemDragCallbacks(onEnd: …)) instead. It goes in 2.0.',
    )
    ItemDragEndCallback? onItemDragEnd,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(callbacks: ItemDragCallbacks(onStart: …)) instead. It goes in 2.0.',
    )
    ItemDragStartCallback? onItemSwipeStart,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(callbacks: ItemDragCallbacks(onUpdate: …)) instead. It goes in 2.0.',
    )
    ItemDragUpdateCallback? onItemSwipeUpdate,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(callbacks: ItemDragCallbacks(onEnd: …)) instead. It goes in 2.0.',
    )
    ItemDragEndCallback? onItemSwipeEnd,
    @Deprecated(
      'Use reorder: ReorderOptions(gestureRecognizerFactory: …) instead. It goes in 2.0.',
    )
    MultiDragGestureRecognizerFactory? reorderGestureRecognizerFactory,
    required ListView listView,
  }) => _ListView(
    key: key,
    keyGetter: keyGetter,
    motion:
        motion ??
        MotionOptions(
          duration: motionAnimationDuration,
          curve: motionAnimationCurve,
        ),
    reorder:
        reorder ??
        ReorderOptions(
          onReorder: onReorder,
          draggableGetter: draggableGetter,
          reorderableGetter: reorderableGetter,
          gestureRecognizerFactory: reorderGestureRecognizerFactory,
          autoScrollerVelocityScalar: autoScrollerVelocityScalar,
          decoration: ItemDecoration(
            decorator: draggedItemDecorator,
            duration: draggedItemDecorationAnimationDuration,
          ),
          callbacks: ItemDragCallbacks(
            onStart: onItemDragStart,
            onUpdate: onItemDragUpdate,
            onEnd: onItemDragEnd,
          ),
        ),
    swipeToRemove:
        swipeToRemove ??
        SwipeToRemoveOptions(
          onSwipeToRemove: onSwipeToRemove,
          directionGetter: swipeToRemoveDirectionGetter,
          extent: swipeToRemoveExtent,
          velocity: swipeToRemoveVelocity,
          springDescription: swipeToRemoveSpringDescription,
          decoration: ItemDecoration(
            decorator: swipedItemDecorator,
            duration: swipedItemDecorationAnimationDuration,
          ),
          callbacks: ItemDragCallbacks(
            onStart: onItemSwipeStart,
            onUpdate: onItemSwipeUpdate,
            onEnd: onItemSwipeEnd,
          ),
        ),
    listView: listView,
  );

  /// Creates an [AnimatedReorderable] for a [GridView].
  ///
  /// [motion], [reorder] and [swipeToRemove] configure it. The other
  /// parameters are deprecated, and are ignored where the options they
  /// belong to are given.
  factory AnimatedReorderable.grid({
    Key? key,
    required KeyGetter keyGetter,
    MotionOptions? motion,
    ReorderOptions? reorder,
    SwipeToRemoveOptions? swipeToRemove,
    @Deprecated(
      'Use motion: MotionOptions(duration: …) instead. It goes in 2.0.',
    )
    Duration motionAnimationDuration = defaultMotionAnimationDuration,
    @Deprecated('Use motion: MotionOptions(curve: …) instead. It goes in 2.0.')
    Curve motionAnimationCurve = defaultMotionAnimationCurve,
    @Deprecated(
      'Use reorder: ReorderOptions(autoScrollerVelocityScalar: …) instead. It goes in 2.0.',
    )
    double autoScrollerVelocityScalar = defaultAutoScrollVelocityScalar,
    @Deprecated(
      'Use reorder: ReorderOptions(draggableGetter: …) instead. It goes in 2.0.',
    )
    BoolGetter? draggableGetter,
    @Deprecated(
      'Use reorder: ReorderOptions(reorderableGetter: …) instead. It goes in 2.0.',
    )
    BoolGetter? reorderableGetter,
    @Deprecated(
      'Use reorder: ReorderOptions(onReorder: …) instead. It goes in 2.0.',
    )
    ReorderCallback? onReorder,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(directionGetter: …) instead. It goes in 2.0.',
    )
    AxisDirectionGetter? swipeToRemoveDirectionGetter,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(extent: …) instead. It goes in 2.0.',
    )
    double swipeToRemoveExtent = defaultSwipeToRemoveExtent,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(velocity: …) instead. It goes in 2.0.',
    )
    double swipeToRemoveVelocity = defaultSwipeToRemoveVelocity,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(springDescription: …) instead. It goes in 2.0.',
    )
    SpringDescription swipeToRemoveSpringDescription =
        defaultFlingSpringDescription,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(onSwipeToRemove: …) instead. It goes in 2.0.',
    )
    SwipeToRemoveCallback? onSwipeToRemove,
    @Deprecated(
      'Use reorder: ReorderOptions(decoration: ItemDecoration(decorator: …)) instead. It goes in 2.0.',
    )
    model.AnimatedItemDecorator? draggedItemDecorator =
        model.defaultDraggedItemDecorator,
    @Deprecated(
      'Use reorder: ReorderOptions(decoration: ItemDecoration(duration: …)) instead. It goes in 2.0.',
    )
    Duration draggedItemDecorationAnimationDuration =
        defaultDraggedItemDecorationAnimationDuration,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(decoration: ItemDecoration(decorator: …)) instead. It goes in 2.0.',
    )
    model.AnimatedItemDecorator? swipedItemDecorator =
        model.defaultDraggedItemDecorator,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(decoration: ItemDecoration(duration: …)) instead. It goes in 2.0.',
    )
    Duration swipedItemDecorationAnimationDuration =
        defaultSwipedItemDecorationAnimationDuration,
    @Deprecated(
      'Use reorder: ReorderOptions(callbacks: ItemDragCallbacks(onStart: …)) instead. It goes in 2.0.',
    )
    ItemDragStartCallback? onItemDragStart,
    @Deprecated(
      'Use reorder: ReorderOptions(callbacks: ItemDragCallbacks(onUpdate: …)) instead. It goes in 2.0.',
    )
    ItemDragUpdateCallback? onItemDragUpdate,
    @Deprecated(
      'Use reorder: ReorderOptions(callbacks: ItemDragCallbacks(onEnd: …)) instead. It goes in 2.0.',
    )
    ItemDragEndCallback? onItemDragEnd,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(callbacks: ItemDragCallbacks(onStart: …)) instead. It goes in 2.0.',
    )
    ItemDragStartCallback? onItemSwipeStart,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(callbacks: ItemDragCallbacks(onUpdate: …)) instead. It goes in 2.0.',
    )
    ItemDragUpdateCallback? onItemSwipeUpdate,
    @Deprecated(
      'Use swipeToRemove: SwipeToRemoveOptions(callbacks: ItemDragCallbacks(onEnd: …)) instead. It goes in 2.0.',
    )
    ItemDragEndCallback? onItemSwipeEnd,
    @Deprecated(
      'Use reorder: ReorderOptions(gestureRecognizerFactory: …) instead. It goes in 2.0.',
    )
    MultiDragGestureRecognizerFactory? reorderGestureRecognizerFactory,
    required GridView gridView,
  }) => _GridView(
    key: key,
    keyGetter: keyGetter,
    motion:
        motion ??
        MotionOptions(
          duration: motionAnimationDuration,
          curve: motionAnimationCurve,
        ),
    reorder:
        reorder ??
        ReorderOptions(
          onReorder: onReorder,
          draggableGetter: draggableGetter,
          reorderableGetter: reorderableGetter,
          gestureRecognizerFactory: reorderGestureRecognizerFactory,
          autoScrollerVelocityScalar: autoScrollerVelocityScalar,
          decoration: ItemDecoration(
            decorator: draggedItemDecorator,
            duration: draggedItemDecorationAnimationDuration,
          ),
          callbacks: ItemDragCallbacks(
            onStart: onItemDragStart,
            onUpdate: onItemDragUpdate,
            onEnd: onItemDragEnd,
          ),
        ),
    swipeToRemove:
        swipeToRemove ??
        SwipeToRemoveOptions(
          onSwipeToRemove: onSwipeToRemove,
          directionGetter: swipeToRemoveDirectionGetter,
          extent: swipeToRemoveExtent,
          velocity: swipeToRemoveVelocity,
          springDescription: swipeToRemoveSpringDescription,
          decoration: ItemDecoration(
            decorator: swipedItemDecorator,
            duration: swipedItemDecorationAnimationDuration,
          ),
          callbacks: ItemDragCallbacks(
            onStart: onItemSwipeStart,
            onUpdate: onItemSwipeUpdate,
            onEnd: onItemSwipeEnd,
          ),
        ),
    gridView: gridView,
  );

  /// Creates an [AnimatedReorderable] from its settings, for a subclass.
  @Deprecated(
    'Use AnimatedReorderable.list or AnimatedReorderable.grid instead. '
    'It goes in 2.0.',
  )
  AnimatedReorderable({
    super.key,
    required this.keyGetter,
    Duration motionAnimationDuration = defaultMotionAnimationDuration,
    Curve motionAnimationCurve = defaultMotionAnimationCurve,
    double autoScrollerVelocityScalar = defaultAutoScrollVelocityScalar,
    BoolGetter? draggableGetter,
    BoolGetter? reorderableGetter,
    ReorderCallback? onReorder,
    AxisDirectionGetter? swipeToRemoveDirectionGetter,
    double swipeToRemoveExtent = defaultSwipeToRemoveExtent,
    double swipeToRemoveVelocity = defaultSwipeToRemoveVelocity,
    SpringDescription swipeToRemoveSpringDescription =
        defaultFlingSpringDescription,
    SwipeToRemoveCallback? onSwipeToRemove,
    model.AnimatedItemDecorator? draggedItemDecorator,
    Duration draggedItemDecorationAnimationDuration =
        defaultDraggedItemDecorationAnimationDuration,
    model.AnimatedItemDecorator? swipedItemDecorator,
    Duration swipedItemDecorationAnimationDuration =
        defaultSwipedItemDecorationAnimationDuration,
    ItemDragStartCallback? onItemDragStart,
    ItemDragUpdateCallback? onItemDragUpdate,
    ItemDragEndCallback? onItemDragEnd,
    ItemDragStartCallback? onItemSwipeStart,
    ItemDragUpdateCallback? onItemSwipeUpdate,
    ItemDragEndCallback? onItemSwipeEnd,
    MultiDragGestureRecognizerFactory? reorderGestureRecognizerFactory,
  }) : motion = MotionOptions(
         duration: motionAnimationDuration,
         curve: motionAnimationCurve,
       ),
       reorder = ReorderOptions(
         onReorder: onReorder,
         draggableGetter: draggableGetter,
         reorderableGetter: reorderableGetter,
         gestureRecognizerFactory: reorderGestureRecognizerFactory,
         autoScrollerVelocityScalar: autoScrollerVelocityScalar,
         decoration: ItemDecoration(
           decorator: draggedItemDecorator,
           duration: draggedItemDecorationAnimationDuration,
         ),
         callbacks: ItemDragCallbacks(
           onStart: onItemDragStart,
           onUpdate: onItemDragUpdate,
           onEnd: onItemDragEnd,
         ),
       ),
       swipeToRemove = SwipeToRemoveOptions(
         onSwipeToRemove: onSwipeToRemove,
         directionGetter: swipeToRemoveDirectionGetter,
         extent: swipeToRemoveExtent,
         velocity: swipeToRemoveVelocity,
         springDescription: swipeToRemoveSpringDescription,
         decoration: ItemDecoration(
           decorator: swipedItemDecorator,
           duration: swipedItemDecorationAnimationDuration,
         ),
         callbacks: ItemDragCallbacks(
           onStart: onItemSwipeStart,
           onUpdate: onItemSwipeUpdate,
           onEnd: onItemSwipeEnd,
         ),
       );

  const AnimatedReorderable._({
    super.key,
    required this.keyGetter,
    required this.motion,
    required this.reorder,
    required this.swipeToRemove,
  });

  /// A function that provides the unique key for each item in the list or grid.
  final KeyGetter keyGetter;

  /// How items move to their new places.
  final MotionOptions motion;

  /// How items are dragged and reordered.
  final ReorderOptions reorder;

  /// How items are swiped away to remove them.
  final SwipeToRemoveOptions swipeToRemove;

  /// The duration of the motion animation for item reordering.
  ///
  /// This [Duration] defines the time it takes for the motion animation to complete
  /// when items are being reordered within the [AnimatedReorderable] widget.
  @Deprecated('Read motion.duration instead. It goes in 2.0.')
  Duration get motionAnimationDuration => motion.duration;

  /// The curve of the motion animation for item reordering.
  @Deprecated('Read motion.curve instead. It goes in 2.0.')
  Curve get motionAnimationCurve => motion.curve;

  /// {@macro flutter.widgets.EdgeDraggingAutoScroller.velocityScalar}
  ///
  /// {@macro flutter.widgets.SliverReorderableList.autoScrollerVelocityScalar.default}
  @Deprecated(
    'Read reorder.autoScrollerVelocityScalar instead. It goes in 2.0.',
  )
  double get autoScrollerVelocityScalar => reorder.autoScrollerVelocityScalar;

  /// A function that determines whether an item at a given index is draggable.
  ///
  /// If not provided all items are draggable by default.
  @Deprecated('Read reorder.draggableGetter instead. It goes in 2.0.')
  BoolGetter? get draggableGetter => reorder.draggableGetter;

  /// A function that determines whether an item at a given index is reorderable.
  ///
  /// If not provided all items are reorderable by default.
  @Deprecated('Read reorder.reorderableGetter instead. It goes in 2.0.')
  BoolGetter? get reorderableGetter => reorder.reorderableGetter;

  /// A callback function called when items are reordered.
  @Deprecated('Read reorder.onReorder instead. It goes in 2.0.')
  ReorderCallback? get onReorder => reorder.onReorder;

  /// A function that determines the swipe-to-remove direction for an item at a given index.
  ///
  /// If the function returns `null`, the `swipeToRemove` feature
  /// will be disabled for the element at the specified [index].
  @Deprecated('Read swipeToRemove.directionGetter instead. It goes in 2.0.')
  AxisDirectionGetter? get swipeToRemoveDirectionGetter =>
      swipeToRemove.directionGetter;

  /// The minimal extent, as a ratio of item movement, to trigger swipe-to-remove.
  ///
  /// This property represents the minimum ratio of the item's movement along
  /// the swipe direction required to initiate the swipe-to-remove action.
  /// When a user swipes an item to an extent greater than or equal to this
  /// ratio, the swipe-to-remove action will be initiated for the corresponding
  /// item within the [AnimatedReorderable] widget.
  @Deprecated('Read swipeToRemove.extent instead. It goes in 2.0.')
  double get swipeToRemoveExtent => swipeToRemove.extent;

  /// The minimum swiping velocity required to trigger the swipe-to-remove action.
  ///
  /// If the swiping velocity of an item exceeds this value, the swipe-to-remove
  /// action will be triggered for the corresponding item within the
  /// [AnimatedReorderable] widget.
  @Deprecated('Read swipeToRemove.velocity instead. It goes in 2.0.')
  double get swipeToRemoveVelocity => swipeToRemove.velocity;

  /// The spring description used for the swipe-to-remove animation.
  ///
  /// This [SpringDescription] defines the animation characteristics,
  /// including the mass, stiffness and damping, used in the
  /// swipe-to-remove animation within the [AnimatedReorderable] widget.
  @Deprecated('Read swipeToRemove.springDescription instead. It goes in 2.0.')
  SpringDescription get swipeToRemoveSpringDescription =>
      swipeToRemove.springDescription;

  /// A callback function called when an item is swiped for removal.
  ///
  ///  It occurs if at least one of the following two cases happens:
  /// * Swiped in the remove direction, and the extent is greater than or equal to [swipeToRemoveExtent].
  /// * Swiped in the remove direction, and the velocity is greater than or equal to [swipeToRemoveVelocity].
  @Deprecated('Read swipeToRemove.onSwipeToRemove instead. It goes in 2.0.')
  SwipeToRemoveCallback? get onSwipeToRemove => swipeToRemove.onSwipeToRemove;

  /// A callback that allows to add an animated decoration around
  /// an item when it is being dragged.
  @Deprecated('Read reorder.decoration.decorator instead. It goes in 2.0.')
  model.AnimatedItemDecorator? get draggedItemDecorator =>
      reorder.decoration.decorator;

  /// The duration of the animation for decorating the dragged item.
  @Deprecated('Read reorder.decoration.duration instead. It goes in 2.0.')
  Duration get draggedItemDecorationAnimationDuration =>
      reorder.decoration.duration;

  /// A callback that allows to add an animated decoration around
  /// an item when it is being swiped.
  @Deprecated(
    'Read swipeToRemove.decoration.decorator instead. It goes in 2.0.',
  )
  model.AnimatedItemDecorator? get swipedItemDecorator =>
      swipeToRemove.decoration.decorator;

  /// The duration of the animation for decorating the swiped item.
  @Deprecated('Read swipeToRemove.decoration.duration instead. It goes in 2.0.')
  Duration get swipedItemDecorationAnimationDuration =>
      swipeToRemove.decoration.duration;

  /// Callback function invoked when dragging a list or grid item starts.
  @Deprecated('Read reorder.callbacks.onStart instead. It goes in 2.0.')
  ItemDragStartCallback? get onItemDragStart => reorder.callbacks.onStart;

  /// Callback function invoked when dragging a list or grid item is updated.
  @Deprecated('Read reorder.callbacks.onUpdate instead. It goes in 2.0.')
  ItemDragUpdateCallback? get onItemDragUpdate => reorder.callbacks.onUpdate;

  /// Callback function invoked when dragging a list or grid item ends.
  @Deprecated('Read reorder.callbacks.onEnd instead. It goes in 2.0.')
  ItemDragEndCallback? get onItemDragEnd => reorder.callbacks.onEnd;

  /// Callback function invoked when swiping a list or grid item starts.
  @Deprecated('Read swipeToRemove.callbacks.onStart instead. It goes in 2.0.')
  ItemDragStartCallback? get onItemSwipeStart =>
      swipeToRemove.callbacks.onStart;

  /// Callback function invoked when swiping a list or grid item is updated.
  @Deprecated('Read swipeToRemove.callbacks.onUpdate instead. It goes in 2.0.')
  ItemDragUpdateCallback? get onItemSwipeUpdate =>
      swipeToRemove.callbacks.onUpdate;

  /// Callback function invoked when swiping a list or grid item ends.
  @Deprecated('Read swipeToRemove.callbacks.onEnd instead. It goes in 2.0.')
  ItemDragEndCallback? get onItemSwipeEnd => swipeToRemove.callbacks.onEnd;

  /// A factory function that creates a [MultiDragGestureRecognizer] for handling
  /// reordering gestures in the [AnimatedReorderable] widget.
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
  /// reorderGestureRecognizerFactory: (BuildContext context) {
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
  @Deprecated('Read reorder.gestureRecognizerFactory instead. It goes in 2.0.')
  MultiDragGestureRecognizerFactory? get reorderGestureRecognizerFactory =>
      reorder.gestureRecognizerFactory;

  /// The state from the closest instance of this class that encloses the given
  /// context.
  ///
  /// This method is typically used by [AnimatedReorderable] item widgets that insert
  /// or remove items in response to user input.
  ///
  /// If no [AnimatedReorderable] surrounds the context given, then this function will
  /// assert in debug mode and throw an exception in release mode.
  ///
  /// This method can be expensive (it walks the element tree).
  ///
  /// This method does not create a dependency, and so will not cause rebuilding
  /// when the state changes.
  ///
  /// See also:
  ///
  ///  * [maybeOf], a similar function that will return null if no
  ///    [AnimatedReorderable] ancestor is found.
  static AnimatedReorderableState of(BuildContext context) {
    final AnimatedReorderableState? result = AnimatedReorderable.maybeOf(
      context,
    );
    assert(() {
      if (result == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'AnimatedReorderable.of() called with a context that does not contain an AnimatedReorderable.',
          ),
          ErrorDescription(
            'No AnimatedReorderable ancestor could be found starting from the context that was passed to AnimatedReorderable.of().',
          ),
          ErrorHint(
            'This can happen when the context provided is from the same StatefulWidget that '
            'built the AnimatedReorderable. Please see the AnimatedReorderable documentation for examples '
            'of how to refer to an AnimatedReorderableState object:\n'
            '  https://pub.dev/packages/animated_reorderable',
          ),
          context.describeElement('The context used was'),
        ]);
      }
      return true;
    }());
    return result!;
  }

  /// The [AnimatedReorderableState] from the closest instance of [AnimatedReorderable] that encloses the given
  /// context.
  ///
  /// This method is typically used by [AnimatedReorderable] item widgets that insert
  /// or remove items in response to user input.
  ///
  /// If no [AnimatedReorderable] surrounds the context given, then this function will
  /// return null.
  ///
  /// This method can be expensive (it walks the element tree).
  ///
  /// This method does not create a dependency, and so will not cause rebuilding
  /// when the state changes.
  ///
  /// See also:
  ///
  ///  * [of], a similar function that will throw if no [AnimatedReorderable] ancestor
  ///    is found.
  static AnimatedReorderableState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<AnimatedReorderableState>();
  }
}

/// The [AnimatedReorderableState] for [AnimatedReorderable], a wrapper for list or grid that
/// animates items when they are inserted, removed or reordered.
///
/// When an item is inserted with [insertItem] an animation begins running. The
/// animation is passed to the [insertItem] `builder` parameter.
///
/// When an item is removed with [removeItem] its animation is reversed.
/// The removed item's animation is passed to the [removeItem] `builder`
/// parameter.
///
/// When an item is reordered with [reorderItem] its motion animation is handled
/// by the underlying controller.
///
/// An app that needs to insert, remove or reorder items in response to an event
/// can refer to the [AnimatedReorderable]'s state with a global key:
///
/// ```dart
/// // (e.g. in a stateful widget)
/// GlobalKey<AnimatedReorderableState> animatedReorderableKey = GlobalKey<AnimatedReorderableState>();
///
/// // ...
///
/// @override
/// Widget build(BuildContext context) {
///   return AnimatedReorderable(
///     key: animatedReorderableKey,
///     keyGetter: (index) => ValueKey(_items[index]),
///     listView: ListView.builder(
///     //  ...
///     ),
///   );
/// }
///
/// // ...
///
/// void _updateList() {
///   _items.insert(123, newItem);
///   animatedReorderableKey.currentState!.insertItem(123, builder:  (context, index, animation) {
///   //  ...
///   });
/// }
/// ```
///
/// [AnimatedReorderable] item input handlers can also refer to their [AnimatedReorderableState]
/// with the static [AnimatedReorderable.of] method.
abstract class AnimatedReorderableState<T extends AnimatedReorderable>
    extends State<T>
    with TickerProviderStateMixin {
  late final AnimatedReorderableController _controller;
  ScrollController? _ownScrollController;

  ScrollController? get _scrollController;

  bool? get _primary;

  SliverChildDelegate get _childrenDelegate;

  Clip get _clipBehavior;

  Axis get _scrollDirection;

  @override
  void initState() {
    super.initState();

    _controller = AnimatedReorderableController(
      keyGetter: widget.keyGetter,
      motion: widget.motion,
      reorder: widget.reorder,
      swipeToRemove: widget.swipeToRemove,
      scrollDirection: _scrollDirection,
      itemCount: childrenDelegateSettingsOf(_childrenDelegate).childCount,
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _controller.scrollSync.scrollController = _effectiveScrollController;
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);

    _controller
      ..keyGetter = widget.keyGetter
      ..motion = widget.motion
      ..reorder = widget.reorder
      ..swipeToRemove = widget.swipeToRemove
      ..scrollDirection = _scrollDirection
      ..scrollSync.scrollController = _effectiveScrollController;
  }

  /// The wrapped view's controller or, if the view is primary, the
  /// [PrimaryScrollController], decided the way [ScrollView] decides it.
  /// The view is then built with that controller and `primary: false`.
  ScrollController get _effectiveScrollController {
    final primary =
        _primary ??
        (_scrollController == null &&
            PrimaryScrollController.shouldInherit(context, _scrollDirection));
    final scrollController = primary
        ? PrimaryScrollController.maybeOf(context)
        : _scrollController;
    return scrollController ?? (_ownScrollController ??= ScrollController());
  }

  /// Insert an item at `index` and start an animation that will be passed
  /// to `builder`.
  ///
  /// This method's semantics are the same as Dart's [List.insert] method: it
  /// increases the length of the list of items by one and shifts
  /// all items at or after `index` towards the end of the list of items.
  void insertItem(
    int index,
    AnimatedItemBuilder builder, {
    Duration duration = defaultInsertItemAnimationDuration,
  }) => _controller.insertItem(index, builder, duration);

  /// Remove the item at `index` and start an animation that will be passed to
  /// `builder` when the item is visible.
  ///
  /// Items are removed immediately. After an item has been removed, its index
  /// will no longer be passed to the `itemBuilder`. However, the
  /// item will still appear for `duration` and during that time
  /// `builder` must construct its widget as needed.
  ///
  /// This method's semantics are the same as Dart's [List.remove] method: it
  /// decreases the length of items by one and shifts all items at or before
  /// `index` towards the beginning of the list of items.
  ///
  /// See also:
  ///
  ///   * [AnimatedRemovedItemBuilder], which describes the arguments to the
  ///     `builder` argument.
  void removeItem(
    int index,
    AnimatedRemovedItemBuilder builder, {
    Duration duration = defaultRemoveItemAnimationDuration,
    int? zIndex,
  }) => _controller.removeItem(index, builder, duration, zIndex: zIndex);

  /// Reorders the item at the specified [index] to a new position in the list or grid.
  ///
  /// This method triggers the reordering animation to smoothly move the item
  /// from its current position to the [destIndex] within the [AnimatedReorderable] widget.
  ///
  /// If `onReorder` callback is not specified, then this function will throw an exception.
  ///
  /// The [index] parameter represents the original position of the item.
  /// The [destIndex] parameter represents the new position to which the item will be moved.
  ///
  /// Note: The reordering animation is handled by the underlying controller.
  ///
  /// Parameters:
  /// - `index`: The original position of the item to be reordered.
  /// - `destIndex`: The new position to which the item will be moved.
  void reorderItem(int index, {required int destIndex}) =>
      _controller.reorderItem(index, destIndex: destIndex);

  /// Checks if the item at the given [index] is currently rendered within the widget tree.
  ///
  /// An item is considered rendered if it is either within the visible viewport of the list or grid,
  /// or within the `cacheExtent` area (pre-rendered items just outside of the visible viewport).
  ///
  /// This method does not guarantee that the item is visible on screen but only that it is part of the widget tree.
  ///
  /// [index]: The position of the item in the list or grid. Must be a valid index for the current data.
  ///
  /// Returns:
  ///   - `true`: If the item is rendered (either visible or within the cache extent area).
  ///   - `false`: If the item is not currently rendered (i.e., outside of the widget tree).
  ///
  /// Example:
  /// ```
  /// bool isRendered = isItemRendered(5);
  /// if (isRendered) {
  ///   // The item is rendered in the widget tree, perform further actions
  /// }
  /// ```
  bool isItemRendered(int index) => _controller.isItemRendered(index);

  /// Returns the [BuildContext] of a grid item at the given [index],
  /// if the item is part of the widget tree (i.e., rendered, but not necessarily visible on screen).
  ///
  /// This method checks if the item at the specified [index] has been rendered
  /// (i.e., is within the widget tree, which includes items in the `cacheExtent` area)
  /// and returns its associated [BuildContext].
  ///
  /// If the item is not rendered (for example, it is outside the `cacheExtent`)
  /// or if the [index] does not correspond to any existing item in the grid,
  /// the method returns `null`.
  ///
  /// [index]: The position of the item in the grid. Must be a valid index for the current grid data.
  ///
  /// Returns:
  ///   - [BuildContext]: The build context of the rendered item if available.
  ///   - `null`: If the item is not rendered or if the [index] is invalid (i.e., no item exists at the given index).
  ///
  /// Example:
  /// ```
  /// BuildContext? context = getItemBuildContext(3);
  /// if (context != null) {
  ///   // Perform actions with the item's context
  /// }
  /// ```
  BuildContext? getRenderedItemBuildContext(int index) =>
      _controller.getRenderedItemAt(index)?.context;

  @override
  void dispose() {
    _controller.dispose();
    _ownScrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CrossAxisResizeListener(
    scrollDirection: _scrollDirection,
    // A grid keeps its first visible item in place when its cross axis
    // resizes.
    onResize: _controller.scrollSync.anchorFirstVisibleGridItem,
    // The layers build again with the new constraints, so the overlayed
    // items fit the new layout.
    builder: (context) => Stack(
      children: [
        Align(
          alignment: Alignment.center,
          // A layout-time correction, like a clamp after the content
          // shrank, moves the scroll offset without notifying listeners.
          // Only re-mark the baseline: overlayed items are re-targeted from
          // live positions after the build, so shifting them would count
          // the correction twice. On ordinary scrolls this is a no-op.
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (notification) {
              if (notification.depth == 0) {
                _controller.scrollSync.markScrollOffset();
              }
              return false;
            },
            child: ItemsLayer(
              controller: _controller,
              collectionViewBuilder: buildCollectionView,
            ),
          ),
        ),
        OverlayedItemsLayer(
          controller: _controller,
          clipBehavior: _clipBehavior,
        ),
      ],
    ),
  );

  Widget buildCollectionView(BuildContext context);
}

class _ListView extends AnimatedReorderable {
  const _ListView({
    super.key,
    required super.keyGetter,
    required super.motion,
    required super.reorder,
    required super.swipeToRemove,
    required this.listView,
  }) : super._();

  final ListView listView;

  @override
  State<AnimatedReorderable> createState() => _ListViewState();
}

class _ListViewState extends AnimatedReorderableState<_ListView> {
  @override
  ScrollController? get _scrollController => widget.listView.controller;

  @override
  bool? get _primary => widget.listView.primary;

  @override
  SliverChildDelegate get _childrenDelegate => widget.listView.childrenDelegate;

  @override
  Clip get _clipBehavior => widget.listView.clipBehavior;

  @override
  Axis get _scrollDirection => widget.listView.scrollDirection;

  @override
  Widget buildCollectionView(BuildContext context) => ListView.custom(
    key: widget.listView.key,
    scrollDirection: _scrollDirection,
    reverse: widget.listView.reverse,
    controller: _controller.scrollSync.scrollController,
    primary: false,
    physics: widget.listView.physics,
    shrinkWrap: widget.listView.shrinkWrap,
    padding: widget.listView.padding,
    itemExtent: widget.listView.itemExtent,
    prototypeItem: widget.listView.prototypeItem,
    itemExtentBuilder: widget.listView.itemExtentBuilder,
    childrenDelegate: _controller.itemWidgets.overrideChildrenDelegate(
      _childrenDelegate,
    ),
    // ignore: deprecated_member_use
    cacheExtent: widget.listView.cacheExtent,
    scrollCacheExtent: widget.listView.scrollCacheExtent,
    semanticChildCount: widget.listView.semanticChildCount,
    dragStartBehavior: widget.listView.dragStartBehavior,
    keyboardDismissBehavior: widget.listView.keyboardDismissBehavior,
    restorationId: widget.listView.restorationId,
    clipBehavior: _clipBehavior,
    hitTestBehavior: widget.listView.hitTestBehavior,
  );
}

class _GridView extends AnimatedReorderable {
  const _GridView({
    super.key,
    required super.keyGetter,
    required super.motion,
    required super.reorder,
    required super.swipeToRemove,
    required this.gridView,
  }) : super._();

  final GridView gridView;

  @override
  State<AnimatedReorderable> createState() => _GridViewState();
}

class _GridViewState extends AnimatedReorderableState<_GridView> {
  @override
  ScrollController? get _scrollController => widget.gridView.controller;

  @override
  bool? get _primary => widget.gridView.primary;

  @override
  SliverChildDelegate get _childrenDelegate => widget.gridView.childrenDelegate;

  @override
  Clip get _clipBehavior => widget.gridView.clipBehavior;

  @override
  Axis get _scrollDirection => widget.gridView.scrollDirection;

  @override
  Widget buildCollectionView(BuildContext context) => GridView.custom(
    key: widget.gridView.key,
    scrollDirection: _scrollDirection,
    reverse: widget.gridView.reverse,
    controller: _controller.scrollSync.scrollController,
    primary: false,
    physics: AnchoredScrollPhysics(
      anchor: _controller.scrollSync.anchoredScrollOffset,
      parent: widget.gridView.physics,
    ),
    shrinkWrap: widget.gridView.shrinkWrap,
    padding: widget.gridView.padding,
    gridDelegate: SliverGridLayoutNotifier(
      gridDelegate: widget.gridView.gridDelegate,
      onLayout: _controller.scrollSync.didLayOutGrid,
    ),
    childrenDelegate: _controller.itemWidgets.overrideChildrenDelegate(
      _childrenDelegate,
    ),
    // ignore: deprecated_member_use
    cacheExtent: widget.gridView.cacheExtent,
    scrollCacheExtent: widget.gridView.scrollCacheExtent,
    semanticChildCount: widget.gridView.semanticChildCount,
    dragStartBehavior: widget.gridView.dragStartBehavior,
    keyboardDismissBehavior: widget.gridView.keyboardDismissBehavior,
    restorationId: widget.gridView.restorationId,
    clipBehavior: _clipBehavior,
    hitTestBehavior: widget.gridView.hitTestBehavior,
  );
}
