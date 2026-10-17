import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' as widgets;

import '../animated_reorderable.dart';
import 'const.dart';
import 'controller/held_item_sessions.dart';
import 'controller/item_widget_factory.dart';
import 'controller/overlay_coordinator.dart';
import 'controller/scroll_sync.dart';
import 'model/model.dart' as model;
import 'model/swipe_direction.dart';
import 'util/gesture_recognizers.dart';
import 'util/scheduling.dart';
import 'widget/item_widget.dart';
import 'widget/items_layer.dart';
import 'widget/overlayed_items_layer.dart';

class AnimatedReorderableController implements ItemHost {
  AnimatedReorderableController({
    required this.keyGetter,
    required this.motion,
    required this.reorder,
    required this.swipeToRemove,
    required this.scrollDirection,
    int? itemCount,
    required this.vsync,
  }) {
    _items = model.ItemRegistry(itemCount: itemCount, itemFactory: createItem);
  }

  // The current configuration. The state replaces it on every rebuild,
  // and the controller and its collaborators read it when they need it,
  // so they use the latest builders and callbacks.
  KeyGetter keyGetter;
  MotionOptions motion;
  ReorderOptions reorder;
  SwipeToRemoveOptions swipeToRemove;
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
    velocityScalar: () => reorder.autoScrollerVelocityScalar,
    itemCount: () => _items.itemCount ?? 0,
    onScroll: _shiftOverlayedItems,
    onAutoScroll: () => _drag?.reorderAndAutoScroll(),
  );
  late final itemWidgets = ItemWidgetFactory(items: _items, host: this);
  late final model.ItemRegistry _items;
  ItemsLayerState? _itemsLayer;
  OverlayCoordinator? _overlay;

  /// The latest drag, which the auto-scroller keeps going.
  DragSession? _drag;

  /// Whether the items layer was built since the last reconcile pass.
  bool _itemsLayerBuilt = false;

  /// The items built since the last reconcile pass, in the order they were
  /// built.
  final _builtItems = <model.RenderedItem>{};
  bool _reconcileScheduled = false;

  void insertItem(
    int index,
    widgets.AnimatedItemBuilder builder,
    Duration duration,
  ) {
    RangeError.checkValueInInterval(index, 0, checkedItemCount, 'index');

    final insertedItem = _items.insertItem(index: index);

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

    final removedItem = _items.removeItem(index: index);
    if (removedItem == null) return;

    final overlay = _overlay;
    if (overlay == null) {
      _items.releaseRemovedItem(removedItem);
      return;
    }

    overlay
      ..overlayRenderedItems(
        except: removedItem.key,
        newIndex: (x) => x.index > index ? x.index - 1 : x.index,
      )
      ..animateOut(
        removedItem,
        renderedItem: _items.renderedItemBy(key: removedItem.key),
        builder: builder,
        duration: duration,
        zIndex: zIndex ?? outgoingItemZIndex,
      );
  }

  void reorderItem(int index, {required int destIndex}) {
    final onReorder =
        reorder.onReorder ??
        (throw StateError(
          'Items can be reordered only with an onReorder callback',
        ));
    final itemCount = checkedItemCount;
    IndexError.check(index, itemCount, name: 'index');
    IndexError.check(destIndex, itemCount, name: 'destIndex');
    checkReorderable(index, name: 'index');
    checkReorderable(destIndex, name: 'destIndex');
    if (index == destIndex) return;

    final itemAtIndex = _items.ensureItemAt(index: index);
    final itemAtDestIndex = _items.ensureItemAt(index: destIndex);

    final permutations = _items.moveItem(
      index: index,
      destIndex: destIndex,
      reorderableGetter: isReorderable,
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
      _items.itemCount ??
      (throw StateError(
        'Items can be inserted, removed and reordered only in a '
        '${widgets.ListView} or ${widgets.GridView} with an item count',
      ));

  void checkReorderable(int index, {required String name}) {
    if (!isReorderable(index)) {
      throw ArgumentError.value(index, name, 'is not reorderable');
    }
  }

  void dispose() {
    scrollSync.dispose();
    _items.dispose();
  }

  /// What the items layer builds from changes with these.
  widgets.Listenable get itemsChanges => _items.itemsChanges;

  /// What the overlayed items layer builds from changes with these, and
  /// with the overlayed items themselves.
  widgets.Listenable get overlayChanges => _items.overlayChanges;

  /// The overlayed and outgoing items, from the bottom one up.
  Iterable<model.OverlayedItem> get overlayedItemsOrderedByZIndex =>
      _items.overlayedItemsByZIndex;

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
        items: _items,
        scrollSync: scrollSync,
        vsync: vsync,
        motionAnimationDuration: () => motion.duration,
        motionAnimationCurve: () => motion.curve,
        scrollDirection: () => scrollDirection,
        itemBuilder: () => itemWidgets.originalBuilder,
      );

  void detachOverlayedItemsLayer(OverlayedItemsLayerState layer) {
    if (_overlay?.overlay == layer) _overlay = null;
  }

  void handleOverlayedItemSizeChange(Size size, model.OverlayedItem item) =>
      _overlay?.didResizeItem(size, item);

  model.Item createItem(int index) => model.Item(
    key: keyGetter(index),
    builder: model.ItemBuilder.adaptIndexedWidgetBuilder(
      (context, index) => itemWidgets.originalBuilder(context, index),
    ),
  );

  void _shiftOverlayedItems(Offset delta) =>
      _overlay?.shiftOverlayedItems(delta);

  bool isItemRendered(int index) {
    return getRenderedItemAt(index) != null;
  }

  model.RenderedItem? getRenderedItemAt(int index) =>
      _items.renderedItems.where((x) => x.index == index).firstOrNull;

  @override
  bool isReorderable(int index) =>
      reorder.reorderableGetter?.call(index) ?? true;

  @override
  bool isDraggable(int index) => reorder.draggableGetter?.call(index) ?? true;

  @override
  SwipeDirection? swipeToRemoveDirectionAt(int index) {
    if (swipeToRemove.onSwipeToRemove == null) return null;
    final getter = swipeToRemove.directionGetter;
    if (getter == null) return SwipeDirection.across(scrollDirection);
    return switch (getter(index)) {
      final direction? => SwipeDirection.of(direction),
      null => null,
    };
  }

  @override
  void didInitItem(model.RenderedItem item) => _items.putRenderedItem(item);

  @override
  void didChangeItemIndex(model.RenderedItem item) => _items
    ..removeRenderedItem(item)
    ..putRenderedItem(item);

  @override
  void didDeactivateItem(model.RenderedItem item) =>
      _items.removeRenderedItem(item);

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
  void recognizeReorderDrag(model.RenderedItem item, PointerDownEvent event) {
    final overlayedItem = _overlay?.createOverlayedItem(
      item,
      recognizerFactory:
          reorder.gestureRecognizerFactory ??
          createReorderDragGestureRecognizer,
    );
    if (overlayedItem == null) return;
    _recognizeDrag(overlayedItem, event, item.context);
  }

  @override
  void recognizeSwipe(model.RenderedItem item, PointerDownEvent event) {
    final direction = item.swipeToRemoveDirection;
    if (direction == null) return;
    final overlayedItem = _overlay?.createOverlayedItem(
      item,
      recognizerFactory: direction.recognizerFactory,
    );
    if (overlayedItem == null) return;
    _recognizeSwipe(overlayedItem, event, item.context, direction: direction);
  }

  /// Lets an item that flies back to its slot be held again.
  void recognizeOverlayedItem(
    PointerDownEvent event,
    model.OverlayedItem item,
    widgets.BuildContext context,
  ) => switch (item.swipeToRemoveDirection) {
    final direction? => _recognizeSwipe(
      item,
      event,
      context,
      direction: direction,
    ),
    null => _recognizeDrag(item, event, context),
  };

  /// Starts a drag session for [item] if [event] starts a drag of it.
  void _recognizeDrag(
    model.OverlayedItem item,
    PointerDownEvent event,
    widgets.BuildContext context,
  ) {
    DragSession? session;
    item.recognizeDrag(
      event,
      context: context,
      onDragStart: (details, item) {
        final overlay = _overlay;
        if (overlay == null) return;
        item.recognizerFactory = createImmediateDragGestureRecognizer;
        session = _drag = DragSession(
          item: item,
          items: _items,
          overlay: overlay,
          scrollSync: scrollSync,
          options: () => reorder,
          reorderItem: reorderItem,
        )..start(details);
      },
      onDragUpdate: (details, _) => session?.update(details),
      onDragEnd: (details, _) {
        session?.end(details);
        if (_drag == session) _drag = null;
      },
    );
  }

  /// Starts a swipe session for [item] if [event] starts a swipe of it.
  void _recognizeSwipe(
    model.OverlayedItem item,
    PointerDownEvent event,
    widgets.BuildContext context, {
    required SwipeDirection direction,
  }) {
    SwipeSession? session;
    item.recognizeSwipe(
      event,
      context: context,
      swipeDirection: direction,
      onSwipeStart: (details, item) {
        final overlay = _overlay;
        if (overlay == null) return;
        session = SwipeSession(
          item: item,
          items: _items,
          overlay: overlay,
          options: () => swipeToRemove,
        )..start(details);
      },
      onSwipeUpdate: (details, _) => session?.update(details),
      onSwipeEnd: (details, _) => session?.end(details),
    );
  }
}
