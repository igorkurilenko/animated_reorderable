import 'dart:math';

import 'package:animated_reorderable/animated_reorderable.dart'
    show Permutations;
import 'package:animated_reorderable/src/model/model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('moveItem', () {
    test('moves an item to the end', () {
      final state = _stateOf([0, 1, 2, 3]);

      _move(state, 0, 3);

      expect(_order(state, 4), [1, 2, 3, 0]);
    });

    test('moves an item to the start', () {
      final state = _stateOf([0, 1, 2, 3]);

      _move(state, 3, 0);

      expect(_order(state, 4), [3, 0, 1, 2]);
    });

    test('moves items around the ones that are not reorderable', () {
      final state = _stateOf([0, 1, 2, 3, 4]);

      _move(state, 0, 4, fixed: {2});

      expect(_order(state, 5), [1, 3, 2, 4, 0]);
    });

    test('creates the items it moves that it does not have yet', () {
      final state = _stateOf([0, 1, 2, 3], only: {0});

      _move(state, 0, 3);

      expect(_order(state, 4), [1, 2, 3, 0]);
    });

    test('changes nothing when an item stays', () {
      final state = _stateOf([0, 1, 2]);

      expect(_move(state, 1, 1), isEmpty);
      expect(_order(state, 3), [0, 1, 2]);
    });

    test('moves the overlayed items along', () {
      final state = _stateOf([0, 1, 2, 3]);
      final overlayed = state.putOverlayedItem(_overlayed(1, index: 1));

      _move(state, 0, 3);

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
        final state = _stateOf(
          ids,
          only: ids.where((_) => random.nextBool()).toSet(),
        );
        final list = [...ids];
        final fixed = ids.toSet().difference(reorderable.toSet());
        final reason = 'move $from to $to of $count, fixed $fixed';

        _move(state, from, to, fixed: fixed).apply(list);

        final expected = _reference(ids, from, to, fixed: fixed);
        expect(_order(state, count), expected, reason: reason);
        expect(list, expected, reason: reason);
      }
    });

    test('keeps agreeing over a series of moves', () {
      final random = Random(2);
      const count = 8;
      const fixed = {2, 5};
      final reorderable = [0, 1, 3, 4, 6, 7];
      final state = _stateOf(List.generate(count, (i) => i));
      var list = List.generate(count, (i) => i);
      var expected = [...list];

      for (var run = 0; run < 100; run++) {
        final from = reorderable[random.nextInt(reorderable.length)];
        final to = reorderable[random.nextInt(reorderable.length)];
        _move(state, from, to, fixed: fixed).apply(list);
        expected = _reference(expected, from, to, fixed: fixed);

        expect(_order(state, count), expected);
        expect(list, expected);
      }
    });
  });

  group('insertItem', () {
    test('shifts the items and the overlayed items after it', () {
      final state = _stateOf([0, 1, 2]);
      final before = state.putOverlayedItem(_overlayed(0, index: 0));
      final after = state.putOverlayedItem(_overlayed(1, index: 1));

      state.insertItem(index: 1, itemFactory: (_) => _item(9));

      expect(_order(state, 4), [0, 9, 1, 2]);
      expect(state.itemCount, 4);
      expect(before.index, 0);
      expect(after.index, 2);
    });
  });

  group('removeItem', () {
    test('shifts the items and the overlayed items after it', () {
      final state = _stateOf([0, 1, 2, 3]);
      final before = state.putOverlayedItem(_overlayed(0, index: 0));
      final after = state.putOverlayedItem(_overlayed(2, index: 2));

      final removed = state.removeItem(index: 1);

      expect(removed?.key, const ValueKey(1));
      expect(_order(state, 3), [0, 2, 3]);
      expect(state.itemAt(index: 3), isNull);
      expect(state.itemCount, 3);
      expect(before.index, 0);
      expect(after.index, 1);
    });
  });

  test('finds item indexes by key', () {
    final state = _stateOf([0, 1, 2]);

    final childIndexGetter = state.childIndexGetter();

    expect(childIndexGetter(const ValueKey(2)), 2);
    expect(childIndexGetter(const ValueKey(9)), isNull);
  });
}

typedef _State = ControllerState<State<StatefulWidget>, State<StatefulWidget>>;

/// A state with the items of [ids] at their indexes, or only the ones
/// whose ids are in [only].
_State _stateOf(List<int> ids, {Set<int>? only}) {
  final state = _State(itemCount: ids.length);
  for (final (index, id) in ids.indexed) {
    if (only != null && !only.contains(id)) continue;
    state.putItem(_item(id));
    state.setIndex(itemKey: ValueKey(id), index: index);
  }
  return state;
}

/// Moves the item at [from] to [to]. The item at an index the state has no
/// item for yet has the id of its index.
Permutations _move(
  _State state,
  int from,
  int to, {
  Set<int> fixed = const {},
}) => state.moveItem(
  index: from,
  destIndex: to,
  reorderableGetter: (index) => !fixed.contains(index),
  itemFactory: _item,
);

/// The ids of the items at the first [count] indexes. An index the state
/// has no item for keeps the id of its index.
List<int> _order(_State state, int count) => [
  for (var index = 0; index < count; index++)
    switch (state.itemAt(index: index)?.key) {
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
  key: ValueKey(id),
  builder: ItemBuilder.adaptIndexedWidgetBuilder((_, _) => null),
  position: Offset.zero,
  constraints: const BoxConstraints(),
  size: Size.zero,
  index: index,
);
