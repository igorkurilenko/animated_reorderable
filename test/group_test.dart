import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _extent = 100.0;

void main() {
  group('between lists', () {
    testWidgets('drags an item from one list to another', (tester) async {
      final board = _Board({
        'a': [0, 1, 2],
        'b': [10, 11, 12],
      });
      await tester.pumpWidget(board.build());

      final drag = await _hold(tester, find.text('1'));
      final from = tester.getCenter(find.text('1'));
      final to = tester.getCenter(find.text('10'));
      for (final step in _steps(from, to, 20)) {
        await drag.moveTo(step);
        await tester.pump(const Duration(milliseconds: 16));
        // It stays under the pointer as it goes over the other list.
        expect(tester.getCenter(find.text('1')), _closeTo(step, 1));
      }

      // The items of both lists move in place: up into its old slot, and
      // down out of its new one.
      expect(
        tester.getTopLeft(find.text('2')).dy,
        inExclusiveRange(_extent, 2 * _extent),
      );
      expect(
        tester.getTopLeft(find.text('12')).dy,
        inExclusiveRange(2 * _extent, 3 * _extent),
      );

      // It goes in over item 11, then takes item 10's place there.
      expect(board.moves, [((list: 'a', index: 1), (list: 'b', index: 1))]);
      expect(board.columns, {
        'a': [0, 2],
        'b': [1, 10, 11, 12],
      });

      await drag.up();
      await tester.pumpAndSettle();

      // It lands in the other list's first slot, and keeps its state.
      expect(tester.getTopLeft(find.text('1')), const Offset(400, 0));
      expect(tester.getTopLeft(find.text('10')), const Offset(400, _extent));
      expect(tester.getTopLeft(find.text('2')), const Offset(0, _extent));
      expect(board.inits[1], 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('drags an item past the end of another list', (tester) async {
      final board = _Board({
        'a': [0, 1, 2],
        'b': [10],
      });
      await tester.pumpWidget(board.build());

      // Down past the list's own items, then across, below the other's.
      final drag = await _hold(tester, find.text('2'));
      const below = Offset(200, 450);
      await _dragAlong(tester, drag, [
        ..._steps(tester.getCenter(find.text('2')), below, 10),
        ..._steps(below, const Offset(600, 450), 10),
      ]);
      await drag.up();
      await tester.pumpAndSettle();

      expect(board.moves, [((list: 'a', index: 2), (list: 'b', index: 1))]);
      expect(tester.getTopLeft(find.text('2')), const Offset(400, _extent));
    });

    testWidgets('drags the only item of a list into an empty one', (
      tester,
    ) async {
      final board = _Board({
        'a': [0],
        'b': [],
      });
      await tester.pumpWidget(board.build());

      final drag = await _hold(tester, find.text('0'));
      await _dragAlong(
        tester,
        drag,
        _steps(tester.getCenter(find.text('0')), const Offset(600, 50), 10),
      );
      await drag.up();
      await tester.pumpAndSettle();

      expect(board.moves, [((list: 'a', index: 0), (list: 'b', index: 0))]);
      expect(board.columns, {
        'a': <int>[],
        'b': [0],
      });
      expect(tester.getTopLeft(find.text('0')), const Offset(400, 0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('drops an item before the first item past the pointer', (
      tester,
    ) async {
      final board = _Board(
        {
          'a': [0, 1],
          'b': [10, 11],
        },
        paddings: {'b': const EdgeInsets.only(top: _extent)},
      );
      await tester.pumpWidget(board.build());

      // Into the other list's padding, above its first item.
      final drag = await _hold(tester, find.text('0'));
      await _dragAlong(
        tester,
        drag,
        _steps(tester.getCenter(find.text('0')), const Offset(600, 50), 10),
      );
      await drag.up();
      await tester.pumpAndSettle();

      expect(board.moves.single.$2, (list: 'b', index: 0));
      expect(tester.getTopLeft(find.text('0')), const Offset(400, _extent));
    });

    testWidgets('asks once whether an item may go to a list', (tester) async {
      final asked = <ItemPlace>[];
      final board = _Board(
        {
          'a': [0, 1],
          'b': [10, 11],
        },
        canMove: (from, to) {
          asked.add(to);
          return false;
        },
      );
      await tester.pumpWidget(board.build());

      final drag = await _hold(tester, find.text('0'));
      final from = tester.getCenter(find.text('0'));
      const over = Offset(600, 50);
      await _dragAlong(tester, drag, [
        ..._steps(from, over, 10),
        // Around the other list, then back to the item's own and over the
        // other again.
        ..._steps(over, const Offset(650, 150), 5),
        ..._steps(const Offset(650, 150), from, 10),
        ..._steps(from, over, 10),
      ]);
      await drag.up();
      await tester.pumpAndSettle();

      expect(asked.map((x) => x.list), ['b', 'b']);
      expect(board.moves, isEmpty);
      expect(tester.getTopLeft(find.text('0')), Offset.zero);
    });

    testWidgets('calls the drag callbacks of the list the item is in', (
      tester,
    ) async {
      final board = _Board({
        'a': [0, 1],
        'b': [10],
      });
      await tester.pumpWidget(board.build());

      final drag = await _hold(tester, find.text('1'));
      await _dragAlong(
        tester,
        drag,
        _steps(tester.getCenter(find.text('1')), const Offset(600, 50), 10),
      );
      await drag.up();
      await tester.pumpAndSettle();

      expect(board.events.first, ('a', 'start', 1));
      // The update it goes over on still comes from the list it leaves.
      final updates = [
        for (final (list, event, _) in board.events)
          if (event == 'update') list,
      ];
      expect(updates.first, 'a');
      expect(updates.skipWhile((x) => x == 'a'), everyElement('b'));
      expect(updates.last, 'b');
      expect(board.events.last, ('b', 'end', 0));
    });

    testWidgets('lets go of an item whose list goes away mid-drag', (
      tester,
    ) async {
      final board = _Board({
        'a': [0, 1],
        'b': [10],
      });
      await tester.pumpWidget(board.build());

      final drag = await _hold(tester, find.text('1'));
      await _dragAlong(
        tester,
        drag,
        _steps(tester.getCenter(find.text('1')), const Offset(600, 50), 10),
      );
      board.columns.remove('b');
      await tester.pumpWidget(board.build());
      await drag.moveBy(const Offset(-20, 0));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      expect(find.text('1'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps an item out of a list with no group id', (tester) async {
      final board = _Board(
        {
          'a': [0, 1],
          'b': [10],
        },
        withoutGroupId: {'b'},
      );
      await tester.pumpWidget(board.build());

      final drag = await _hold(tester, find.text('1'));
      await _dragAlong(
        tester,
        drag,
        _steps(tester.getCenter(find.text('1')), const Offset(600, 50), 10),
      );
      await drag.up();
      await tester.pumpAndSettle();

      expect(board.moves, isEmpty);
      expect(tester.getTopLeft(find.text('1')), const Offset(0, _extent));
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the items of a list with no group id', (tester) async {
      final board = _Board(
        {
          'a': [0, 1],
          'b': [10],
        },
        withoutGroupId: {'a'},
      );
      await tester.pumpWidget(board.build());

      final drag = await _hold(tester, find.text('1'));
      await _dragAlong(
        tester,
        drag,
        _steps(tester.getCenter(find.text('1')), const Offset(600, 50), 10),
      );
      await drag.up();
      await tester.pumpAndSettle();

      expect(board.moves, isEmpty);
      expect(tester.getTopLeft(find.text('1')), const Offset(0, _extent));
    });
  });

  group('layout', () {
    testWidgets('fits a dragged item to the slots of its new list', (
      tester,
    ) async {
      final board = _Board(
        {
          'a': [0, 1],
          'b': [10, 11],
        },
        widths: {'a': 500, 'b': 300},
      );
      await tester.pumpWidget(board.build());

      final drag = await _hold(tester, find.text('0'));
      expect(tester.getSize(find.byType(_Item).first).width, 500);
      final pointer = tester.getCenter(find.text('11'));
      await _dragAlong(
        tester,
        drag,
        _steps(tester.getCenter(find.text('0')), pointer, 10),
      );
      await tester.pump();

      expect(board.moves.single.$2, (list: 'b', index: 1));
      // As wide as the other list's slots, and still under the pointer.
      final held = find.ancestor(
        of: find.text('0'),
        matching: find.byType(_Item),
      );
      expect(tester.getSize(held).width, 300);
      expect(tester.getRect(held).contains(pointer), isTrue);
      await drag.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('0')), const Offset(500, _extent));
    });

    testWidgets('drags an item from a list into a grid', (tester) async {
      final board = _Board(
        {
          'a': [0, 1],
          'g': [10, 11, 12, 13],
        },
        grids: {'g'},
      );
      await tester.pumpWidget(board.build());

      final drag = await _hold(tester, find.text('1'));
      await _dragAlong(
        tester,
        drag,
        _steps(
          tester.getCenter(find.text('1')),
          tester.getCenter(find.text('13')),
          10,
        ),
      );
      await drag.up();
      await tester.pumpAndSettle();

      // It goes in over item 12, then takes item 13's place.
      expect(board.moves.single, (
        (list: 'a', index: 1),
        (list: 'g', index: 2),
      ));
      expect(board.columns['g'], [10, 11, 12, 1, 13]);
      expect(tester.getTopLeft(find.text('1')), const Offset(600, _extent));
      expect(tester.takeException(), isNull);
    });
  });
}

/// A board of lists side by side in a group, each with a list of ids.
class _Board {
  _Board(
    Map<String, List<int>> columns, {
    this.widths = const {},
    this.grids = const {},
    this.paddings = const {},
    this.withoutGroupId = const {},
    this.canMove,
  }) : columns = {
         for (final MapEntry(:key, :value) in columns.entries) key: [...value],
       };

  final Map<String, List<int>> columns;

  /// The widths of the columns that don't share the rest of the screen.
  final Map<String, double> widths;

  /// The columns that are grids of two columns.
  final Set<String> grids;
  final Map<String, EdgeInsets> paddings;
  final Set<String> withoutGroupId;
  final ItemMovePredicate? canMove;

  final moves = <(ItemPlace, ItemPlace)>[];

  /// The drag callbacks each column got: its id, the event and the index.
  final events = <(String, String, int)>[];

  /// How many times each item's state was created.
  final inits = <int, int>{};

  Widget build() => MaterialApp(home: Scaffold(body: _group()));

  Widget _group() => AnimatedReorderableGroup(
    onMove: (from, to) {
      moves.add((from, to));
      final id = columns[from.list]!.removeAt(from.index);
      columns[to.list]!.insert(to.index, id);
    },
    canMove: canMove,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final id in columns.keys)
          switch (widths[id]) {
            final width? => SizedBox(width: width, child: _column(id)),
            null => Expanded(child: _column(id)),
          },
      ],
    ),
  );

  Widget _column(String id) {
    final items = columns[id]!;
    final reorder = ReorderOptions(
      groupId: withoutGroupId.contains(id) ? null : id,
      onReorder: (permutations) => permutations.apply(items),
      callbacks: ItemDragCallbacks(
        onStart: (_, index) => events.add((id, 'start', index)),
        onUpdate: (_, index) => events.add((id, 'update', index)),
        onEnd: (_, index) => events.add((id, 'end', index)),
      ),
    );
    Widget item(BuildContext context, int index) => _Item(
      id: items[index],
      onInit: () => inits.update(items[index], (n) => n + 1, ifAbsent: () => 1),
    );
    if (grids.contains(id)) {
      return AnimatedReorderable.grid(
        key: ValueKey(id),
        keyGetter: (index) => ValueKey(items[index]),
        reorder: reorder,
        gridView: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: _extent,
          ),
          padding: paddings[id] ?? EdgeInsets.zero,
          itemCount: items.length,
          itemBuilder: item,
        ),
      );
    }
    return AnimatedReorderable.list(
      key: ValueKey(id),
      keyGetter: (index) => ValueKey(items[index]),
      reorder: reorder,
      listView: ListView.builder(
        padding: paddings[id] ?? EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: item,
      ),
    );
  }
}

class _Item extends StatefulWidget {
  const _Item({required this.id, required this.onInit});

  final int id;
  final VoidCallback onInit;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: _extent, child: Text('${widget.id}'));
}

/// Holds the item at [finder] until a drag of it starts.
Future<TestGesture> _hold(WidgetTester tester, Finder finder) async {
  final drag = await tester.startGesture(tester.getCenter(finder));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  return drag;
}

/// Moves [drag] through [steps], a frame each.
Future<void> _dragAlong(
  WidgetTester tester,
  TestGesture drag,
  List<Offset> steps,
) async {
  for (final step in steps) {
    await drag.moveTo(step);
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// [count] points from [from] to [to], [to] included.
List<Offset> _steps(Offset from, Offset to, int count) => [
  for (var i = 1; i <= count; i++) Offset.lerp(from, to, i / count)!,
];

Matcher _closeTo(Offset expected, double epsilon) => predicate<Offset>(
  (actual) => (actual - expected).distance <= epsilon,
  'within $epsilon of $expected',
);
