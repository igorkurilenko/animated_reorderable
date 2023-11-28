part of model;

class ControllerState {
  ControllerState(this._motionAnimationController);

  final _itemById = <int, Item>{};
  final _overlayedItemById = <int, OverlayedItem>{};
  final _outgoingItemById = <int, OutgoingItem>{};
  final _itemIdByIndex = SplayTreeMap<int, int>();
  final _renderedItemById = <int, RenderedItem>{};
  final _positionUpdateByItemId = <int, (Offset, Offset)>{};
  final AnimationController _motionAnimationController;
  OverlayedItem? draggedItem;
  OverlayedItem? swipedItem;
  int? itemUnderThePointerId;

  int? itemCount;

  Iterable<Item> get items => _itemById.values;
  Iterable<OutgoingItem> get outgoingItems => _outgoingItemById.values;
  Iterable<OverlayedItem> get overlayedItems => _overlayedItemById.values;
  int get overlayedItemsNumber => _overlayedItemById.length;
  Iterable<RenderedItem> get renderedItems => _renderedItemById.values;
  Animation get motionAnimation => _motionAnimationController.view;
  bool isDragged({required int itemId}) => itemId == draggedItem?.id;
  bool isNotDragged({required int itemId}) => !isDragged(itemId: itemId);
  bool isSwiped({required int itemId}) => itemId == swipedItem?.id;
  bool isNotSwiped({required int itemId}) => !isSwiped(itemId: itemId);

  Item? itemAt({required int index}) => itemBy(id: _itemIdByIndex[index] ?? -1);

  Item? itemBy({required int id}) => _itemById[id];

  Item putItem(Item x) => _itemById[x.id] = x;

  RenderedItem putRenderedItem(RenderedItem x) => _renderedItemById[x.id] = x;

  RenderedItem? renderedItemBy({required int id}) => _renderedItemById[id];

  RenderedItem? removeRenderedItemBy({required int id}) =>
      _renderedItemById.remove(id);

  bool isRendered({required int itemId}) =>
      _renderedItemById.containsKey(itemId);

  void setOrder({required int index, required int id}) =>
      _itemIdByIndex[index] = id;

  bool isOverlayed({required int itemId}) =>
      _overlayedItemById.containsKey(itemId);

  bool isOverlayedAt({required int index}) =>
      _overlayedItemById.containsKey(_itemIdByIndex[index] ?? -1);

  bool isNotOverlayed({required int itemId}) => !isOverlayed(itemId: itemId);

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

  void recomputeItemPositions({
    required Rect canvasGeometry,
    required AxisDirection axisDirection,
    bool notifyItemListeners = true,
  }) {
    _positionUpdateByItemId.clear();

    return switch (axisDirection) {
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
  }

  Future forwardMotionAnimation({double? from}) => _motionAnimationController
      .forward(from: from)
      .whenComplete(() => _positionUpdateByItemId.clear());

  void stopMotionAnimation() => _motionAnimationController.stop();

  bool hasPositionUpdate({required int itemId}) =>
      _positionUpdateByItemId.containsKey(itemId);

  (Offset, Offset)? positionUpdateBy({required int id}) =>
      _positionUpdateByItemId[id];

  void dispose() {
    _motionAnimationController.dispose();

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
  void _recomputePositionsIfAxisDirectionDown({
    required Rect canvasGeometry,
    bool notifyItemListeners = true,
  }) {
    var cursor = canvasGeometry.topLeft;
    final minLeft = canvasGeometry.left;
    final maxRight = canvasGeometry.right;
    var maxRowHeight = 0.0;

    for (var item in _itemIdByIndex.values.map((id) => itemBy(id: id)!)) {
      final testGeometry = cursor & item.size;

      if (testGeometry.deflate(alpha).right > maxRight) {
        cursor += Offset(-(cursor.dx - minLeft), maxRowHeight);
        maxRowHeight = item.height;
      }

      final anchorPosition = cursor;

      if ((item.position - anchorPosition).distance > alpha) {
        _positionUpdateByItemId[item.id] = (item.position, anchorPosition);
        item.setPosition(anchorPosition, notify: notifyItemListeners);
      }

      maxRowHeight = math.max(maxRowHeight, item.height);
      cursor += Offset(item.width, 0);
    }
  }

  void _recomputePositionsIfAxisDirectionUp({
    required Rect canvasGeometry,
    bool notifyItemListeners = true,
  }) {
    var cursor = canvasGeometry.bottomLeft;
    final minLeft = canvasGeometry.left;
    final maxRight = canvasGeometry.right;
    var maxRowHeight = 0.0;

    for (var item in _itemIdByIndex.values.map((id) => itemBy(id: id)!)) {
      final testGeometry = cursor & item.size;

      if (testGeometry.deflate(alpha).right > maxRight) {
        cursor += Offset(-(cursor.dx - minLeft), -maxRowHeight);
        maxRowHeight = item.height;
      }

      final anchorPosition = cursor - Offset(0, item.height);

      if ((item.position - anchorPosition).distance > alpha) {
        _positionUpdateByItemId[item.id] = (item.position, anchorPosition);
        item.setPosition(anchorPosition, notify: notifyItemListeners);
      }

      maxRowHeight = math.max(maxRowHeight, item.height);
      cursor += Offset(item.width, 0);
    }
  }

  void _recomputePositionsIfAxisDirectionRight({
    required Rect canvasGeometry,
    bool notifyItemListeners = true,
  }) {
    var cursor = canvasGeometry.topLeft;
    final minTop = canvasGeometry.top;
    final maxBottom = canvasGeometry.bottom;
    var maxColWidth = 0.0;

    for (var item in _itemIdByIndex.values.map((id) => itemBy(id: id)!)) {
      final testGeometry = cursor & item.size;

      if (testGeometry.deflate(alpha).bottom > maxBottom) {
        cursor += Offset(maxColWidth, -(cursor.dy - minTop));
        maxColWidth = item.width;
      }

      final anchorPosition = cursor;

      if ((item.position - anchorPosition).distance > alpha) {
        _positionUpdateByItemId[item.id] = (item.position, anchorPosition);
        item.setPosition(anchorPosition, notify: notifyItemListeners);
      }

      maxColWidth = math.max(maxColWidth, item.width);
      cursor += Offset(0, item.height);
    }
  }

  void _recomputePositionsIfAxisDirectionLeft({
    required Rect canvasGeometry,
    bool notifyItemListeners = true,
  }) {
    var cursor = canvasGeometry.topRight;
    final minTop = canvasGeometry.top;
    final maxBottom = canvasGeometry.bottom;
    var maxColWidth = 0.0;

    for (var item in _itemIdByIndex.values.map((id) => itemBy(id: id)!)) {
      final testGeometry = cursor & item.size;

      if (testGeometry.deflate(alpha).bottom > maxBottom) {
        cursor += Offset(-maxColWidth, -(cursor.dy - minTop));
        maxColWidth = item.width;
      }

      final anchorPosition = cursor + Offset(-item.width, 0);

      if ((item.position - anchorPosition).distance > alpha) {
        _positionUpdateByItemId[item.id] = (item.position, anchorPosition);
        item.setPosition(anchorPosition, notify: notifyItemListeners);
      }

      maxColWidth = math.max(maxColWidth, item.width);
      cursor += Offset(0, item.height);
    }
  }
}
