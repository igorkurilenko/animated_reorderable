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

  IdleItem putIdleItem(IdleItem item) => _idleItemById[item.id] = item;

  RenderedItem putRenderedItem(RenderedItem item) =>
      _renderedItemById[item.id] = item;

  RenderedItem? renderedItemBy({required int id}) => _renderedItemById[id];

  RenderedItem? removeRenderedItemBy({required int id}) =>
      _renderedItemById.remove(id);

  void setOrder({required int index, required int id}) =>
      _itemIdByIndex[index] = id;
}
