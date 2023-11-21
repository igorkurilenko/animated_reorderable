part of model;

class ControllerState {
  final _idleItemById = <int, IdleItem>{};
  final _overlayedItemById = <int, OverlayedItem>{};
  final _outgoingItemById = <int, OutgoingItem>{};
  final _itemIdByIndex = SplayTreeMap<int, int>();
  final _renderedItemById = <int, RenderedItem>{};
  int? itemCount;

  Iterable<OutgoingItem> get outgoingItems => _outgoingItemById.values;

  Iterable<OverlayedItem> get overlayedItems => _overlayedItemById.values;

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

  OverlayedItem putOverlayedItem(OverlayedItem x) {
    _overlayedItemById.remove(x.id);
    return _overlayedItemById[x.id] = x;
  }

  OverlayedItem? removeOverlayedItem({required int id}) =>
      _overlayedItemById.remove(id);

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
}
