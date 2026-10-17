import 'dart:math';

import 'package:animated_reorderable/animated_reorderable.dart'
    show Permutations;
import 'package:animated_reorderable/src/model/model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('moveItem', () {
    test('moves an item to the end', () {
      final registry = _registryOf([0, 1, 2, 3]);

      _move(registry, 0, 3);

      expect(_order(registry, 4), [1, 2, 3, 0]);
    });

    test('moves an item to the start', () {
      final registry = _registryOf([0, 1, 2, 3]);

      _move(registry, 3, 0);

      expect(_order(registry, 4), [3, 0, 1, 2]);
    });

    test('moves items around the ones that are not reorderable', () {
      final registry = _registryOf([0, 1, 2, 3, 4]);

      _move(registry, 0, 4, fixed: {2});

      expect(_order(registry, 5), [1, 3, 2, 4, 0]);
    });

    test('creates the items it moves that it does not have yet', () {
      final registry = _registryOf([0, 1, 2, 3], only: {0});

      _move(registry, 0, 3);

      expect(_order(registry, 4), [1, 2, 3, 0]);
    });

    test('changes nothing when an item stays', () {
      final registry = _registryOf([0, 1, 2]);

      expect(_move(registry, 1, 1), isEmpty);
      expect(_order(registry, 3), [0, 1, 2]);
    });

    test('moves the overlayed items along', () {
      final registry = _registryOf([0, 1, 2, 3]);
      final overlayed = registry.putOverlayedItem(_overlayed(1, index: 1));

      _move(registry, 0, 3);

      expect(overlayed.index, 0);
    });

    test('moves like a list does, with permutations that agree', () {
      final random = Random(1);
      for (var run = 0; run < 500; run++) {
        final count = 2 + random.nextInt(8);
        final ids = List.generate(count, (i) => i);
        final reorderable = ids.where((_) => random.nextInt(4) > 0).toList();
        if (reorderable.length < 2) continue;
        final from = reorderable[random.nextInt(reorderable.length)];
        final to = reorderable[random.nextInt(reorderable.length)];
        final registry = _registryOf(
          ids,
          only: ids.where((_) => random.nextBool()).toSet(),
        );
        final list = [...ids];
        final fixed = ids.toSet().difference(reorderable.toSet());
        final reason = 'move $from to $to of $count, fixed $fixed';

        _move(registry, from, to, fixed: fixed).apply(list);

        final expected = _reference(ids, from, to, fixed: fixed);
        expect(_order(registry, count), expected, reason: reason);
        expect(list, expected, reason: reason);
      }
    });

    test('keeps agreeing over a series of moves', () {
      final random = Random(2);
      const count = 8;
      const fixed = {2, 5};
      final reorderable = [0, 1, 3, 4, 6, 7];
      final registry = _registryOf(List.generate(count, (i) => i));
      var list = List.generate(count, (i) => i);
      var expected = [...list];

      for (var run = 0; run < 100; run++) {
        final from = reorderable[random.nextInt(reorderable.length)];
        final to = reorderable[random.nextInt(reorderable.length)];
        _move(registry, from, to, fixed: fixed).apply(list);
        expected = _reference(expected, from, to, fixed: fixed);

        expect(_order(registry, count), expected);
        expect(list, expected);
      }
    });
  });

  group('insertItem', () {
    test('shifts the items and the overlayed items after it', () {
      final ids = [0, 1, 2];
      final registry = _registryOf(ids);
      final before = registry.putOverlayedItem(_overlayed(0, index: 0));
      final after = registry.putOverlayedItem(_overlayed(1, index: 1));

      ids.insert(1, 9);
      registry.insertItem(index: 1);

      expect(_order(registry, 4), [0, 9, 1, 2]);
      expect(registry.itemCount, 4);
      expect(before.index, 0);
      expect(after.index, 2);
    });
  });

  group('removeItem', () {
    test('shifts the items and the overlayed items after it', () {
      final registry = _registryOf([0, 1, 2, 3]);
      final before = registry.putOverlayedItem(_overlayed(0, index: 0));
      final after = registry.putOverlayedItem(_overlayed(2, index: 2));

      final removed = registry.removeItem(index: 1);

      expect(removed?.key, const ValueKey(1));
      expect(_order(registry, 3), [0, 2, 3]);
      expect(registry.itemAt(index: 3), isNull);
      expect(registry.itemCount, 3);
      expect(before.index, 0);
      expect(after.index, 1);
    });
  });

  test('finds item indexes by key', () {
    final registry = _registryOf([0, 1, 2]);

    final childIndexGetter = registry.childIndexGetter();

    expect(childIndexGetter(const ValueKey(2)), 2);
    expect(childIndexGetter(const ValueKey(9)), isNull);
  });
}

/// A registry with the items of [ids] at their indexes, or only the ones
/// whose ids are in [only]. It creates the others from [ids].
ItemRegistry _registryOf(List<int> ids, {Set<int>? only}) {
  final registry = ItemRegistry(
    itemCount: ids.length,
    itemFactory: (index) => _item(ids[index]),
  );
  for (final (index, id) in ids.indexed) {
    if (only != null && !only.contains(id)) continue;
    registry.putItem(_item(id));
    registry.setIndex(itemKey: ValueKey(id), index: index);
  }
  return registry;
}

/// Moves the item at [from] to [to].
Permutations _move(
  ItemRegistry registry,
  int from,
  int to, {
  Set<int> fixed = const {},
}) => registry.moveItem(
  index: from,
  destIndex: to,
  reorderableGetter: (index) => !fixed.contains(index),
);

/// The ids of the items at the first [count] indexes. An index the registry
/// has no item for keeps the id of its index.
List<int> _order(ItemRegistry registry, int count) => [
  for (var index = 0; index < count; index++)
    switch (registry.itemAt(index: index)?.key) {
      ValueKey<int>(:final value) => value,
      _ => index,
    },
];

/// [ids] with the id at [from] moved to [to] and the ids at the [fixed]
/// indexes left where they are.
List<int> _reference(
  List<int> ids,
  int from,
  int to, {
  required Set<int> fixed,
}) {
  final slots = [
    for (var i = 0; i < ids.length; i++)
      if (!fixed.contains(i)) i,
  ];
  final moving = [for (final i in slots) ids[i]];
  moving.insert(slots.indexOf(to), moving.removeAt(slots.indexOf(from)));
  final result = [...ids];
  for (final (i, slot) in slots.indexed) {
    result[slot] = moving[i];
  }
  return result;
}

Item _item(int id) => Item(
  key: ValueKey(id),
  builder: ItemBuilder.adaptIndexedWidgetBuilder((_, _) => null),
);

OverlayedItem _overlayed(int id, {required int index}) => OverlayedItem(
  item: _item(id),
  position: Offset.zero,
  constraints: const BoxConstraints(),
  size: Size.zero,
  index: index,
);
