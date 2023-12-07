part of model;

class ControllerState {
  final _itemById = <int, Item>{};
  final _itemIdByIndex = SplayTreeMap<int, int>();
  final _activeItemById = <int, ActiveItem>{};
  final _renderedItemById = <int, RenderedItem>{};
  ActiveItem? draggedItem;
  ActiveItem? swipedItem;
  int? itemUnderThePointerId;
  int? itemCount;
  BoxConstraints? constraintsMark;
  Offset scrollOffsetMark = Offset.zero;
  bool shiftItemsOnScroll = true;

  Iterable<Item> get items => _itemById.values;
  Iterable<ActiveItem> get activeItems => _activeItemById.values;
  int get activeItemsNumber => _activeItemById.length;
  Iterable<RenderedItem> get renderedItems => _renderedItemById.values;
  bool isDragged({required int id}) => id == draggedItem?.id;
  bool isSwiped({required int id}) => id == swipedItem?.id;
  Iterable<(int, Item)> iterator() => _itemIdByIndex.entries.map(
        (e) => (e.key, itemBy(id: e.value)!),
      );

  Item? itemAt({required int index}) => itemBy(id: _itemIdByIndex[index] ?? -1);

  Item? itemBy({required int id}) => _itemById[id];

  Item putItem(Item x) => _itemById[x.id] = x;

  void putRenderedItem(RenderedItem x) => _renderedItemById[x.id] = x;

  RenderedItem? renderedItemBy({required int id}) => _renderedItemById[id];

  RenderedItem? removeRenderedItemBy({required int id}) =>
      _renderedItemById.remove(id);

  bool isRendered({required int id}) => _renderedItemById.containsKey(id);

  void setIndex({required int itemId, required int index}) =>
      _itemIdByIndex[index] = itemId;

  bool isActive({required int id}) => _activeItemById.containsKey(id);

  bool isActiveAt({required int index}) =>
      _activeItemById.containsKey(_itemIdByIndex[index] ?? -1);

  ActiveItem? activeItemBy({required int id}) => _activeItemById[id];

  void putActiveItem(ActiveItem x) {
    _activeItemById.remove(x.id);
    _activeItemById[x.id] = x;
  }

  ActiveItem? removeActiveItem({required int id}) => _activeItemById.remove(id);

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

    for (var activeItem in activeItems) {
      if (activeItem.index >= index) {
        activeItem.index++;
      }
    }

    final item = itemFactory.call(index);

    _itemById[item.id] = item;
    _itemIdByIndex[index] = item.id;

    itemCount = itemCount! + 1;

    return item;
  }

  Item? removeItem({required int index}) {
    final id = _itemIdByIndex.remove(index);

    itemCount = itemCount! - 1;

    int? lastIndex;
    for (var i in _itemIdByIndex.keys.toList()) {
      if (i > index) {
        _itemIdByIndex[i - 1] = _itemIdByIndex[i]!;
        lastIndex = i;
      }
    }
    _itemIdByIndex.remove(lastIndex);

    for (var activeItem in activeItems) {
      if (activeItem.index > index) {
        activeItem.index--;
      }
    }

    return _itemById.remove(id);
  }

  Permutations moveItem({
    required int index,
    required int destIndex,
    required bool Function(int index) reorderableGetter,
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

    for (var activeItem in activeItems) {
      activeItem.index =
          permutations.indexOf(activeItem.id) ?? activeItem.index;
    }

    return permutations;
  }

  List<ItemPositionUpdate> recomputeItemPositions({
    required Rect canvasGeometry,
    required AxisDirection axisDirection,
  }) =>
      switch (axisDirection) {
        AxisDirection.down =>
          _recomputePositionsIfAxisDirectionDown(canvasGeometry),
        AxisDirection.up =>
          _recomputePositionsIfAxisDirectionUp(canvasGeometry),
        AxisDirection.right =>
          _recomputePositionsIfAxisDirectionRight(canvasGeometry),
        AxisDirection.left =>
          _recomputePositionsIfAxisDirectionLeft(canvasGeometry),
      };

  void reset() {
    _itemById.clear();
    _activeItemById.clear();
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
    for (var x in activeItems) {
      x.dispose();
    }
  }
}

extension _ControllerState on ControllerState {
  List<ItemPositionUpdate> _recomputePositionsIfAxisDirectionDown(
    Rect canvasGeometry,
  ) {
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
        item.setPosition(anchorPosition);
      }

      maxRowHeight = math.max(maxRowHeight, item.height);
      cursor += Offset(item.width, 0);
    }
    return updates;
  }

  List<ItemPositionUpdate> _recomputePositionsIfAxisDirectionUp(
    Rect canvasGeometry,
  ) {
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
        item.setPosition(anchorPosition);
      }

      maxRowHeight = math.max(maxRowHeight, item.height);
      cursor += Offset(item.width, 0);
    }
    return updates;
  }

  List<ItemPositionUpdate> _recomputePositionsIfAxisDirectionRight(
    Rect canvasGeometry,
  ) {
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
        item.setPosition(anchorPosition);
      }

      maxColWidth = math.max(maxColWidth, item.width);
      cursor += Offset(0, item.height);
    }
    return updates;
  }

  List<ItemPositionUpdate> _recomputePositionsIfAxisDirectionLeft(
    Rect canvasGeometry,
  ) {
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
        item.setPosition(anchorPosition);
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
