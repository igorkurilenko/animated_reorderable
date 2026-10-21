import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('applies a move to the end', () {
    final list = ['a', 'b', 'c', 'd'];
    _moves(list, [(0, 3), (3, 2), (2, 1), (1, 0)]).apply(list);

    expect(list, ['b', 'c', 'd', 'a']);
  });

  test('applies a move to the start', () {
    final list = ['a', 'b', 'c', 'd'];
    _moves(list, [(3, 0), (0, 1), (1, 2), (2, 3)]).apply(list);

    expect(list, ['d', 'a', 'b', 'c']);
  });

  test('applies a move around a fixed item', () {
    final list = ['a', 'b', 'c', 'd', 'e'];
    // c stays where it is.
    _moves(list, [(0, 4), (4, 3), (3, 1), (1, 0)]).apply(list);

    expect(list, ['b', 'd', 'c', 'e', 'a']);
  });

  test('applies a swap', () {
    final list = ['a', 'b', 'c'];
    _moves(list, [(0, 2), (2, 0)]).apply(list);

    expect(list, ['c', 'b', 'a']);
  });

  test('finds items by index and indexes by item', () {
    final list = ['a', 'b', 'c'];
    final moves = _moves(list, [(0, 2), (2, 1), (1, 0)]);

    expect(moves.indexOf(const ValueKey('a')), 2);
    expect(moves.indexOf(const ValueKey('c')), 1);
    expect(moves.itemKeyAt(0), const ValueKey('b'));
    expect(moves.length, 3);
  });

  test('lists the moves it applies', () {
    final list = ['a', 'b', 'c'];

    expect(_moves(list, [(0, 2), (2, 1), (1, 0)]), const [
      ItemMove(itemKey: ValueKey('a'), from: 0, to: 2),
      ItemMove(itemKey: ValueKey('c'), from: 2, to: 1),
      ItemMove(itemKey: ValueKey('b'), from: 1, to: 0),
    ]);
  });

  test('compares moves by value', () {
    const a = ItemMove(itemKey: ValueKey('a'), from: 0, to: 2);
    const b = ItemMove(itemKey: ValueKey('b'), from: 0, to: 2);

    expect(a, ItemMove(itemKey: const ValueKey('a'), from: 0, to: 2));
    expect(
      a.hashCode,
      ItemMove(itemKey: const ValueKey('a'), from: 0, to: 2).hashCode,
    );
    expect(a, isNot(b));
    expect(a, isNot(const ItemMove(itemKey: ValueKey('a'), from: 1, to: 2)));
    expect(a, isNot(const ItemMove(itemKey: ValueKey('a'), from: 0, to: 1)));
    expect('$a', "ItemMove(itemKey: [<'a'>], from: 0, to: 2)");
  });

  test('takes the names it had before 2.9', () {
    // ignore: deprecated_member_use_from_same_package
    final Permutations moves = Permutations()
      // ignore: deprecated_member_use_from_same_package
      ..addPermutation(itemKey: const ValueKey('a'), srcIndex: 0, destIndex: 1);
    // ignore: deprecated_member_use_from_same_package
    const Permutation move = Permutation(
      itemKey: ValueKey('a'),
      from: 0,
      to: 1,
    );
    final reorders = <ItemMoves>[];
    // ignore: deprecated_member_use_from_same_package
    final PermutationsCallback onReorder = reorders.add;

    onReorder(moves);

    expect(reorders.single, [move]);
    expect(reorders.single, isA<ItemMoves>());
    expect(move, const ItemMove(itemKey: ValueKey('a'), from: 0, to: 1));
  });

  test('changes nothing when empty', () {
    final list = ['a', 'b'];
    final moves = ItemMoves()..apply(list);

    expect(list, ['a', 'b']);
    expect(moves, isEmpty);
  });
}

/// The moves of the items of [list] by their indexes, in order.
ItemMoves _moves(List<String> list, List<(int, int)> indexes) {
  final moves = ItemMoves();
  for (final (from, to) in indexes) {
    moves.addMove(itemKey: ValueKey(list[from]), srcIndex: from, destIndex: to);
  }
  return moves;
}
