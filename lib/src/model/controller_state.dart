part of model;

class ControllerState<ItemsLayerState extends State<StatefulWidget>,
    OverlayedItemsLayerState extends State<StatefulWidget>> {
  ControllerState({this.itemCount});

  GlobalKey<ItemsLayerState> _itemsLayerKey = GlobalKey<ItemsLayerState>();
  GlobalKey<OverlayedItemsLayerState> _overlayedItemsLayerKey =
      GlobalKey<OverlayedItemsLayerState>();

  final _itemById = <int, Item>{};
  final _itemIdByIndex = SplayTreeMap<int, int>();
  final _overlayedItemById = <int, OverlayedItem>{};
  final _renderedItemById = <int, RenderedItem>{};
  OverlayedItem? draggedItem;
  OverlayedItem? swipedItem;
  int? itemUnderThePointerId;
  int? itemCount;
  BoxConstraints? constraints;
  SliverGridLayout? gridLayout;
  Offset scrollOffset = Offset.zero;
  bool shiftItemsOnScroll = true;

  GlobalKey<ItemsLayerState> get itemsLayerKey => _itemsLayerKey;

  ItemsLayerState? get itemsLayerState => itemsLayerKey.currentState;

  GlobalKey<OverlayedItemsLayerState> get overlayedItemsLayerKey =>
      _overlayedItemsLayerKey;

  OverlayedItemsLayerState? get overlayedItemsLayerState =>
      overlayedItemsLayerKey.currentState;

  Iterable<Item> get items => _itemById.values;

  Iterable<OverlayedItem> get overlayedItems => _overlayedItemById.values;

  Iterable<RenderedItem> get renderedItems => _renderedItemById.values;

  bool isDragged({required int id}) => id == draggedItem?.id;

  bool isSwiped({required int id}) => id == swipedItem?.id;

  Iterable<(int, Item)> iterator() => _itemIdByIndex.entries.map(
        (e) => (e.key, itemBy(id: e.value)!),
      );

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

  OverlayedItem putOverlayedItemIfAbsent(
          {required int id, required OverlayedItem Function() ifAbsent}) =>
      putOverlayedItem(overlayedItemBy(id: id) ?? ifAbsent());

  OverlayedItem? removeOverlayedItem({required int id}) =>
      _overlayedItemById.remove(id);

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

    for (var overlayedItem in overlayedItems) {
      if (overlayedItem.index > index) {
        overlayedItem.index--;
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

    for (var overlayedItem in overlayedItems) {
      overlayedItem.index =
          permutations.indexOf(overlayedItem.id) ?? overlayedItem.index;
    }

    return permutations;
  }

  void reset() {
    _itemsLayerKey = GlobalKey<ItemsLayerState>();
    _overlayedItemsLayerKey = GlobalKey<OverlayedItemsLayerState>();
    _itemById.clear();
    _overlayedItemById.clear();
    _itemIdByIndex.clear();
    _renderedItemById.clear();
    draggedItem = null;
    swipedItem = null;
    itemUnderThePointerId = null;
    itemCount = null;
    constraints = null;
    scrollOffset = Offset.zero;
    shiftItemsOnScroll = true;
    gridLayout = null;
  }

  void dispose() {
    for (var x in items) {
      x.dispose();
    }
    for (var x in overlayedItems) {
      x.dispose();
    }
    reset();
  }
}
