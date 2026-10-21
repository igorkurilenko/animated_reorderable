import 'package:flutter/widgets.dart';

import '../util/key_map.dart';

/// The moves of the items a reorder takes to new indexes, each from its
/// old index to its new one, in the order the reorder makes them.
///
/// [ReorderOptions.onReorder] gets them, and [apply] makes them on the
/// app's items, so they keep the order the list shows:
///
/// ```dart
/// reorder: ReorderOptions(
///   onReorder: (moves) => moves.apply(items),
/// ),
/// ```
class ItemMoves extends Iterable<ItemMove> {
  final _moves = <ItemMove>[];
  final _indexByItemKey = keyMap<int>();
  final _itemKeyByIndex = <int, Key>{};

  /// Adds the move of the item with [itemKey] from [srcIndex] to
  /// [destIndex].
  void addMove({
    required Key itemKey,
    required int srcIndex,
    required int destIndex,
  }) => _add(ItemMove(itemKey: itemKey, from: srcIndex, to: destIndex));

  /// Adds the move of the item with [itemKey] from [srcIndex] to
  /// [destIndex].
  @Deprecated('Use addMove instead. It goes in 3.0.')
  void addPermutation({
    required Key itemKey,
    required int srcIndex,
    required int destIndex,
  }) => addMove(itemKey: itemKey, srcIndex: srcIndex, destIndex: destIndex);

  void _add(ItemMove move) {
    final curIndexOfElement = indexOf(move.itemKey);
    _itemKeyByIndex.remove(curIndexOfElement);

    final unorderedElementId = itemKeyAt(move.to);
    _indexByItemKey.remove(unorderedElementId);

    _indexByItemKey[move.itemKey] = move.to;
    _itemKeyByIndex[move.to] = move.itemKey;

    _moves.add(move);
  }

  /// The index the moves take the item with [itemKey] to, or null if they
  /// don't move it.
  int? indexOf(Key itemKey) => _indexByItemKey[itemKey];

  /// The key of the item the moves take to [index], or null if they take
  /// none there.
  Key? itemKeyAt(int index) => _itemKeyByIndex[index];

  /// Makes the moves on [list], which holds the items in the order the
  /// list showed them before the moves.
  void apply<T>(List<T> list) {
    final unordered = <int, T>{};
    final emptySlots = <int>{};
    for (final move in _moves) {
      if (!emptySlots.contains(move.to)) {
        unordered[move.to] = list[move.to];
      }
      if (unordered.containsKey(move.from)) {
        list[move.to] = unordered.remove(move.from) as T;
      } else {
        list[move.to] = list[move.from];
        emptySlots.add(move.from);
      }
      emptySlots.remove(move.to);
    }
  }

  /// Whether there are no moves.
  @override
  bool get isEmpty => _moves.isEmpty;

  /// The number of moves.
  @override
  int get length => _moves.length;

  /// Iterates over the moves, in the order they're made.
  @override
  Iterator<ItemMove> get iterator => _moves.iterator;
}

/// The move of an item from one index to another. Two moves are equal when
/// they move the same item from and to the same indexes.
class ItemMove {
  const ItemMove({required this.itemKey, required this.from, required this.to});

  /// The key of the item that moves.
  final Key itemKey;

  /// The index the item moves from, starting at zero.
  final int from;

  /// The index the item moves to, starting at zero.
  final int to;

  @override
  bool operator ==(Object other) =>
      other is ItemMove &&
      other.itemKey == itemKey &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(itemKey, from, to);

  @override
  String toString() => 'ItemMove(itemKey: $itemKey, from: $from, to: $to)';
}

/// The name [ItemMove] had before 2.9.
@Deprecated('Use ItemMove instead. It goes in 3.0.')
typedef Permutation = ItemMove;

/// The name [ItemMoves] had before 2.9.
@Deprecated('Use ItemMoves instead. It goes in 3.0.')
typedef Permutations = ItemMoves;
