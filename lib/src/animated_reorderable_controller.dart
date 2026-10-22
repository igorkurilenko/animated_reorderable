import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' as widgets;

import '../animated_reorderable.dart';
import 'const.dart';
import 'controller/board_scroll.dart';
import 'controller/held_item_sessions.dart';
import 'controller/item_widget_factory.dart';
import 'controller/overlay_coordinator.dart';
import 'controller/reorderable_group.dart';
import 'controller/scroll_sync.dart';
import 'model/model.dart' as model;
import 'model/swipe_direction.dart';
import 'util/gesture_recognizers.dart';
import 'util/scheduling.dart';
import 'widget/item_widget.dart';
import 'widget/item_flight_shuttle.dart' show LookBoundary;
import 'widget/items_layer.dart';
import 'widget/overlayed_items_layer.dart';

class AnimatedReorderableController implements ItemHost {
  AnimatedReorderableController({
    required this.keyGetter,
    required this.motion,
    required this.reorder,
    required this.swipeToRemove,
    required this.insertTransition,
    required this.scrollDirection,
    required this.isGrid,
    required this.clipBehavior,
    int? itemCount,
    required this.vsync,
  }) {
    _items = model.ItemRegistry(itemCount: itemCount, itemFactory: createItem)
      ..overlayChanges.addListener(_focusLandedItem);
    SemanticsBinding.instance.addSemanticsEnabledListener(
      _didChangeSemanticsEnabled,
    );
  }

  /// The items gain or lose their moves as a screen reader comes or goes:
  /// after the frame, as it can come while the app builds, when the items
  /// can't build again.
  void _didChangeSemanticsEnabled() {
    addPostFrame(() {
      if (!_disposed) _items.itemsChanges.notify();
    });
  }

  // The current configuration. The state replaces it on every rebuild,
  // and the controller and its collaborators read it when they need it,
  // so they use the latest builders and callbacks.
  KeyGetter keyGetter;
  MotionOptions motion;

  @override
  Duration get motionDuration => motion.duration;

  @override
  widgets.Curve get motionCurve => motion.curve;

  /// Whether the items changed since the frame began. The frame lays them
  /// out anew.
  var _changing = false;

  double _scrollAdjustment = 0.0;

  @override
  double get scrollAdjustment => _scrollAdjustment;

  void _didChangeItems() {
    if (_changing) return;
    _changing = true;
    addPostFrame(() => _changing = false);
  }

  /// Called during layout with how far, in pixels, the view's scroll offset
  /// moves as the content changes its dimensions, like a list that shrank
  /// under its offset. After a change of the items, they go on from where
  /// they showed, rather than jump with the content. Otherwise, as on a
  /// resize, they move with the content, as any view's do.
  void didAdjustScrollOffset(double pixels) {
    if (!_changing) return;
    if (_scrollAdjustment == 0.0) addPostFrame(() => _scrollAdjustment = 0.0);
    _scrollAdjustment += pixels;
    for (final item in _items.renderedItems) {
      item.willShift();
    }
  }

  @override
  ViewEdge? takeEntry(widgets.Key key) => _overlay?.takeEntry(key);

  @override
  int? semanticIndexOf(widgets.Widget child, int index) =>
      itemWidgets.semanticIndexOf(child, index);
  ReorderOptions reorder;
  SwipeToRemoveOptions swipeToRemove;
  model.AnimatedItemDecorator? insertTransition;
  Axis scrollDirection;
  @override
  bool isGrid;

  /// How the list clips its items at its edges, as its view does.
  Clip clipBehavior;
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

  /// The view around the list that scrolls across it, such as a board of
  /// lists that scrolls sideways.
  late final boardScroll = BoardScroll(
    velocityScalar: () => reorder.autoScrollerVelocityScalar,
    // The board moves the list's slots, so the list's items that fly back
    // to them in their group's layer head for where the slots are now. A
    // layer that moves with the board takes them along already.
    onScroll: () => _overlay?.reconcileOverlayedItems(
      (item, _) => item.sharedSpace != null,
    ),
    // The lists move under the item.
    onAutoScroll: () => _drag?.followPointer(),
  );
  late final itemWidgets = ItemWidgetFactory(items: _items, host: this);
  late final model.ItemRegistry _items;
  ItemsLayerState? _itemsLayer;
  OverlayCoordinator? _overlay;

  model.ItemRegistry get registry => _items;
  OverlayCoordinator? get overlayCoordinator => _overlay;

  /// Takes over [session], whose item came in from another list of the
  /// group: the list's auto-scrollers keep it going from now on.
  void takeOverDrag(DragSession session) => _drag = session;

  /// Lets go of [session], which ends.
  void didEndDrag(DragSession session) {
    if (_drag == session) _drag = null;
    boardScroll.stopAutoScroll();
  }

  /// Scrolls the board while [draggedItem], a rectangle on the screen, is
  /// at one of its edges, so the item gets to the group's lists out of
  /// sight.
  void autoScrollBoard(Rect draggedItem) {
    if (groupForDrags == null) return;
    boardScroll.autoScroll(draggedItem);
  }

  ReorderableGroup? _group;

  /// The group above the list, if any.
  set group(ReorderableGroup? value) {
    if (identical(_group, value)) return;
    _group?.leave(this);
    _group = value?..join(this);
  }

  /// Whether items can be dragged to and from the other lists of its group.
  bool get takesGroupItems =>
      _group != null && reorder.groupId != null && reorder.onReorder != null;

  /// The group the list's items are dragged in, if they are.
  ReorderableGroup? get groupForDrags => takesGroupItems ? _group : null;

  /// The id of the list in its group.
  Object? get groupId => reorder.groupId;

  /// Where the list is on the screen: its overlay covers it.
  Rect? get globalRect {
    final overlay = _overlay?.overlay;
    if (overlay == null) return null;
    return overlay.localToGlobal(const model.OverlayOffset(Offset.zero)) &
        overlay.size;
  }

  /// The index an item dragged in from another list goes to at [point]:
  /// that of the item there, or after it if it can't be reordered, or else
  /// that of the first item past [point] along the list, or the end.
  int dropIndexAt(model.GlobalOffset point) {
    final under = _items.renderedItemAt(position: point);
    if (under != null) {
      return isReorderable(under.index) ? under.index : under.index + 1;
    }
    final axisDirection =
        scrollSync.scrollPosition?.axisDirection ??
        switch (scrollDirection) {
          Axis.vertical => AxisDirection.down,
          Axis.horizontal => AxisDirection.right,
        };
    bool isPast(Rect slot) => switch (axisDirection) {
      AxisDirection.down => slot.top > point.dy,
      AxisDirection.up => slot.bottom < point.dy,
      AxisDirection.right => slot.left > point.dx,
      AxisDirection.left => slot.right < point.dx,
    };
    final past = [
      for (final item in _items.renderedItems)
        if ((item.globalPosition, item.size) case (final position?, final size?)
            when isPast(position & size))
          item.index,
    ];
    return past.isEmpty ? checkedItemCount : past.reduce(math.min);
  }

  /// Gives up the held [item] to another list of the group. The items
  /// after it move up into its place.
  void releaseHeldItem(model.OverlayedItem item) {
    if (_drag?.item == item) _drag = null;
    scrollSync.stopAutoScroll();
    boardScroll.stopAutoScroll();
    _items.releaseHeldItem(item);
    _didChangeItems();
    _overlay?.moveRenderedItems(except: item.key);
  }

  /// Takes in the held [item] from another list of the group at [index].
  /// The items from there on move down to make room for it. A drag goes on
  /// holding it if it is [held], as a screen reader's move doesn't: the
  /// list lands it on its slot once it lays the slot out.
  void adoptHeldItem(
    model.OverlayedItem item, {
    required int index,
    bool held = true,
  }) {
    if (!held) _focusOnLanding = item.key;
    // It flies from the look it leaves, as it last showed: the other list
    // builds another item at its index by now.
    final fly = _takeOff(item);
    // The other list's builder would build what it has at the index now.
    item.item.builder = _itemBuilder();
    _fitToSlots(item);
    _items.adoptHeldItem(item, index: index, held: held);
    _didChangeItems();
    _overlay?.moveRenderedItems(except: item.key);
    fly?.call();
  }

  /// Takes the look [item] leaves, as it last showed, and the point of it
  /// the pointer holds, or its middle without a pointer, as on a screen
  /// reader's move, if the group flies items and the item has shown. A
  /// flight under way turns from what its shuttle shows. Returns what flies
  /// the item from there to the look its builder builds.
  void Function()? _takeOff(model.OverlayedItem item) {
    final flight = _group?.flightOptions;
    final grip = item.grip ?? const Offset(0.5, 0.5);
    if (flight == null || flight.duration <= Duration.zero) return null;
    if (LookBoundary.takeLook(item.lookKey) case (final look, final size)) {
      return () => item.fly(
        from: look,
        fromSize: size,
        grip: grip,
        vsync: vsync,
        duration: flight.duration,
        curve: flight.curve,
      );
    }
    return null;
  }

  /// Gives [item] the size of the list's slots at once, under the pointer:
  /// a list's items share their constraints, and so do a grid's.
  void _fitToSlots(model.OverlayedItem item) {
    final slot =
        _items.renderedItems.firstOrNull?.constraints ?? _slotOfEmptyList();
    if (slot == null) return;
    item.setConstraints(slot);
    final size = slot.constrain(item.size);
    _overlay?.keepUnderPointer(item, size: size);
    _items.setOverlayedItemSize(item, size);
  }

  /// The constraints of a slot of the list, which has none to show yet:
  /// as wide as the list, or as high for one that scrolls sideways. They
  /// hold until the list lays the item's placeholder out.
  BoxConstraints? _slotOfEmptyList() => switch (globalRect?.size) {
    final size? when scrollSync.gridLayout != null => BoxConstraints.loose(
      size,
    ),
    final size? => switch (scrollDirection) {
      Axis.vertical => BoxConstraints.tightFor(width: size.width),
      Axis.horizontal => BoxConstraints.tightFor(height: size.height),
    },
    null => null,
  };

  /// The latest drag, which the auto-scroller keeps going.
  DragSession? _drag;

  /// Whether the items layer was built since the last reconcile pass.
  bool _itemsLayerBuilt = false;

  /// The items built since the last reconcile pass, in the order they were
  /// built.
  final _builtItems = <model.RenderedItem>{};
  bool _reconcileScheduled = false;

  void insertItem(int index, Duration duration) {
    RangeError.checkValueInInterval(index, 0, checkedItemCount, 'index');

    // An item swiped away that is still going with the key of the one that
    // comes goes at once, so the two don't show the app's subtree, and its
    // global keys, twice.
    _items.removeSwipedAwayItems(key: keyGetter(index));
    final insertedItem = _items.insertItem(index: index)
      ..enter(vsync: vsync, duration: duration);

    _didChangeItems();
    _overlay?.moveRenderedItems(except: insertedItem.key);
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
    _didChangeItems();

    final overlay = _overlay;
    if (overlay == null) {
      _items.releaseRemovedItem(removedItem);
      return;
    }

    overlay
      ..moveRenderedItems(except: removedItem.key)
      ..animateOut(
        removedItem,
        renderedItem: _items.renderedItemBy(key: removedItem.key),
        builder: builder,
        duration: duration,
        zIndex: zIndex ?? _outgoingZIndexOf(removedItem.key),
      );
  }

  /// Where the removed item with [key] shows as it goes: under the items
  /// that move into its place, unless the overlay shows it above them
  /// already, as it shows an item swiped away, which flies out over its
  /// neighbors.
  int _outgoingZIndexOf(widgets.Key key) =>
      _items.overlayedItemBy(key: key)?.zIndex ?? outgoingItemZIndex;

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

    final moves = _items.moveItem(
      index: index,
      destIndex: destIndex,
      reorderableGetter: isReorderable,
    );
    _didChangeItems();

    _overlay
      ?..moveRenderedItems()
      ..enterNotRenderedItem(itemAtIndex, index: index)
      ..enterNotRenderedItem(itemAtDestIndex, index: destIndex);

    onReorder(moves);
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

  var _disposed = false;

  void dispose() {
    _disposed = true;
    SemanticsBinding.instance.removeSemanticsEnabledListener(
      _didChangeSemanticsEnabled,
    );
    boardScroll.dispose();
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
      );

  void detachOverlayedItemsLayer(OverlayedItemsLayerState layer) {
    if (_overlay?.overlay == layer) _overlay = null;
  }

  void handleOverlayedItemSizeChange(Size size, model.OverlayedItem item) =>
      _overlay?.didResizeItem(size, item);

  /// Called as [item] lays out at [size], before the frame paints it.
  void handleOverlayedItemLayout(Size size, model.OverlayedItem item) =>
      _overlay?.didLayOutItem(size, item);

  model.Item createItem(int index) =>
      model.Item(key: keyGetter(index), builder: _itemBuilder());

  /// Builds an item as the wrapped view builds its children.
  model.ItemBuilder _itemBuilder() =>
      model.ItemBuilder.adaptIndexedWidgetBuilder(
        (context, index) => itemWidgets.originalBuilder(context, index),
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

  /// Without a screen reader, items have no moves, so an item that keeps
  /// its index doesn't build again as the moves of its place change, as the
  /// last item's do when an item after it goes.
  @override
  SemanticMoves semanticMovesAt(int index) =>
      SemanticsBinding.instance.semanticsEnabled
      ? _semanticMovesAt(index)
      : _noSemanticMoves;

  static const SemanticMoves _noSemanticMoves = (
    back: false,
    forward: false,
    rowBack: false,
    rowForward: false,
    toLists: ListMoves.none,
  );

  SemanticMoves _semanticMovesAt(int index) => (
    back: _semanticDestination(index, SemanticMove.back) != null,
    forward: _semanticDestination(index, SemanticMove.forward) != null,
    rowBack: _semanticDestination(index, SemanticMove.rowBack) != null,
    rowForward: _semanticDestination(index, SemanticMove.rowForward) != null,
    toLists: _listMovesAt(index),
  );

  @override
  void moveToList(int index, Object list) {
    final group = groupForDrags;
    final to = group?.memberWith(list);
    if (group == null || to == null) return;
    if (!_listMovesAt(index).moves.any((x) => x.list == list)) return;
    group.moveItem(from: this, index: index, to: to);
  }

  /// The moves a screen reader can make with the item at [index] to the
  /// other lists of the group that take it, in the group's order, if the
  /// group names them. The item goes to the same index there.
  ListMoves _listMovesAt(int index) {
    final group = groupForDrags;
    final label = group?.options().moveToListLabel;
    final itemCount = _items.itemCount;
    if (group == null ||
        label == null ||
        itemCount == null ||
        index >= itemCount ||
        !isDraggable(index) ||
        !isReorderable(index)) {
      return ListMoves.none;
    }
    final from = (list: groupId!, index: index);
    return ListMoves(
      [
        for (final to in group.members)
          if (to != this &&
              to.takesGroupItems &&
              group.canMove(from, (
                list: to.groupId!,
                index: group.moveIndexIn(to, index),
              )))
            (list: to.groupId!, label: label(to.groupId!)),
      ],
      // Of the lists that take the group's items: a list without an id,
      // like one that reorders the board's columns, is no place to go.
      labels: [
        for (final list in group.members)
          if (list.takesGroupItems) label(list.groupId!),
      ],
    );
  }

  /// Lifts the item at [index] into the group's layer for a screen
  /// reader's move to another list. It shows where it shows now,
  /// undecorated, with no pointer to follow, and the move holds it until
  /// it goes, so the list doesn't land it on its slot meanwhile. Null if
  /// the list doesn't show it.
  model.OverlayedItem? liftForMove(int index) {
    final overlay = _overlay;
    final group = groupForDrags;
    final rendered = getRenderedItemAt(index);
    if (overlay == null || group == null || rendered == null) return null;
    final item =
        _items.overlayedItemBy(key: rendered.key) ??
        overlay.createOverlayedItem(rendered);
    item.stopMotion();
    group.host(item, this);
    overlay.lift(
      item,
      decorator: null,
      decorationDuration: Duration.zero,
      sharedSpace: group,
    );
    _items.draggedItem = item;
    return item;
  }

  /// The item a screen reader moved here from another list, or tried to,
  /// which takes the screen reader's focus once it lands on its slot. The
  /// move lifted it, which took away the node of its moves that had the
  /// focus, and the list builds it again only as it shows the item itself.
  Key? _focusOnLanding;

  void _focusLandedItem() {
    final key = _focusOnLanding;
    if (key == null || _items.isOverlayed(key: key)) return;
    _focusOnLanding = null;
    // Once the frame that builds it has sent its node to the platform.
    addPostFrame(() {
      if (!_disposed) _items.renderedItemBy(key: key)?.focusSemanticMoves();
    });
  }

  /// Takes [item], lifted for a move that didn't happen, back into the
  /// list, with the screen reader's focus, which the lift took away.
  void dropMovedItem(model.OverlayedItem item) {
    if (_items.draggedItem == item) _items.draggedItem = null;
    _focusOnLanding = item.key;
    _overlay?.unoverlay(item);
  }

  @override
  void makeSemanticMove(int index, SemanticMove move) {
    if (_semanticDestination(index, move) case final destIndex?) {
      reorderItem(index, destIndex: destIndex);
    }
  }

  /// The index [move] takes the item at [index] to, or null if the item
  /// can't make it. Only an item that can be dragged and reordered moves,
  /// and it moves past items that can't be reordered: one place or row
  /// back or forward takes it to the nearest index it can take that way,
  /// and a move to the start or the end to the farthest.
  int? _semanticDestination(int index, SemanticMove move) {
    final itemCount = _items.itemCount;
    if (reorder.onReorder == null ||
        itemCount == null ||
        index >= itemCount ||
        !isDraggable(index) ||
        !isReorderable(index)) {
      return null;
    }
    final row = _rowLength;
    if (row == null &&
        (move == SemanticMove.rowBack || move == SemanticMove.rowForward)) {
      return null;
    }
    // The indexes it can go to, from the first one to try.
    final (from, to) = switch (move) {
      SemanticMove.toStart => (0, index - 1),
      SemanticMove.back => (index - 1, 0),
      SemanticMove.forward => (index + 1, itemCount - 1),
      SemanticMove.toEnd => (itemCount - 1, index + 1),
      SemanticMove.rowBack => (index - row!, 0),
      SemanticMove.rowForward => (index + row!, itemCount - 1),
    };
    if (from < 0 || to < 0 || from >= itemCount || to >= itemCount) {
      return null;
    }
    final step = from <= to ? 1 : -1;
    for (var i = from; i != to + step; i += step) {
      if (isReorderable(i)) return i;
    }
    return null;
  }

  /// How many items each row of the grid holds, if it holds more than
  /// one, as a regular grid's rows do. Screen readers move items a row back
  /// or forward then.
  int? get _rowLength => switch (scrollSync.gridLayout) {
    final SliverGridRegularTileLayout layout when layout.crossAxisCount > 1 =>
      layout.crossAxisCount,
    _ => null,
  };

  /// Takes the grid's [layout], which its items build with. The grid lays
  /// itself out before it builds them, but one it already has builds again
  /// once its rows hold another number of items, for its row moves.
  void didLayOutGrid(SliverGridLayout layout, SliverConstraints constraints) {
    final laidOut = scrollSync.gridLayout != null;
    final rowLength = _rowLength;
    scrollSync.didLayOutGrid(layout, constraints);
    if (laidOut && _rowLength != rowLength) {
      addPostFrame(() {
        if (!_disposed) _items.itemsChanges.notify();
      });
    }
  }

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
  widgets.Widget buildEntrance(
    widgets.Widget child,
    int index,
    widgets.Animation<double> entrance,
  ) => insertTransition?.call(child, index, entrance) ?? child;

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
    // A build moves the slots of items it doesn't build, like those after
    // a held item whose placeholder resized: the overlayed items head for
    // where their slots are now.
    overlay.reconcileOverlayedItems((_, slot) => !builtItems.contains(slot));
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
        session = _drag = DragSession(item: item, host: this)..start(details);
      },
      onDragUpdate: (details, _) => session?.update(details),
      onDragEnd: (details, _) => session?.end(details),
      onDragCancel: (details, _) => session?.cancel(details),
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
      onSwipeCancel: (details, _) => session?.cancel(details),
    );
  }
}
