import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' as widgets;

import '../animated_reorderable.dart';
import 'const.dart';
import 'model/model.dart' as model;
import 'model/swipe_direction.dart';
import 'util/geometry.dart';
import 'util/gesture_recognizers.dart';
import 'util/measure_util.dart';
import 'util/overridden_sliver_child_builder_delegate.dart';
import 'util/scheduling.dart';
import 'widget/item_widget.dart';
import 'widget/items_layer.dart';
import 'widget/overlayed_items_layer.dart';

class AnimatedReorderableController implements ItemHost {
  AnimatedReorderableController({
    required this.widget,
    required this.scrollDirection,
    int? itemCount,
    required this.vsync,
  }) : _state = model.ControllerState(itemCount: itemCount);

  /// The current configuration. The state replaces it on every rebuild, so
  /// the getters below always read the latest builders and callbacks.
  AnimatedReorderable widget;
  Axis scrollDirection;
  final widgets.TickerProvider vsync;

  widgets.ScrollController? _scrollController;
  widgets.EdgeDraggingAutoScroller? _autoScroller;
  late OverriddenSliverChildBuilderDelegate _childrenDelegate;
  final model.ControllerState _state;
  ItemsLayerState? _itemsLayer;
  OverlayedItemsLayerState? _overlayedItemsLayer;

  /// Whether the items layer was built since the last reconcile pass.
  bool _itemsLayerBuilt = false;

  /// The items built since the last reconcile pass, in the order they were
  /// built.
  final _builtItems = <model.RenderedItem>{};
  bool _reconcileScheduled = false;

  KeyGetter get keyGetter => widget.keyGetter;
  BoolGetter get reorderableGetter => widget.reorderableGetter ?? (_) => true;
  double get autoScrollerVelocityScalar => widget.autoScrollerVelocityScalar;
  double get swipeToRemoveExtent => widget.swipeToRemoveExtent;
  double get swipeToRemoveVelocity => widget.swipeToRemoveVelocity;
  widgets.SpringDescription get swipeToRemoveSpringDescription =>
      widget.swipeToRemoveSpringDescription;
  ReorderCallback? get onReorder => widget.onReorder;
  SwipeToRemoveCallback? get onSwipeToRemove => widget.onSwipeToRemove;
  Duration get motionAnimationDuration => widget.motionAnimationDuration;
  widgets.Curve get motionAnimationCurve => widget.motionAnimationCurve;
  model.AnimatedItemDecorator? get draggedItemDecorator =>
      widget.draggedItemDecorator;
  Duration get draggedItemDecorationAnimationDuration =>
      widget.draggedItemDecorationAnimationDuration;
  model.AnimatedItemDecorator? get swipedItemDecorator =>
      widget.swipedItemDecorator;
  Duration get swipedItemDecorationAnimationDuration =>
      widget.swipedItemDecorationAnimationDuration;
  ItemDragStartCallback? get onItemDragStart => widget.onItemDragStart;
  ItemDragUpdateCallback? get onItemDragUpdate => widget.onItemDragUpdate;
  ItemDragEndCallback? get onItemDragEnd => widget.onItemDragEnd;
  ItemDragStartCallback? get onItemSwipeStart => widget.onItemSwipeStart;
  ItemDragUpdateCallback? get onItemSwipeUpdate => widget.onItemSwipeUpdate;
  ItemDragEndCallback? get onItemSwipeEnd => widget.onItemSwipeEnd;
  MultiDragGestureRecognizerFactory get reorderGestureRecognizerFactory =>
      widget.reorderGestureRecognizerFactory ??
      createReorderDragGestureRecognizer;

  void insertItem(
    int index,
    widgets.AnimatedItemBuilder builder,
    Duration duration,
  ) {
    RangeError.checkValueInInterval(index, 0, checkedItemCount, 'index');

    final insertedItem = _state.insertItem(
      index: index,
      itemFactory: createItem,
    );

    insertedItem.animateItemBuilder(
      builder: builder,
      duration: duration,
      vsync: vsync,
    );

    overlayedItemsLayer!.rebuild(
      () => overlayRenderedItems(
        except: insertedItem.key,
        newIndex: (x) => x.index >= index ? x.index + 1 : x.index,
      ),
    );

    itemsLayer!.rebuild();
  }

  void removeItem(
    int index,
    widgets.AnimatedRemovedItemBuilder builder,
    Duration duration, {
    int? zIndex,
  }) {
    IndexError.check(index, checkedItemCount, name: 'index');

    final removedItem = _state.removeItem(index: index);
    if (removedItem == null) return;

    final renderedItem = _state.renderedItemBy(key: removedItem.key);
    if (renderedItem == null) {
      removedItem.dispose();
    }

    overlayedItemsLayer!.rebuild(() {
      overlayRenderedItems(
        except: removedItem.key,
        newIndex: (x) => x.index > index ? x.index - 1 : x.index,
      );

      if (renderedItem != null) {
        final outgoingItem = _state.putOverlayedItemIfAbsent(
          key: renderedItem.key,
          ifAbsent: () => createOverlayedItem(
            renderedItem,
            builder: removedItem.builder,
            childKey: removedItem.childKey,
          ),
        );
        outgoingItem
          ..outgoing = true
          // It keeps its size while the removed item builder animates it.
          ..setConstraints(
            widgets.BoxConstraints.tight(outgoingItem.size),
            notify: false,
          )
          ..setInteractive(false, notify: false)
          ..setZIndex(zIndex ?? outgoingItemZIndex, notify: false)
          ..animateRemovedItemBuilder(
            builder: builder,
            duration: duration,
            vsync: vsync,
          ).whenComplete(
            () => overlayedItemsLayer!.rebuild(() {
              _state.removeOverlayedItem(key: removedItem.key)?.dispose();
              removedItem.dispose();
            }),
          );
      }
    });

    itemsLayer!.rebuild();
  }

  void reorderItem(int index, {required int destIndex}) {
    if (onReorder == null) {
      throw StateError(
        'Items can be reordered only with an onReorder callback',
      );
    }
    final itemCount = checkedItemCount;
    IndexError.check(index, itemCount, name: 'index');
    IndexError.check(destIndex, itemCount, name: 'destIndex');
    checkReorderable(index, name: 'index');
    checkReorderable(destIndex, name: 'destIndex');
    if (index == destIndex) return;

    final itemAtIndex = ensureItemAt(index: index);
    final itemAtDestIndex = ensureItemAt(index: destIndex);

    final permutations = _state.moveItem(
      index: index,
      destIndex: destIndex,
      reorderableGetter: reorderableGetter,
      itemFactory: createItem,
    );

    overlayedItemsLayer!.rebuild(() {
      overlayRenderedItems(
        newIndex: (x) => permutations.indexOf(x.key) ?? x.index,
      );

      overlayNotRenderedItem(
        itemAtIndex,
        index: index,
        newIndex: permutations.indexOf(itemAtIndex.key)!,
      );
      overlayNotRenderedItem(
        itemAtDestIndex,
        index: destIndex,
        newIndex: permutations.indexOf(itemAtDestIndex.key)!,
      );
    });

    itemsLayer!.rebuild(() => onReorder!.call(permutations));
  }

  /// The item count, which a list or grid needs for its items to change.
  int get checkedItemCount =>
      _state.itemCount ??
      (throw StateError(
        'Items can be inserted, removed and reordered only in a '
        '${widgets.ListView} or ${widgets.GridView} with an item count',
      ));

  void checkReorderable(int index, {required String name}) {
    if (!reorderableGetter(index)) {
      throw ArgumentError.value(index, name, 'is not reorderable');
    }
  }

  void dispose() {
    _scrollController?.removeListener(handleScroll);
    _state.dispose();
  }

  Iterable<model.OverlayedItem> get overlayedItemsOrderedByZIndex =>
      _state.overlayedItems.toList()
        ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

  bool isDragged(model.RenderedItem item) => _state.isDragged(key: item.key);

  bool isSwiped(model.RenderedItem item) => _state.isSwiped(key: item.key);

  bool isNotDragged(model.RenderedItem item) => !isDragged(item);

  bool isNotSwiped(model.RenderedItem item) => !isSwiped(item);

  bool isRendered(model.OverlayedItem item) => _state.isRendered(key: item.key);

  bool isNotRendered(model.OverlayedItem item) => !isRendered(item);

  ItemsLayerState? get itemsLayer => _itemsLayer;

  OverlayedItemsLayerState? get overlayedItemsLayer => _overlayedItemsLayer;

  /// The layers attach themselves while they are mounted.
  void attachItemsLayer(ItemsLayerState layer) => _itemsLayer = layer;

  void detachItemsLayer(ItemsLayerState layer) {
    if (_itemsLayer == layer) _itemsLayer = null;
  }

  void attachOverlayedItemsLayer(OverlayedItemsLayerState layer) =>
      _overlayedItemsLayer = layer;

  void detachOverlayedItemsLayer(OverlayedItemsLayerState layer) {
    if (_overlayedItemsLayer == layer) _overlayedItemsLayer = null;
  }

  bool didSwipeToRemove(
    model.OverlayedItem item, {
    required Velocity velocity,
  }) =>
      item.swipeToRemoveDirection?.removes(
        extent: item.swipeExtent,
        velocity: velocity,
        minExtent: swipeToRemoveExtent,
        minVelocity: swipeToRemoveVelocity,
      ) ??
      false;

  model.Item ensureItemAt({required int index}) =>
      _state.itemAt(index: index) ?? spawnItemAt(index: index);

  model.Item spawnItemAt({required int index}) {
    final item = createItem(index);
    _state.putItem(item);
    _state.setIndex(itemKey: item.key, index: index);
    return item;
  }

  model.Item createItem(int index) => model.Item(
    key: keyGetter(index),
    builder: model.ItemBuilder.adaptIndexedWidgetBuilder(
      (context, index) => childrenDelegate.originalBuilder(context, index),
    ),
  );

  model.OverlayedItem createOverlayedItem(
    model.RenderedItem renderedItem, {
    MultiDragGestureRecognizerFactory? recognizerFactory,
    model.ItemBuilder? builder,
    widgets.GlobalKey? childKey,
  }) {
    final item = _state.itemBy(key: renderedItem.key);
    return model.OverlayedItem(
      index: renderedItem.index,
      key: renderedItem.key,
      position: overlayedItemsLayer!.globalToLocal(
        renderedItem.globalPosition!,
      )!,
      // The item lays out in the overlay as it would in the list.
      constraints:
          renderedItem.constraints ??
          widgets.BoxConstraints.tight(renderedItem.size!),
      size: renderedItem.size!,
      builder: builder ?? model.ItemBuilder.proxy(item!),
      childKey: childKey ?? item!.childKey,
      recognizerFactory: recognizerFactory,
    )..addListener(overlayedItemsLayer!.rebuild);
  }

  /// Overlays the rendered items, except [except] and the held ones, so
  /// they can move to their slots at [newIndex] when the list lays out.
  void overlayRenderedItems({
    required int Function(model.RenderedItem item) newIndex,
    widgets.Key? except,
  }) {
    for (var renderedItem
        in _state.renderedItems
            .where((x) => x.key != except)
            .where(isNotDragged)
            .where(isNotSwiped)) {
      _state.putOverlayedItemIfAbsent(
          key: renderedItem.key,
          ifAbsent: () => createOverlayedItem(renderedItem),
        )
        ..index = newIndex(renderedItem)
        ..setInteractive(false, notify: false);
    }
  }

  /// Overlays [item], which was at [index] and is neither rendered nor
  /// overlayed, just outside the overlay, so it can move in to its slot at
  /// [newIndex] when the list lays out.
  void overlayNotRenderedItem(
    model.Item item, {
    required int index,
    required int newIndex,
  }) {
    if (_state.isRendered(key: item.key)) return;
    if (_state.isOverlayed(key: item.key)) return;

    final fakeGeometry = getFakeAnchorGeometryOfNotRenderedItem(
      notRenderedItemIndex: index,
      anyRenderedItem: _state.renderedItems.first,
    );

    _state
        .putOverlayedItem(
          model.OverlayedItem(
            index: newIndex,
            key: item.key,
            position: fakeGeometry.topLeft,
            constraints: widgets.BoxConstraints.tight(fakeGeometry.size),
            size: fakeGeometry.size,
            builder: model.ItemBuilder.proxy(item),
            childKey: item.childKey,
            interactive: false,
          ),
        )
        .addListener(overlayedItemsLayer!.rebuild);
  }

  void registerRenderedItem(model.RenderedItem item) =>
      _state.putRenderedItem(item);

  void unregisterRenderedItem(model.RenderedItem item) {
    final registeredRenderedItem = _state.renderedItemBy(key: item.key);
    if (registeredRenderedItem == item) {
      _state.removeRenderedItemBy(key: item.key);
    }
  }

  void reorderAndAutoScrollIfNecessary() {
    reorderDraggedItemIfNecessary();
    autoScrollIfNecessary();
  }

  void reorderDraggedItemIfNecessary() {
    if (onReorder == null) return;
    if (_state.draggedItem == null) return;

    final item = _state.draggedItem!;

    if (!reorderableGetter(item.index)) return;

    final pointerPosition = item.globalPointerPosition!;
    final renderedItem = _state.renderedItemAt(position: pointerPosition);

    if (renderedItem?.key == _state.itemUnderThePointerKey) return;
    _state.itemUnderThePointerKey = renderedItem?.key;

    if (renderedItem == null) return;
    if (renderedItem.key == item.key) return;
    if (!renderedItem.reorderable) return;

    reorderItem(item.index, destIndex: renderedItem.index);

    addPostFrame(
      () => _state.itemUnderThePointerKey = _state
          .renderedItemAt(position: pointerPosition)
          ?.key,
    );
  }

  void unoverlay(model.OverlayedItem item) {
    if (_state.overlayedItemBy(key: item.key) != item) return;
    if (item.outgoing) return;
    overlayedItemsLayer?.rebuild(
      () => _state.removeOverlayedItem(key: item.key),
    );
    _state.renderedItemBy(key: item.key)?.rebuild();
    addPostFrame(() {
      if (_state.overlayedItemBy(key: item.key) != item) item.dispose();
    });
  }

  widgets.Rect getFakeAnchorGeometryOfNotRenderedItem({
    required int notRenderedItemIndex,
    required model.RenderedItem anyRenderedItem,
    widgets.Size? itemSize,
  }) {
    final gridLayout = _state.gridLayout;
    itemSize ??=
        gridLayout?.getChildSize(notRenderedItemIndex, scrollDirection) ??
        // A list lays out all its items with the same constraints.
        measureItemWidgetAt(
          index: notRenderedItemIndex,
          constraints: anyRenderedItem.constraints,
        );

    // Just outside the overlay, which covers the list. It is the space the
    // overlayed items are positioned in, unlike the screen.
    final bounds = Offset.zero & overlayedItemsLayer!.size!;
    // In line with a list's items, or in the middle of a grid.
    final anyRenderedItemPosition = gridLayout == null
        ? anyRenderedItem.globalPosition
        : null;
    final crossAxisPosition = anyRenderedItemPosition != null
        ? overlayedItemsLayer!.globalToLocal(anyRenderedItemPosition)!
        : bounds.center - Offset(itemSize.width / 2, itemSize.height / 2);
    final before = notRenderedItemIndex < anyRenderedItem.index;
    final fakePosition = switch (scrollPosition!.axisDirection) {
      AxisDirection.down => Offset(
        crossAxisPosition.dx,
        before ? bounds.top - itemSize.height : bounds.bottom,
      ),
      AxisDirection.right => Offset(
        before ? bounds.left - itemSize.width : bounds.right,
        crossAxisPosition.dy,
      ),
      AxisDirection.up => Offset(
        crossAxisPosition.dx,
        before ? bounds.bottom : bounds.top - itemSize.height,
      ),
      AxisDirection.left => Offset(
        before ? bounds.right : bounds.left - itemSize.width,
        crossAxisPosition.dy,
      ),
    };

    return fakePosition & itemSize;
  }

  Size measureItemWidgetAt({required int index, BoxConstraints? constraints}) =>
      MeasureUtil.measureWidget(
        context: scrollPosition!.context.storageContext,
        builder: (context) =>
            _childrenDelegate.originalBuilder(context, index)!,
        constraints:
            constraints ??
            (scrollDirection == Axis.vertical
                ? BoxConstraints(maxWidth: _state.constraints!.maxWidth)
                : BoxConstraints(maxHeight: _state.constraints!.maxHeight)),
      );

  Size getScreenSize() {
    final screenView =
        widgets.WidgetsBinding.instance.platformDispatcher.views.first;
    return screenView.physicalSize / screenView.devicePixelRatio;
  }

  bool isItemRendered(int index) {
    return getRenderedItemAt(index) != null;
  }

  model.RenderedItem? getRenderedItemAt(int index) =>
      _state.renderedItems.where((x) => x.index == index).firstOrNull;

  @override
  bool isReorderable(int index) => reorderableGetter(index);

  @override
  bool isDraggable(int index) => widget.draggableGetter?.call(index) ?? true;

  @override
  SwipeDirection? swipeToRemoveDirectionAt(int index) {
    if (widget.onSwipeToRemove == null) return null;
    final getter = widget.swipeToRemoveDirectionGetter;
    if (getter == null) return SwipeDirection.across(scrollDirection);
    return switch (getter(index)) {
      final direction? => SwipeDirection.of(direction),
      null => null,
    };
  }

  @override
  Size? overlayedSizeOf(widgets.Key key) =>
      _state.overlayedItemBy(key: key)?.size;

  @override
  void didInitItem(model.RenderedItem item) => registerRenderedItem(item);

  @override
  void didChangeItemIndex(model.RenderedItem item) {
    unregisterRenderedItem(item);
    registerRenderedItem(item);
  }

  @override
  void didDeactivateItem(model.RenderedItem item) =>
      unregisterRenderedItem(item);

  @override
  void didBuildItem(model.RenderedItem item) {
    _builtItems.add(item);
    _scheduleReconcile();
  }

  void didBuildItemsLayer() {
    _itemsLayerBuilt = true;
    _scheduleReconcile();
  }

  void _scheduleReconcile() {
    if (_reconcileScheduled) return;
    _reconcileScheduled = true;
    addPostFrame(_reconcile);
  }

  /// Brings the overlay in line with what was built, once the frame has
  /// laid it out: first the items layer, then the items in the order they
  /// were built.
  void _reconcile() {
    _reconcileScheduled = false;
    if (_itemsLayerBuilt) {
      _itemsLayerBuilt = false;
      reconcileItemsLayer();
    }
    final builtItems = _builtItems.toList();
    _builtItems.clear();
    builtItems.forEach(reconcileItem);
  }

  /// Moves the overlayed item of [item] to where the list laid [item] out.
  void reconcileItem(model.RenderedItem item) {
    final overlayedItem = _state.overlayedItemBy(key: item.key);
    if (overlayedItem == null || overlayedItem.outgoing) return;

    // They change when the list resizes.
    final constraints = item.constraints;
    if (constraints != null && constraints != overlayedItem.constraints) {
      overlayedItem.setConstraints(constraints);
      if (isDragged(item)) {
        // Its new size, unless its main axis extent changes too.
        final size = constraints.constrain(overlayedItem.size);
        keepUnderPointer(overlayedItem, size: size);
        overlayedItem.size = size;
      }
    }

    if (isDragged(item)) return;

    final globalPosition = item.globalPosition;
    if (globalPosition == null) return;

    final anchorPosition = overlayedItemsLayer!.globalToLocal(globalPosition)!;

    if (isSwiped(item)) {
      // It stays in its slot, swiped as far.
      overlayedItem.setPosition(anchorPosition + overlayedItem.swipeOffset);
      return;
    }

    if (overlayedItem.anchorPosition != anchorPosition) {
      overlayedItem
          .animateTo(
            anchorPosition,
            vsync: vsync,
            duration: motionAnimationDuration,
            curve: motionAnimationCurve,
          )
          .whenComplete(() => unoverlay(overlayedItem));
    } else if (!(overlayedItem.motionAnimationStatus?.isAnimating ?? false)) {
      unoverlay(overlayedItem);
    }
  }

  @override
  void recognizeReorderDrag(model.RenderedItem item, PointerDownEvent event) =>
      createOverlayedItem(
        item,
        recognizerFactory: reorderGestureRecognizerFactory,
      ).recognizeDrag(
        event,
        context: item.context,
        onDragStart: (details, overlayedItem) {
          overlayedItem.recognizerFactory =
              createImmediateDragGestureRecognizer;
          handleItemDragStart(details, overlayedItem);
        },
        onDragUpdate: handleItemDragUpdate,
        onDragEnd: handleItemDragEnd,
      );

  @override
  void recognizeSwipe(model.RenderedItem item, PointerDownEvent event) {
    final swipeDirection = item.swipeToRemoveDirection!;
    createOverlayedItem(
      item,
      recognizerFactory: swipeDirection.recognizerFactory,
    ).recognizeSwipe(
      event,
      context: item.context,
      swipeDirection: swipeDirection,
      onSwipeStart: handleItemSwipeStart,
      onSwipeUpdate: handleItemSwipeUpdate,
      onSwipeEnd: handleItemSwipeEnd,
    );
  }
}

extension OverlayedItemSizeChangeHandler on AnimatedReorderableController {
  /// The list's placeholder follows the item's size in the overlay.
  void handleOverlayedItemSizeChange(Size size, model.OverlayedItem item) {
    if (item.size == size) return;
    if (_state.isDragged(key: item.key)) keepUnderPointer(item, size: size);
    item.size = size;
    if (_state.overlayedItemBy(key: item.key) != item) return;
    _state.renderedItemBy(key: item.key)?.rebuild();
  }
}

extension DraggedItemPlacement on AnimatedReorderableController {
  /// Keeps the pointer over the same point of a dragged item, relative to
  /// its size, when the item is about to change its [size].
  void keepUnderPointer(model.OverlayedItem item, {required Size size}) {
    final globalPointerPosition = item.globalPointerPosition;
    if (globalPointerPosition == null || item.size.isEmpty) return;
    final pointer = overlayedItemsLayer!.globalToLocal(globalPointerPosition)!;
    final grip = pointer - item.position;
    item.setPosition(
      pointer -
          Offset(
            grip.dx * size.width / item.size.width,
            grip.dy * size.height / item.size.height,
          ),
    );
  }
}

extension ItemsLayerReconciliation on AnimatedReorderableController {
  /// Fits removed items to the layout and moves the overlayed items that
  /// the list did not build out of sight.
  void reconcileItemsLayer() {
    fitOutgoingItemsToLayout();

    for (var overlayedItem
        in _state.overlayedItems
            .where(isNotRendered)
            .where((x) => !x.outgoing)
            .toList()) {
      final fakeGeometry = getFakeAnchorGeometryOfNotRenderedItem(
        notRenderedItemIndex: overlayedItem.index,
        anyRenderedItem: _state.renderedItems.first,
        itemSize: overlayedItem.size,
      );

      overlayedItem
          .animateTo(
            fakeGeometry.topLeft,
            vsync: vsync,
            duration: motionAnimationDuration,
            curve: motionAnimationCurve,
          )
          .whenComplete(() => unoverlay(overlayedItem));
    }
  }

  /// A removed item has no slot any more. It fades out in place, as wide
  /// as the list's slots (or as big as the grid's) after a resize.
  void fitOutgoingItemsToLayout() {
    for (var item in _state.overlayedItems.where((x) => x.outgoing)) {
      final slot =
          getRenderedItemAt(item.index) ?? _state.renderedItems.firstOrNull;
      final constraints = slot?.constraints;
      if (constraints == null) continue;
      item.setConstraints(
        constraints.tighten(width: item.size.width, height: item.size.height),
      );
    }
  }
}

/// What dragged and swiped items have in common.
extension HeldItemMotion on AnimatedReorderableController {
  /// Lifts [item] above the other items, into the overlay if it is not
  /// there yet, and decorates it with [decorator].
  void lift(
    model.OverlayedItem item, {
    required model.AnimatedItemDecorator? decorator,
    required Duration decorationDuration,
  }) {
    if (!_state.isOverlayed(key: item.key)) {
      overlayedItemsLayer?.rebuild(
        () =>
            _state.putOverlayedItem(item)..setZIndex(maxZIndex, notify: false),
      );
      _state.renderedItemBy(key: item.key)?.rebuild();
    } else {
      item.setZIndex(maxZIndex);
    }

    item.animateDecoration(
      decorator: decorator,
      duration: decorationDuration,
      vsync: vsync,
    );
  }

  /// Flings [item] back to its slot in the list, and takes it out of the
  /// overlay once it is there and [undecoration] is done.
  void flingBackToSlot(
    model.OverlayedItem item, {
    required Future undecoration,
    required Velocity velocity,
    widgets.SpringDescription springDescription = defaultFlingSpringDescription,
  }) {
    Future.wait([
      undecoration,
      item.animateFlingTo(
        overlayedItemsLayer!.globalToLocal(
          _state.renderedItemBy(key: item.key)!.globalPosition!,
        )!,
        velocity: velocity,
        screenSize: getScreenSize(),
        springDescription: springDescription,
        vsync: vsync,
      ),
    ]).whenComplete(() => unoverlay(item));
  }
}

extension OverlayedItemDragHandlers on AnimatedReorderableController {
  void handleItemDragStart(
    widgets.DragStartDetails details,
    model.OverlayedItem item,
  ) {
    onItemDragStart?.call(details, item.index);

    item.stopMotion();

    _state.draggedItem = item;

    lift(
      item,
      decorator: draggedItemDecorator,
      decorationDuration: draggedItemDecorationAnimationDuration,
    );
  }

  void handleItemDragUpdate(
    widgets.DragUpdateDetails details,
    model.OverlayedItem item,
  ) {
    onItemDragUpdate?.call(details, item.index);

    item.shift(details.delta);

    reorderAndAutoScrollIfNecessary();
  }

  void handleItemDragEnd(
    widgets.DragEndDetails details,
    model.OverlayedItem item,
  ) {
    onItemDragEnd?.call(details, item.index);

    _state.draggedItem = null;

    stopAutoScroll(forceStopAnimation: true);

    flingBackToSlot(
      item,
      undecoration: item.animateUndecoration(),
      velocity: details.velocity,
    );
  }
}

extension OverlayedItemSwipeHandlers on AnimatedReorderableController {
  void handleItemSwipeStart(
    widgets.DragStartDetails details,
    model.OverlayedItem item,
  ) {
    onItemSwipeStart?.call(details, item.index);

    item.stopMotion();

    _state.swipedItem = item;

    lift(
      item,
      decorator: swipedItemDecorator,
      decorationDuration: swipedItemDecorationAnimationDuration,
    );
  }

  void handleItemSwipeUpdate(
    widgets.DragUpdateDetails details,
    model.OverlayedItem item,
  ) {
    onItemSwipeUpdate?.call(details, item.index);

    item.shift(details.delta);
  }

  void handleItemSwipeEnd(
    widgets.DragEndDetails details,
    model.OverlayedItem item,
  ) {
    onItemSwipeEnd?.call(details, item.index);

    _state.swipedItem = null;

    final undecoration = item.animateUndecoration();
    final bounds = overlayedItemsLayer!.size!;

    if (didSwipeToRemove(item, velocity: details.velocity)) {
      onSwipeToRemove!.call(item.index);

      item.animateFlingTo(
        item.swipeToRemoveDirection!.flingTarget(
          item.position,
          itemSize: item.size,
          bounds: bounds,
        ),
        velocity: details.velocity,
        screenSize: getScreenSize(),
        springDescription: swipeToRemoveSpringDescription,
        vsync: vsync,
      );
    } else {
      flingBackToSlot(
        item,
        undecoration: undecoration,
        velocity: details.velocity,
        springDescription: swipeToRemoveSpringDescription,
      );
    }
  }
}

extension ScrollHandler on AnimatedReorderableController {
  void handleScroll() {
    final delta = markScrollOffset();

    for (var x
        in _state.overlayedItems
            .where((x) => !_state.isDragged(key: x.key))
            .where((x) => !_state.isSwiped(key: x.key))) {
      x.shift(-delta);
    }
  }
}

extension ConstraintsChangeHandler on AnimatedReorderableController {
  void handleConstraintsChange(BoxConstraints constraints) {
    final oldConstraints = _state.constraints;
    _state.constraints = constraints;
    if (oldConstraints == null) return;

    final scaleFactor = scrollDirection == Axis.vertical
        ? constraints.maxWidth / oldConstraints.maxWidth
        : constraints.maxHeight / oldConstraints.maxHeight;
    // Every rebuild comes here too.
    if (scaleFactor == 1) return;

    anchorFirstVisibleGridItem();
  }
}

extension SliverGridLayoutChangeHandler on AnimatedReorderableController {
  void handleSliverGridLayoutChange(
    SliverGridLayout layout,
    SliverConstraints constraints,
  ) {
    _state.gridLayout = layout;
    _state.gridPrecedingScrollExtent = constraints.precedingScrollExtent;
  }
}

/// A grid's layout changes with its cross axis, so a grid keeps its first
/// visible item in place when the cross axis resizes. A list needs nothing:
/// its items keep their scroll offsets, as in a plain [widgets.ListView].
extension GridScrollAnchoring on AnimatedReorderableController {
  /// Remembers the first visible item before the grid lays out again.
  void anchorFirstVisibleGridItem() {
    final layout = _state.gridLayout;
    final itemCount = _state.itemCount ?? 0;
    final scrollPosition = this.scrollPosition;
    if (layout == null || itemCount == 0) return;
    if (scrollPosition == null || !scrollPosition.hasPixels) return;

    final scrollOffset =
        scrollPosition.pixels - _state.gridPrecedingScrollExtent;
    final index = math.min(
      layout.getMinChildIndexForScrollOffset(math.max(0.0, scrollOffset)),
      itemCount - 1,
    );
    final geometry = layout.getGeometryForChildIndex(index);
    _state.scrollAnchor = (
      index: index,
      leadingEdge: geometry.scrollOffset - scrollOffset,
      extent: geometry.mainAxisExtent,
    );
    addPostFrame(() => _state.scrollAnchor = null);

    // Makes the viewport ask its physics for a correction even if the
    // grid's scroll extent stays the same.
    scrollPosition.correctBy(0.0);
  }

  /// The scroll offset that keeps the anchored item in place in the grid's
  /// new layout. The grid has laid out by the time its viewport asks.
  double? anchoredScrollOffset(widgets.ScrollMetrics position) {
    final anchor = _state.scrollAnchor;
    final layout = _state.gridLayout;
    if (anchor == null || layout == null) return null;
    _state.scrollAnchor = null;

    final geometry = layout.getGeometryForChildIndex(anchor.index);
    // An item partly scrolled away keeps the same part of it hidden.
    final leadingEdge = anchor.leadingEdge < 0 && anchor.extent > 0
        ? anchor.leadingEdge * geometry.mainAxisExtent / anchor.extent
        : anchor.leadingEdge;
    return _state.gridPrecedingScrollExtent +
        geometry.scrollOffset -
        leadingEdge;
  }
}

extension ChildrenDelegate on AnimatedReorderableController {
  OverriddenSliverChildBuilderDelegate get childrenDelegate =>
      _childrenDelegate;
  set childrenDelegate(OverriddenSliverChildBuilderDelegate value) =>
      _childrenDelegate = value;

  widgets.SliverChildDelegate overrideChildrenDelegate(
    widgets.SliverChildDelegate delegate,
  ) => childrenDelegate = OverriddenSliverChildBuilderDelegate.override(
    delegate: delegate,
    overriddenChildBuilder: buildItemWidget,
    overriddenChildCountGetter: () => _state.itemCount,
    fallbackChildIndexGetter: _state.childIndexGetter(),
  );

  widgets.Widget buildItemWidget(widgets.BuildContext context, int index) {
    final item = ensureItemAt(index: index);

    return ItemWidget(
      key: item.key,
      index: index,
      childKey: item.childKey,
      builder: item.builder.build,
      host: this,
    );
  }
}

extension Scrolling on AnimatedReorderableController {
  widgets.ScrollController? get scrollController => _scrollController;

  set scrollController(widgets.ScrollController? value) {
    if (_scrollController == value) return;
    addPostFrame(() {
      setupAutoscroller();
      markScrollOffset();
    });
    _scrollController?.removeListener(handleScroll);
    (_scrollController = value)?.addListener(handleScroll);
  }

  /// The position of the wrapped view's own [widgets.Scrollable]. The scroll
  /// controller can be shared, like the [widgets.PrimaryScrollController],
  /// so it can have other positions too.
  widgets.ScrollPosition? get scrollPosition {
    final itemsLayer = this.itemsLayer;
    if (itemsLayer == null) return null;
    return _scrollController?.positions
        .where(
          (position) =>
              position.context.storageContext
                  .findAncestorStateOfType<ItemsLayerState>() ==
              itemsLayer,
        )
        .firstOrNull;
  }

  void setupAutoscroller() {
    final scrollPosition = this.scrollPosition;
    if (scrollPosition == null) return;

    _autoScroller = widgets.EdgeDraggingAutoScroller(
      scrollPosition.context as widgets.ScrollableState,
      velocityScalar: autoScrollerVelocityScalar,
      onScrollViewScrolled: () => reorderAndAutoScrollIfNecessary(),
    );
  }

  void autoScrollIfNecessary() {
    if (_state.draggedItem == null) return;

    final size = _state.draggedItem!.size;
    final position = overlayedItemsLayer!.localToGlobal(
      _state.draggedItem!.position,
    )!;

    _autoScroller?.startAutoScrollIfNecessary(
      (position & size).deflate(autoScrollEdgeInset),
    );
  }

  void stopAutoScroll({bool forceStopAnimation = false}) {
    _autoScroller?.stopAutoScroll();

    final scrollPosition = this.scrollPosition;
    if (forceStopAnimation && scrollPosition != null) {
      scrollPosition.jumpTo(scrollPosition.pixels);
    }
  }

  Offset markScrollOffset() {
    final scrollPosition = this.scrollPosition;
    if (scrollPosition == null) return Offset.zero;

    final scrollOffset = scrollPosition.toRelativeOffset();
    final delta = scrollOffset - _state.scrollOffset;
    _state.scrollOffset = scrollOffset;
    return delta;
  }
}
