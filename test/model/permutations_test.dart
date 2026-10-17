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
    final permutations = _moves(list, [(0, 2), (2, 1), (1, 0)]);

    expect(permutations.indexOf(const ValueKey('a')), 2);
    expect(permutations.indexOf(const ValueKey('c')), 1);
    expect(permutations.itemKeyAt(0), const ValueKey('b'));
    expect(permutations.length, 3);
  });

  test('changes nothing when empty', () {
    final list = ['a', 'b'];
    final permutations = Permutations()..apply(list);

    expect(list, ['a', 'b']);
    expect(permutations, isEmpty);
  });
}

/// The permutations that move the items of [list] by their indexes,
/// in order.
Permutations _moves(List<String> list, List<(int, int)> moves) {
  final permutations = Permutations();
  for (final (from, to) in moves) {
    permutations.addPermutation(
      itemKey: ValueKey(list[from]),
      srcIndex: from,
      destIndex: to,
    );
  }
  return permutations;
}
