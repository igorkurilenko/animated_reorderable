part of model;

class ControllerState {
  final _idleItemById = <int, IdleItem>{};
  final _overlayedItemById = <int, OverlayedItem>{};
  final _outgoingItemById = <int, OutgoingItem>{};
  final _itemIdByIndex = SplayTreeMap<int, int>();
  final _renderedItemById = <int, RenderedItem>{};

  int? itemCount;

  Iterable<IdleItem> get idleItems => _idleItemById.values;

  Iterable<OutgoingItem> get outgoingItems => _outgoingItemById.values;

  Iterable<OverlayedItem> get overlayedItems => _overlayedItemById.values;

  Iterable<Item> get allItems => idleItems
      .cast()
      .followedBy(overlayedItems.cast())
      .followedBy(outgoingItems.cast())
      .cast();

  IdleItem? idleItemAt({required int index}) =>
      idleItemBy(id: _itemIdByIndex[index] ?? -1);

  IdleItem? idleItemBy({required int id}) => _idleItemById[id];

  IdleItem putIdleItem(IdleItem x) => _idleItemById[x.id] = x;

  RenderedItem putRenderedItem(RenderedItem x) => _renderedItemById[x.id] = x;

  RenderedItem? renderedItemBy({required int id}) => _renderedItemById[id];

  RenderedItem? removeRenderedItemBy({required int id}) =>
      _renderedItemById.remove(id);

  void setOrder({required int index, required int id}) =>
      _itemIdByIndex[index] = id;

  bool isOverlayed({required int itemId}) =>
      _overlayedItemById.containsKey(itemId);

  bool isNotOverlayed({required int itemId}) => !isOverlayed(itemId: itemId);

  OverlayedItem? overlayedItemBy({required int id}) => _overlayedItemById[id];

  OverlayedItem putOverlayedItem(OverlayedItem x) {
    _overlayedItemById.remove(x.id);
    return _overlayedItemById[x.id] = x;
  }

  OverlayedItem? removeOverlayedItem({required int id}) =>
      _overlayedItemById.remove(id);

  OutgoingItem? outgoingItemBy({required int id}) => _outgoingItemById[id];

  void shiftOverlayedItems(
    widgets.Offset delta, {
    bool Function(OverlayedItem item)? where,
  }) {
    for (var x in overlayedItems.where(where ?? returnTrue)) {
      x.shift(delta);
    }
  }

  void shiftOutgoingItems(
    widgets.Offset delta, {
    bool Function(OutgoingItem item)? where,
  }) {
    for (var x in outgoingItems.where(where ?? returnTrue)) {
      x.shift(delta);
    }
  }

  Map<int, (Offset, Offset)> recomputeIdleItemLocations({
    required Rect canvasGeometry,
    required AxisDirection axisDirection,
    bool notifyIdleItemListeners = true,
  }) =>
      switch (axisDirection) {
        AxisDirection.down => _recomputeIdleItemLocationsDown(
            canvasGeometry: canvasGeometry,
            notifyIdleItemListeners: notifyIdleItemListeners,
          ),
        AxisDirection.up => _recomputeIdleItemLocationsUp(
            canvasGeometry: canvasGeometry,
            notifyIdleItemListeners: notifyIdleItemListeners,
          ),
        AxisDirection.right => _recomputeIdleItemLocationsRight(
            canvasGeometry: canvasGeometry,
            notifyIdleItemListeners: notifyIdleItemListeners,
          ),
        AxisDirection.left => _recomputeIdleItemLocationsLeft(
            canvasGeometry: canvasGeometry,
            notifyIdleItemListeners: notifyIdleItemListeners,
          ),
      };

  void dispose() {
    for (var x in idleItems) {
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
  Map<int, (Offset, Offset)> _recomputeIdleItemLocationsDown({
    required Rect canvasGeometry,
    bool notifyIdleItemListeners = true,
  }) {
    final locationUpdateByItemId = <int, (Offset, Offset)>{};
    var cursor = canvasGeometry.location;
    var maxRowHeight = 0.0;

    for (var item in _itemIdByIndex.values.map((id) => idleItemBy(id: id)!)) {
      final testGeometry = cursor & item.size;

      if (testGeometry.deflate(alpha).right > canvasGeometry.right) {
        cursor += Offset(
          -(cursor.dx - canvasGeometry.left),
          maxRowHeight,
        );
        maxRowHeight = item.height;
      }

      final anchorLocation = cursor;

      if ((item.location - anchorLocation).distance > alpha) {
        locationUpdateByItemId[item.id] = (item.location, anchorLocation);
        item.setLocation(anchorLocation, notify: notifyIdleItemListeners);
      }

      maxRowHeight = math.max(maxRowHeight, item.height);
      cursor += Offset(item.width, 0);
    }

    return locationUpdateByItemId;
  }

  Map<int, (Offset, Offset)> _recomputeIdleItemLocationsUp({
    required Rect canvasGeometry,
    bool notifyIdleItemListeners = true,
  }) {
    final locationUpdateByItemId = <int, (Offset, Offset)>{};
    var cursor = canvasGeometry.bottomLeft;
    var maxRowHeight = 0.0;

    for (var item in _itemIdByIndex.values.map((id) => idleItemBy(id: id)!)) {
      final testGeometry = cursor & item.size;

      if (testGeometry.deflate(alpha).right > canvasGeometry.right) {
        cursor += Offset(
          -(cursor.dx - canvasGeometry.left),
          -maxRowHeight,
        );
        maxRowHeight = item.height;
      }

      final anchorLocation = cursor - Offset(0, item.height);

      if ((item.location - anchorLocation).distance > alpha) {
        locationUpdateByItemId[item.id] = (item.location, anchorLocation);
        item.setLocation(anchorLocation, notify: notifyIdleItemListeners);
      }

      maxRowHeight = math.max(maxRowHeight, item.height);
      cursor += Offset(item.width, 0);
    }

    return locationUpdateByItemId;
  }

  Map<int, (Offset, Offset)> _recomputeIdleItemLocationsRight({
    required Rect canvasGeometry,
    bool notifyIdleItemListeners = true,
  }) {
    final locationUpdateByItemId = <int, (Offset, Offset)>{};
    var cursor = canvasGeometry.topLeft;
    var maxColWidth = 0.0;

    for (var item in _itemIdByIndex.values.map((id) => idleItemBy(id: id)!)) {
      final testGeometry = cursor & item.size;

      if (testGeometry.deflate(alpha).bottom > canvasGeometry.bottom) {
        cursor += Offset(
          maxColWidth,
          -(cursor.dy - canvasGeometry.top),
        );
        maxColWidth = item.width;
      }

      final anchorLocation = cursor;

      if ((item.location - anchorLocation).distance > alpha) {
        locationUpdateByItemId[item.id] = (item.location, anchorLocation);
        item.setLocation(anchorLocation, notify: notifyIdleItemListeners);
      }

      maxColWidth = math.max(maxColWidth, item.width);
      cursor += Offset(0, item.height);
    }

    return locationUpdateByItemId;
  }

  Map<int, (Offset, Offset)> _recomputeIdleItemLocationsLeft({
    required Rect canvasGeometry,
    bool notifyIdleItemListeners = true,
  }) {
    final locationUpdateByItemId = <int, (Offset, Offset)>{};
    var cursor = canvasGeometry.topRight;
    var maxColWidth = 0.0;

    for (var item in _itemIdByIndex.values.map((id) => idleItemBy(id: id)!)) {
      final testGeometry = cursor & item.size;

      if (testGeometry.deflate(alpha).bottom > canvasGeometry.bottom) {
        cursor += Offset(
          -maxColWidth,
          -(cursor.dy - canvasGeometry.top),
        );
        maxColWidth = item.width;
      }

      final anchorLocation = cursor + Offset(-item.width, 0);

      if ((item.location - anchorLocation).distance > alpha) {
        locationUpdateByItemId[item.id] = (item.location, anchorLocation);
        item.setLocation(anchorLocation, notify: notifyIdleItemListeners);
      }

      maxColWidth = math.max(maxColWidth, item.width);
      cursor += Offset(0, item.height);
    }

    return locationUpdateByItemId;
  }
}
