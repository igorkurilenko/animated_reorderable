import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' as widgets;

import '../animated_reorderable.dart';
import 'const.dart';
import 'controller/overlay_coordinator.dart';
import 'controller/scroll_sync.dart';
import 'model/model.dart' as model;
import 'model/swipe_direction.dart';
import 'util/gesture_recognizers.dart';
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

  late final scrollSync = ScrollSync(
    isOwnPosition: (position) {
      final itemsLayer = _itemsLayer;
      return itemsLayer != null &&
          position.context.storageContext
                  .findAncestorStateOfType<ItemsLayerState>() ==
              itemsLayer;
    },
    velocityScalar: () => autoScrollerVelocityScalar,
    itemCount: () => _state.itemCount ?? 0,
    onScroll: _shiftOverlayedItems,
    onAutoScroll: reorderAndAutoScrollIfNecessary,
  );
  late OverriddenSliverChildBuilderDelegate _childrenDelegate;
  final model.ControllerState _state;
  ItemsLayerState? _itemsLayer;
  OverlayCoordinator? _overlay;

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

    _overlay?.overlayRenderedItems(
      except: insertedItem.key,
      newIndex: (x) => x.index >= index ? x.index + 1 : x.index,
    );
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

    final overlay = _overlay;
    if (overlay == null) {
      _state.releaseRemovedItem(removedItem);
      return;
    }

    overlay
      ..overlayRenderedItems(
        except: removedItem.key,
        newIndex: (x) => x.index > index ? x.index - 1 : x.index,
      )
      ..animateOut(
        removedItem,
        renderedItem: _state.renderedItemBy(key: removedItem.key),
        builder: builder,
        duration: duration,
        zIndex: zIndex ?? outgoingItemZIndex,
      );
  }

  void reorderItem(int index, {required int destIndex}) {
    final onReorder =
        this.onReorder ??
        (throw StateError(
          'Items can be reordered only with an onReorder callback',
        ));
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

    _overlay
      ?..overlayRenderedItems(
        newIndex: (x) => permutations.indexOf(x.key) ?? x.index,
      )
      ..overlayNotRenderedItem(
        itemAtIndex,
        index: index,
        newIndex: permutations.indexOf(itemAtIndex.key)!,
      )
      ..overlayNotRenderedItem(
        itemAtDestIndex,
        index: destIndex,
        newIndex: permutations.indexOf(itemAtDestIndex.key)!,
      );

    onReorder(permutations);
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
    scrollSync.dispose();
    _state.dispose();
  }

  /// What the items layer builds from changes with these.
  widgets.Listenable get itemsChanges => _state.itemsChanges;

  /// What the overlayed items layer builds from changes with these, and
  /// with the overlayed items themselves.
  widgets.Listenable get overlayChanges => _state.overlayChanges;

  /// The overlayed and outgoing items, from the bottom one up.
  Iterable<model.OverlayedItem> get overlayedItemsOrderedByZIndex =>
      _state.overlayedItemsByZIndex;

  /// The layers attach themselves while they are mounted.
  void attachItemsLayer(ItemsLayerState layer) => _itemsLayer = layer;

  void detachItemsLayer(ItemsLayerState layer) {
    if (_itemsLayer == layer) _itemsLayer = null;
  }

  /// Items move between the list and the overlay while the overlay is
  /// attached.
  void attachOverlayedItemsLayer(OverlayedItemsLayerState layer) =>
      _overlay = OverlayCoordinator(
        overlay: layer,
        items: _state,
        scrollSync: scrollSync,
        vsync: vsync,
        motionAnimationDuration: () => motionAnimationDuration,
        motionAnimationCurve: () => motionAnimationCurve,
        scrollDirection: () => scrollDirection,
        itemBuilder: () => childrenDelegate.originalBuilder,
      );

  void detachOverlayedItemsLayer(OverlayedItemsLayerState layer) {
    if (_overlay?.overlay == layer) _overlay = null;
  }

  void handleOverlayedItemSizeChange(Size size, model.OverlayedItem item) =>
      _overlay?.didResizeItem(size, item);

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

  void registerRenderedItem(model.RenderedItem item) =>
      _state.putRenderedItem(item);

  void unregisterRenderedItem(model.RenderedItem item) {
    final registeredRenderedItem = _state.renderedItemBy(key: item.key);
    if (registeredRenderedItem == item) {
      _state.removeRenderedItemBy(key: item.key);
    }
  }

  widgets.ScrollPosition? get scrollPosition => scrollSync.scrollPosition;

  void _shiftOverlayedItems(Offset delta) =>
      _overlay?.shiftOverlayedItems(delta);

  void reorderAndAutoScrollIfNecessary() {
    reorderDraggedItemIfNecessary();
    autoScrollIfNecessary();
  }

  void autoScrollIfNecessary() {
    final item = _state.draggedItem;
    if (item == null) return;

    final rect = _overlay?.globalRectOf(item);
    if (rect != null) scrollSync.autoScroll(rect);
  }

  void reorderDraggedItemIfNecessary() {
    final item = _state.draggedItem;
    final pointerPosition = item?.globalPointerPosition;
    if (onReorder == null || item == null || pointerPosition == null) return;
    if (!reorderableGetter(item.index)) return;

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
    final itemsLayerBuilt = _itemsLayerBuilt;
    final builtItems = _builtItems.toList();
    _itemsLayerBuilt = false;
    _builtItems.clear();

    final overlay = _overlay;
    if (overlay == null) return;
    if (itemsLayerBuilt) overlay.reconcileItemsLayer();
    builtItems.forEach(overlay.reconcileItem);
  }

  @override
  void recognizeReorderDrag(model.RenderedItem item, PointerDownEvent event) =>
      _overlay
          ?.createOverlayedItem(
            item,
            recognizerFactory: reorderGestureRecognizerFactory,
          )
          .recognizeDrag(
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
    final swipeDirection = item.swipeToRemoveDirection;
    if (swipeDirection == null) return;
    _overlay
        ?.createOverlayedItem(
          item,
          recognizerFactory: swipeDirection.recognizerFactory,
        )
        .recognizeSwipe(
          event,
          context: item.context,
          swipeDirection: swipeDirection,
          onSwipeStart: handleItemSwipeStart,
          onSwipeUpdate: handleItemSwipeUpdate,
          onSwipeEnd: handleItemSwipeEnd,
        );
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

    _overlay?.lift(
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

    scrollSync.stopAutoScroll(forceStopAnimation: true);

    _overlay?.flingBackToSlot(
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

    _overlay?.lift(
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
    final swipeDirection = item.swipeToRemoveDirection;
    final onSwipeToRemove = this.onSwipeToRemove;

    if (swipeDirection != null &&
        onSwipeToRemove != null &&
        didSwipeToRemove(item, velocity: details.velocity)) {
      onSwipeToRemove(item.index);

      _overlay?.flingOut(
        item,
        direction: swipeDirection,
        velocity: details.velocity,
        springDescription: swipeToRemoveSpringDescription,
      );
    } else {
      _overlay?.flingBackToSlot(
        item,
        undecoration: undecoration,
        velocity: details.velocity,
        springDescription: swipeToRemoveSpringDescription,
      );
    }
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
      placeholderSize: item.placeholderSize,
      host: this,
    );
  }
}
