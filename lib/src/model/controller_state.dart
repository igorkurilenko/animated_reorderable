part of 'model.dart';

class ControllerState {
  ControllerState({this.itemCount});

  /// Notifies when an item is inserted, removed or moved.
  final itemsChanges = ChangeSignal();

  /// Notifies when an item enters or leaves the overlay, or moves above or
  /// under the other overlayed items.
  final overlayChanges = ChangeSignal();

  final _itemByKey = <Key, Item>{};
  final _itemKeyByIndex = SplayTreeMap<int, Key>();
  final _overlayedItemByKey = <Key, OverlayedItem>{};

  /// The removed items that animate out. The overlay shows them, but not
  /// by their keys: the list can show an item with the same key meanwhile.
  final _outgoingItems = <OverlayedItem>[];
  final _renderedItemByKey = <Key, RenderedItem>{};
  OverlayedItem? draggedItem;
  OverlayedItem? swipedItem;
  Key? itemUnderThePointerKey;
  int? itemCount;
  SliverGridLayout? gridLayout;

  /// The scroll extent before the grid, like its padding.
  double gridPrecedingScrollExtent = 0.0;

  /// The first visible item of the grid before its cross axis resized:
  /// its index, its leading edge relative to the viewport's and its main
  /// axis extent.
  ({int index, double leadingEdge, double extent})? scrollAnchor;
  Offset scrollOffset = Offset.zero;

  Iterable<Item> get items => _itemByKey.values;

  Iterable<OverlayedItem> get overlayedItems => _overlayedItemByKey.values;

  Iterable<OverlayedItem> get outgoingItems => _outgoingItems;

  Iterable<RenderedItem> get renderedItems => _renderedItemByKey.values;

  bool isDragged({required Key key}) => key == draggedItem?.key;

  bool isSwiped({required Key key}) => key == swipedItem?.key;

  Item? itemAt({required int index}) => switch (_itemKeyByIndex[index]) {
    final key? => itemBy(key: key),
    null => null,
  };

  Item? itemBy({required Key key}) => _itemByKey[key];

  Item putItem(Item x) => _itemByKey[x.key] = x;

  RenderedItem putRenderedItem(RenderedItem x) => _renderedItemByKey[x.key] = x;

  RenderedItem? renderedItemBy({required Key key}) => _renderedItemByKey[key];

  RenderedItem? removeRenderedItemBy({required Key key}) =>
      _renderedItemByKey.remove(key);

  bool isRendered({required Key key}) => _renderedItemByKey.containsKey(key);

  /// Finds an item's index by its key, so the list moves an item's element
  /// along with the item instead of building it again.
  ChildIndexGetter childIndexGetter() {
    final indexByKey = {
      for (final MapEntry(key: index, value: key) in _itemKeyByIndex.entries)
        key: index,
    };
    return (key) => indexByKey[key];
  }

  void setIndex({required Key itemKey, required int index}) =>
      _itemKeyByIndex[index] = itemKey;

  bool isOverlayed({required Key key}) => _overlayedItemByKey.containsKey(key);

  OverlayedItem? overlayedItemBy({required Key key}) =>
      _overlayedItemByKey[key];

  OverlayedItem putOverlayedItem(OverlayedItem x) {
    final replaced = _overlayedItemByKey.remove(x.key);
    if (replaced != null && replaced != x) replaced.dispose();
    _overlayedItemByKey[x.key] = x;
    overlayChanges.notify();
    return x;
  }

  OverlayedItem putOverlayedItemIfAbsent({
    required Key key,
    required OverlayedItem Function() ifAbsent,
  }) => putOverlayedItem(overlayedItemBy(key: key) ?? ifAbsent());

  OverlayedItem? removeOverlayedItem({required Key key}) {
    final removed = _overlayedItemByKey.remove(key);
    if (removed != null) overlayChanges.notify();
    return removed;
  }

  void addOutgoingItem(OverlayedItem x) {
    _outgoingItems.add(x);
    overlayChanges.notify();
  }

  /// Takes [x] out of the overlay once it has animated out, and disposes
  /// it with its item, which the list no longer has.
  void removeOutgoingItem(OverlayedItem x) {
    if (!_outgoingItems.remove(x)) return;
    overlayChanges.notify();
    x.dispose();
    x.item.dispose();
  }

  void setZIndex(OverlayedItem item, int zIndex) {
    if (item.zIndex == zIndex) return;
    item.zIndex = zIndex;
    overlayChanges.notify();
  }

  RenderedItem? renderedItemAt({required Offset position}) =>
      renderedItems.where((x) => x.contains(position)).firstOrNull;

  Item insertItem({
    required int index,
    required Item Function(int index) itemFactory,
  }) {
    for (var i in _itemKeyByIndex.keys.toList().reversed) {
      if (i < index) break;
      _itemKeyByIndex[i + 1] = _itemKeyByIndex[i]!;
    }

    for (var overlayedItem in [...overlayedItems, ..._outgoingItems]) {
      if (overlayedItem.index >= index) {
        overlayedItem.index++;
      }
    }

    final item = itemFactory.call(index);

    _itemByKey[item.key] = item;
    _itemKeyByIndex[index] = item.key;

    itemCount = itemCount! + 1;
    itemsChanges.notify();

    return item;
  }

  Item? removeItem({required int index}) {
    final key = _itemKeyByIndex.remove(index);

    itemCount = itemCount! - 1;

    int? lastIndex;
    for (var i in _itemKeyByIndex.keys.toList()) {
      if (i > index) {
        _itemKeyByIndex[i - 1] = _itemKeyByIndex[i]!;
        lastIndex = i;
      }
    }
    _itemKeyByIndex.remove(lastIndex);

    for (var overlayedItem in [...overlayedItems, ..._outgoingItems]) {
      if (overlayedItem.index > index) {
        overlayedItem.index--;
      }
    }
    itemsChanges.notify();

    return _itemByKey.remove(key);
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
    Key unorderedItemKey = curItem.key;
    int unorderedItemIndex = index;

    for (var curIndex = destIndex; ; curIndex = nextIndex(curIndex)) {
      curItem = itemAt(index: curIndex) ?? putItem(itemFactory(curIndex));

      if (reorderableGetter(curIndex)) {
        _itemKeyByIndex[curIndex] = unorderedItemKey;

        permutations.addPermutation(
          itemKey: unorderedItemKey,
          srcIndex: unorderedItemIndex,
          destIndex: curIndex,
        );

        unorderedItemKey = curItem.key;
        unorderedItemIndex = curIndex;
      }

      if (curIndex == index) break;
    }

    for (var overlayedItem in overlayedItems) {
      overlayedItem.index =
          permutations.indexOf(overlayedItem.key) ?? overlayedItem.index;
    }
    itemsChanges.notify();

    return permutations;
  }

  void dispose() {
    for (var x in items) {
      x.dispose();
    }
    for (var x in overlayedItems) {
      x.dispose();
    }
    for (var x in _outgoingItems) {
      x.dispose();
      x.item.dispose();
    }
    _itemByKey.clear();
    _overlayedItemByKey.clear();
    _outgoingItems.clear();
    _itemKeyByIndex.clear();
    _renderedItemByKey.clear();
    draggedItem = null;
    swipedItem = null;
    itemsChanges.dispose();
    overlayChanges.dispose();
  }
}
