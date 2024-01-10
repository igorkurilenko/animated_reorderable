import 'package:flutter/widgets.dart';

class Permutations {
  final _permutations = <_Permuration>[];
  final _indexByItemKey = <Key, int>{};
  final _itemKeyByIndex = <int, Key>{};

  void addPermutation({
    required Key itemKey,
    required int from,
    required int to,
  }) =>
      _add(_Permuration(
        itemKey: itemKey,
        from: from,
        to: to,
      ));

  void _add(_Permuration p) {
    final curIndexOfElement = indexOf(p.itemKey);
    _itemKeyByIndex.remove(curIndexOfElement);

    final unorderedElementId = itemKeyAt(p.to);
    _indexByItemKey.remove(unorderedElementId);

    _indexByItemKey[p.itemKey] = p.to;
    _itemKeyByIndex[p.to] = p.itemKey;

    _permutations.add(p);
  }

  int? indexOf(Key itemKey) => _indexByItemKey[itemKey];

  Key? itemKeyAt(int index) => _itemKeyByIndex[index];

  void apply<T>(List<T> list) {
    final unordered = <int, T>{};
    final emptySlots = <int>{};
    for (final p in _permutations) {
      if (!emptySlots.contains(p.to)) {
        unordered[p.to] = list[p.to];
      }
      if (unordered.containsKey(p.from)) {
        list[p.to] = unordered.remove(p.from) as T;
      } else {
        list[p.to] = list[p.from];
        emptySlots.add(p.from);
      }
      emptySlots.remove(p.to);
    }
  }

  bool get isEmpty => _permutations.isEmpty;

  @override
  String toString() => _permutations.toString();
}

class _Permuration {
  final Key itemKey;
  final int from;
  final int to;

  _Permuration({
    required this.itemKey,
    required this.from,
    required this.to,
  });
}