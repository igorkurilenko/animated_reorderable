import 'package:animated_reorderable/src/util/key_map.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds an item by a value key equal to its own', () {
    final map = keyMap<String>()..[const ValueKey(1)] = 'one';

    expect(map[ValueKey(1)], 'one');
    expect(map[ValueKey(2)], isNull);
  });

  test('keeps value keys of different types apart', () {
    final map = keyMap<String>()
      ..[const ValueKey<int>(1)] = 'int'
      ..[const ValueKey<num>(1)] = 'num';

    expect(map, hasLength(2));
    expect(map[const ValueKey<int>(1)], 'int');
    expect(map[const ValueKey<num>(1)], 'num');
    expect(map[const ValueKey<String>('1')], isNull);
  });

  test('finds other keys by their own equality', () {
    final object = Object();
    final unique = UniqueKey();
    final global = GlobalKey();
    final map = keyMap<String>()
      ..[ObjectKey(object)] = 'object'
      ..[unique] = 'unique'
      ..[global] = 'global';

    expect(map[ObjectKey(object)], 'object');
    expect(map[ObjectKey(Object())], isNull);
    expect(map[unique], 'unique');
    expect(map[UniqueKey()], isNull);
    expect(map[global], 'global');
  });

  test('looks keys up after removing some', () {
    final map = keyMap<int>();
    for (var i = 0; i < 8; i++) {
      map[ValueKey(i)] = i;
    }

    map.removeWhere((key, value) => value.isEven);

    for (var i = 0; i < 8; i++) {
      expect(map[ValueKey(i)], i.isEven ? null : i);
    }
  });

  test('hashes value keys without their runtimeType', () {
    final gets = <int>[];
    final key = _CountingKey(1, gets);
    final map = keyMap<String>()..[key] = 'one';

    expect(map[key], 'one');
    expect(map[_CountingKey(2, gets)], isNull);
    expect(gets, isEmpty);
  });
}

/// A value key that notes in [gets] each time its runtimeType is got.
class _CountingKey extends ValueKey<int> {
  const _CountingKey(super.value, this.gets);

  final List<int> gets;

  @override
  Type get runtimeType {
    gets.add(value);
    return super.runtimeType;
  }
}
