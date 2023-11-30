part of model;

class ControllerState {
  final _itemById = <int, Item>{};
  final _overlayedItemById = <int, OverlayedItem>{};
  final _outgoingItemById = <int, OutgoingItem>{};
  final _itemIdByIndex = SplayTreeMap<int, int>();
  final _renderedItemById = <int, RenderedItem>{};
  OverlayedItem? draggedItem;
  OverlayedItem? swipedItem;
  int? itemUnderThePointerId;
  int? itemCount;
  BoxConstraints? constraintsMark;
  Offset scrollOffsetMark = Offset.zero;
  bool shiftItemsOnScroll = true;

  Iterable<Item> get items => _itemById.values;
  Iterable<OutgoingItem> get outgoingItems => _outgoingItemById.values;
  Iterable<OverlayedItem> get overlayedItems => _overlayedItemById.values;
  int get overlayedItemsNumber => _overlayedItemById.length;
  Iterable<RenderedItem> get renderedItems => _renderedItemById.values;
  bool isDragged({required int id}) => id == draggedItem?.id;
  bool isSwiped({required int id}) => id == swipedItem?.id;

  Item? itemAt({required int index}) => itemBy(id: _itemIdByIndex[index] ?? -1);

  Item? itemBy({required int id}) => _itemById[id];

  Item putItem(Item x) => _itemById[x.id] = x;

  RenderedItem putRenderedItem(RenderedItem x) => _renderedItemById[x.id] = x;

  RenderedItem? renderedItemBy({required int id}) => _renderedItemById[id];

  RenderedItem? removeRenderedItemBy({required int id}) =>
      _renderedItemById.remove(id);

  bool isRendered({required int id}) => _renderedItemById.containsKey(id);

  void setIndex({required int itemId, required int index}) =>
      _itemIdByIndex[index] = itemId;

  bool isOverlayed({required int id}) => _overlayedItemById.containsKey(id);

  bool isOverlayedAt({required int index}) =>
      _overlayedItemById.containsKey(_itemIdByIndex[index] ?? -1);

  OverlayedItem? overlayedItemBy({required int id}) => _overlayedItemById[id];

  OverlayedItem putOverlayedItem(OverlayedItem x) {
    _overlayedItemById.remove(x.id);
    return _overlayedItemById[x.id] = x;
  }

  OverlayedItem? removeOverlayedItem({required int id}) =>
      _overlayedItemById.remove(id);

  OutgoingItem? outgoingItemBy({required int id}) => _outgoingItemById[id];

  RenderedItem? renderedItemAt({required Offset position}) =>
      renderedItems.where((x) => x.contains(position)).firstOrNull;

  Item insertItem({
    required int index,
    required Item Function(int index) itemFactory,
  }) {
    for (var i in _itemIdByIndex.keys.toList().reversed) {
      if (i < index) break;
      _itemIdByIndex[i + 1] = _itemIdByIndex[i]!;
    }

    for (var overlayedItem in overlayedItems) {
      if (overlayedItem.index >= index) {
        overlayedItem.index++;
      }
    }

    final item = itemFactory.call(index);

    _itemById[item.id] = item;
    _itemIdByIndex[index] = item.id;

    itemCount = itemCount! + 1;

    return item;
  }

  Permutations moveItem({
    required int index,
    required int destIndex,
    required ReorderableGetter reorderableGetter,
    required Item Function(int index) itemFactory,
  }) {
    final permutations = Permutations();
    if (index == destIndex) return permutations;

    increment(int i) => i + 1;
    decrement(int i) => i - 1;
    final nextIndex = index > destIndex ? increment : decrement;
    var curItem = itemAt(index: index) ?? putItem(itemFactory(index));
    int unorderedItemId = curItem.id;
    int unorderedItemIndex = index;

    for (var curIndex = destIndex;; curIndex = nextIndex(curIndex)) {
      curItem = itemAt(index: curIndex) ?? putItem(itemFactory(curIndex));

      if (reorderableGetter(curIndex)) {
        _itemIdByIndex[curIndex] = unorderedItemId;

        permutations.addPermutation(
          elementId: unorderedItemId,
          from: unorderedItemIndex,
          to: curIndex,
        );

        unorderedItemId = curItem.id;
        unorderedItemIndex = curIndex;
      }

      if (curIndex == index) break;
    }

    for (var overlayedItem in overlayedItems) {
      overlayedItem.index =
          permutations.indexOf(overlayedItem.id) ?? overlayedItem.index;
    }

    return permutations;
  }

  List<ItemPositionUpdate> recomputeItemPositions({
    required Rect canvasGeometry,
    required AxisDirection axisDirection,
    bool notifyItemListeners = true,
  }) =>
      switch (axisDirection) {
        AxisDirection.down => _recomputePositionsIfAxisDirectionDown(
            canvasGeometry: canvasGeometry,
            notifyItemListeners: notifyItemListeners,
          ),
        AxisDirection.up => _recomputePositionsIfAxisDirectionUp(
            canvasGeometry: canvasGeometry,
            notifyItemListeners: notifyItemListeners,
          ),
        AxisDirection.right => _recomputePositionsIfAxisDirectionRight(
            canvasGeometry: canvasGeometry,
            notifyItemListeners: notifyItemListeners,
          ),
        AxisDirection.left => _recomputePositionsIfAxisDirectionLeft(
            canvasGeometry: canvasGeometry,
            notifyItemListeners: notifyItemListeners,
          ),
      };

  void reset() {
    _itemById.clear();
    _overlayedItemById.clear();
    _outgoingItemById.clear();
    _itemIdByIndex.clear();
    _renderedItemById.clear();
    draggedItem = null;
    swipedItem = null;
    itemUnderThePointerId = null;
    itemCount = null;
    constraintsMark = null;
    scrollOffsetMark = Offset.zero;
    shiftItemsOnScroll = true;
  }

  void dispose() {
    for (var x in items) {
      x.dispose();
    }
    for (var x in overlayedItems) {
      x.dispose();
    }
    for (var x in outgoingItems) {
      x.dispose();
    }
  }
}

extension _ControllerState on ControllerState {
  List<ItemPositionUpdate> _recomputePositionsIfAxisDirectionDown({
    required Rect canvasGeometry,
    bool notifyItemListeners = true,
  }) {
    final updates = <ItemPositionUpdate>[];
    var cursor = canvasGeometry.topLeft;
    final minLeft = canvasGeometry.left;
    final maxRight = canvasGeometry.right;
    var maxRowHeight = 0.0;

    for (var (idx, id) in _itemIdByIndex.entries.map((e) => (e.key, e.value))) {
      final item = itemBy(id: id)!;
      final testGeometry = cursor & item.size;

      if (testGeometry.deflate(alpha).right > maxRight) {
        cursor += Offset(-(cursor.dx - minLeft), maxRowHeight);
        maxRowHeight = item.height;
      }

      final anchorPosition = cursor;

      if ((item.position - anchorPosition).distance > alpha) {
        updates.add(ItemPositionUpdate(
          item: item,
          index: idx,
          oldPosition: item.position,
          newPosition: anchorPosition,
        ));
        item.setPosition(anchorPosition, notify: notifyItemListeners);
      }

      maxRowHeight = math.max(maxRowHeight, item.height);
      cursor += Offset(item.width, 0);
    }
    return updates;
  }

  List<ItemPositionUpdate> _recomputePositionsIfAxisDirectionUp({
    required Rect canvasGeometry,
    bool notifyItemListeners = true,
  }) {
    final updates = <ItemPositionUpdate>[];
    var cursor = canvasGeometry.bottomLeft;
    final minLeft = canvasGeometry.left;
    final maxRight = canvasGeometry.right;
    var maxRowHeight = 0.0;

    for (var (idx, id) in _itemIdByIndex.entries.map((e) => (e.key, e.value))) {
      final item = itemBy(id: id)!;
      final testGeometry = cursor & item.size;

      if (testGeometry.deflate(alpha).right > maxRight) {
        cursor += Offset(-(cursor.dx - minLeft), -maxRowHeight);
        maxRowHeight = item.height;
      }

      final anchorPosition = cursor - Offset(0, item.height);

      if ((item.position - anchorPosition).distance > alpha) {
        updates.add(ItemPositionUpdate(
          item: item,
          index: idx,
          oldPosition: item.position,
          newPosition: anchorPosition,
        ));
        item.setPosition(anchorPosition, notify: notifyItemListeners);
      }

      maxRowHeight = math.max(maxRowHeight, item.height);
      cursor += Offset(item.width, 0);
    }
    return updates;
  }

  List<ItemPositionUpdate> _recomputePositionsIfAxisDirectionRight({
    required Rect canvasGeometry,
    bool notifyItemListeners = true,
  }) {
    final updates = <ItemPositionUpdate>[];
    var cursor = canvasGeometry.topLeft;
    final minTop = canvasGeometry.top;
    final maxBottom = canvasGeometry.bottom;
    var maxColWidth = 0.0;

    for (var (idx, id) in _itemIdByIndex.entries.map((e) => (e.key, e.value))) {
      final item = itemBy(id: id)!;
      final testGeometry = cursor & item.size;

      if (testGeometry.deflate(alpha).bottom > maxBottom) {
        cursor += Offset(maxColWidth, -(cursor.dy - minTop));
        maxColWidth = item.width;
      }

      final anchorPosition = cursor;

      if ((item.position - anchorPosition).distance > alpha) {
        updates.add(ItemPositionUpdate(
          item: item,
          index: idx,
          oldPosition: item.position,
          newPosition: anchorPosition,
        ));
        item.setPosition(anchorPosition, notify: notifyItemListeners);
      }

      maxColWidth = math.max(maxColWidth, item.width);
      cursor += Offset(0, item.height);
    }
    return updates;
  }

  List<ItemPositionUpdate> _recomputePositionsIfAxisDirectionLeft({
    required Rect canvasGeometry,
    bool notifyItemListeners = true,
  }) {
    final updates = <ItemPositionUpdate>[];
    var cursor = canvasGeometry.topRight;
    final minTop = canvasGeometry.top;
    final maxBottom = canvasGeometry.bottom;
    var maxColWidth = 0.0;

    for (var (idx, id) in _itemIdByIndex.entries.map((e) => (e.key, e.value))) {
      final item = itemBy(id: id)!;
      final testGeometry = cursor & item.size;

      if (testGeometry.deflate(alpha).bottom > maxBottom) {
        cursor += Offset(-maxColWidth, -(cursor.dy - minTop));
        maxColWidth = item.width;
      }

      final anchorPosition = cursor + Offset(-item.width, 0);

      if ((item.position - anchorPosition).distance > alpha) {
        updates.add(ItemPositionUpdate(
          item: item,
          index: idx,
          oldPosition: item.position,
          newPosition: anchorPosition,
        ));
        item.setPosition(anchorPosition, notify: notifyItemListeners);
      }

      maxColWidth = math.max(maxColWidth, item.width);
      cursor += Offset(0, item.height);
    }
    return updates;
  }
}

class ItemPositionUpdate {
  final Item item;
  final int index;
  final Offset oldPosition;
  final Offset newPosition;

  ItemPositionUpdate({
    required this.item,
    required this.index,
    required this.oldPosition,
    required this.newPosition,
  });
}
