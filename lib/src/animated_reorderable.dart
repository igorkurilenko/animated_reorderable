import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'animated_reorderable_controller.dart';
import 'animated_reorderable_group.dart';
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
typedef PermutationsCallback = void Function(Permutations permutations);

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
final class AnimatedReorderable extends StatefulWidget {
  /// Creates an [AnimatedReorderable] for a [ListView].
  ///
  /// [motion], [reorder], [swipeToRemove] and [insertTransition] configure
  /// it.
  AnimatedReorderable.list({
    super.key,
    required this.keyGetter,
    this.motion = const MotionOptions(),
    this.reorder = const ReorderOptions(),
    this.swipeToRemove = const SwipeToRemoveOptions(),
    this.insertTransition,
    required ListView listView,
  }) : _view = _WrappedListView(listView);

  /// Creates an [AnimatedReorderable] for a [GridView].
  ///
  /// [motion], [reorder], [swipeToRemove] and [insertTransition] configure
  /// it.
  AnimatedReorderable.grid({
    super.key,
    required this.keyGetter,
    this.motion = const MotionOptions(),
    this.reorder = const ReorderOptions(),
    this.swipeToRemove = const SwipeToRemoveOptions(),
    this.insertTransition,
    required GridView gridView,
  }) : _view = _WrappedGridView(gridView);

  /// The list or grid view it wraps.
  final _WrappedView _view;

  /// A function that provides the unique key for each item in the list or grid.
  final KeyGetter keyGetter;

  /// How items move to their new places.
  final MotionOptions motion;

  /// How items are dragged and reordered.
  final ReorderOptions reorder;

  /// How items are swiped away to remove them.
  final SwipeToRemoveOptions swipeToRemove;

  /// Puts an item's `child` in the transition it enters with, when
  /// [AnimatedReorderableState.insertItem] inserts it.
  ///
  /// Every item is built through it, as [AnimatedList] builds its items:
  /// an inserted item with an `animation` that runs forward while it
  /// enters, and every other item with a completed one. So an item looks
  /// the same to its subtree before, while and after it enters, and the
  /// subtree keeps its state.
  ///
  /// Without it, an inserted item shows at once while the others move
  /// aside.
  final model.AnimatedItemDecorator? insertTransition;

  @override
  State<AnimatedReorderable> createState() => AnimatedReorderableState();

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
/// item enters through the [AnimatedReorderable.insertTransition] with it.
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
///   return AnimatedReorderable.list(
///     key: animatedReorderableKey,
///     keyGetter: (index) => ValueKey(_items[index]),
///     insertTransition: (child, index, animation) =>
///         FadeTransition(opacity: animation, child: child),
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
///   animatedReorderableKey.currentState!.insertItem(123);
/// }
/// ```
///
/// [AnimatedReorderable] item input handlers can also refer to their [AnimatedReorderableState]
/// with the static [AnimatedReorderable.of] method.
final class AnimatedReorderableState extends State<AnimatedReorderable>
    with TickerProviderStateMixin {
  late final AnimatedReorderableController _controller;
  ScrollController? _ownScrollController;

  _WrappedView get _view => widget._view;

  @override
  void initState() {
    super.initState();

    _controller = AnimatedReorderableController(
      keyGetter: widget.keyGetter,
      motion: widget.motion,
      reorder: widget.reorder,
      swipeToRemove: widget.swipeToRemove,
      insertTransition: widget.insertTransition,
      scrollDirection: _view.scrollDirection,
      isGrid: _view is _WrappedGridView,
      clipBehavior: _view.clipBehavior,
      itemCount: childrenDelegateSettingsOf(_view.childrenDelegate).childCount,
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _controller
      ..scrollSync.scrollController = _effectiveScrollController
      ..group = GroupScope.maybeOf(context)
      ..boardScroll.board = Scrollable.maybeOf(
        context,
        axis: flipAxis(_view.scrollDirection),
      );
  }

  @override
  void didUpdateWidget(AnimatedReorderable oldWidget) {
    super.didUpdateWidget(oldWidget);

    _controller
      ..keyGetter = widget.keyGetter
      ..motion = widget.motion
      ..reorder = widget.reorder
      ..swipeToRemove = widget.swipeToRemove
      ..insertTransition = widget.insertTransition
      ..scrollDirection = _view.scrollDirection
      ..isGrid = _view is _WrappedGridView
      ..clipBehavior = _view.clipBehavior
      ..scrollSync.scrollController = _effectiveScrollController;
  }

  /// The wrapped view's controller or, if the view is primary, the
  /// [PrimaryScrollController], decided the way [ScrollView] decides it.
  /// The view is then built with that controller and `primary: false`.
  ScrollController get _effectiveScrollController {
    final primary =
        _view.primary ??
        (_view.controller == null &&
            PrimaryScrollController.shouldInherit(
              context,
              _view.scrollDirection,
            ));
    final scrollController = primary
        ? PrimaryScrollController.maybeOf(context)
        : _view.controller;
    return scrollController ?? (_ownScrollController ??= ScrollController());
  }

  /// Inserts an item at `index`, which enters through the
  /// [AnimatedReorderable.insertTransition] for `duration`:
  ///
  /// ```dart
  /// _items.insert(index, newItem);
  /// animatedReorderableKey.currentState!.insertItem(index);
  /// ```
  ///
  /// This method's semantics are the same as Dart's [List.insert] method: it
  /// increases the length of the list of items by one and shifts
  /// all items at or after `index` towards the end of the list of items.
  void insertItem(
    int index, {
    Duration duration = defaultInsertItemAnimationDuration,
  }) => _controller.insertItem(index, duration);

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
    _controller
      ..group = null
      ..dispose();
    _ownScrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CrossAxisResizeListener(
    scrollDirection: _view.scrollDirection,
    // A grid keeps its first visible item in place when its cross axis
    // resizes.
    onResize: _controller.scrollSync.anchorFirstVisibleGridItem,
    // The layers build again with the new constraints, so the overlayed
    // items fit the new layout.
    builder: (context) => Stack(
      children: [
        OverlayedItemsLayer(
          controller: _controller,
          clipBehavior: _view.clipBehavior,
          underTheList: true,
        ),
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
              collectionViewBuilder: (context) => _view.build(_controller),
            ),
          ),
        ),
        OverlayedItemsLayer(
          controller: _controller,
          clipBehavior: _view.clipBehavior,
        ),
      ],
    ),
  );
}

/// The list or grid view an [AnimatedReorderable] wraps. It builds the view
/// again, with the controller's children and scrolling (GoF Bridge).
sealed class _WrappedView {
  const _WrappedView();

  ScrollView get scrollView;
  ScrollController? get controller => scrollView.controller;
  bool? get primary => scrollView.primary;
  SliverChildDelegate get childrenDelegate;
  Clip get clipBehavior => scrollView.clipBehavior;
  Axis get scrollDirection => scrollView.scrollDirection;

  Widget build(AnimatedReorderableController controller);
}

final class _WrappedListView extends _WrappedView {
  const _WrappedListView(this.listView);

  final ListView listView;

  @override
  ScrollView get scrollView => listView;

  @override
  SliverChildDelegate get childrenDelegate => listView.childrenDelegate;

  @override
  Widget build(AnimatedReorderableController controller) => ListView.custom(
    key: listView.key,
    scrollDirection: scrollDirection,
    reverse: listView.reverse,
    controller: controller.scrollSync.scrollController,
    primary: false,
    physics: AnchoredScrollPhysics(
      anchor: controller.scrollSync.anchoredScrollOffset,
      onAdjust: controller.didAdjustScrollOffset,
      parent: listView.physics,
    ),
    shrinkWrap: listView.shrinkWrap,
    padding: listView.padding,
    itemExtent: listView.itemExtent,
    prototypeItem: listView.prototypeItem,
    itemExtentBuilder: listView.itemExtentBuilder,
    childrenDelegate: controller.itemWidgets.overrideChildrenDelegate(
      childrenDelegate,
    ),
    // ignore: deprecated_member_use
    cacheExtent: listView.cacheExtent,
    scrollCacheExtent: listView.scrollCacheExtent,
    semanticChildCount: listView.semanticChildCount,
    dragStartBehavior: listView.dragStartBehavior,
    keyboardDismissBehavior: listView.keyboardDismissBehavior,
    restorationId: listView.restorationId,
    clipBehavior: clipBehavior,
    hitTestBehavior: listView.hitTestBehavior,
  );
}

final class _WrappedGridView extends _WrappedView {
  const _WrappedGridView(this.gridView);

  final GridView gridView;

  @override
  ScrollView get scrollView => gridView;

  @override
  SliverChildDelegate get childrenDelegate => gridView.childrenDelegate;

  @override
  Widget build(AnimatedReorderableController controller) => GridView.custom(
    key: gridView.key,
    scrollDirection: scrollDirection,
    reverse: gridView.reverse,
    controller: controller.scrollSync.scrollController,
    primary: false,
    physics: AnchoredScrollPhysics(
      anchor: controller.scrollSync.anchoredScrollOffset,
      onAdjust: controller.didAdjustScrollOffset,
      parent: gridView.physics,
    ),
    shrinkWrap: gridView.shrinkWrap,
    padding: gridView.padding,
    gridDelegate: SliverGridLayoutNotifier(
      gridDelegate: gridView.gridDelegate,
      onLayout: controller.scrollSync.didLayOutGrid,
    ),
    childrenDelegate: controller.itemWidgets.overrideChildrenDelegate(
      childrenDelegate,
    ),
    // ignore: deprecated_member_use
    cacheExtent: gridView.cacheExtent,
    scrollCacheExtent: gridView.scrollCacheExtent,
    semanticChildCount: gridView.semanticChildCount,
    dragStartBehavior: gridView.dragStartBehavior,
    keyboardDismissBehavior: gridView.keyboardDismissBehavior,
    restorationId: gridView.restorationId,
    clipBehavior: clipBehavior,
    hitTestBehavior: gridView.hitTestBehavior,
  );
}
