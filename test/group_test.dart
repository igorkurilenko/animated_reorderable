import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _extent = 100.0;
const _second = Duration(seconds: 1);

void main() {
  _boardTests();
  _flightTests();
  _clipTests();
  _screenReaderTests();

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

    testWidgets('moves the items of a list scrolled to its end down into '
        'the place of an item that leaves', (tester) async {
      final board = _Board({
        'a': [for (var id = 0; id < 10; id++) id],
        'b': [10],
      });
      await tester.pumpWidget(board.build());
      final a = tester.state<ScrollableState>(find.byType(Scrollable).first);
      a.position.jumpTo(a.position.maxScrollExtent);
      await tester.pumpAndSettle();
      double top(int id) => tester.getTopLeft(find.text('$id')).dy;
      final before = [top(4)];
      final after = [top(6)];

      // Across, over its own slot, then past the end of the other list.
      final drag = await _hold(tester, find.text('5'));
      final from = tester.getCenter(find.text('5'));
      for (final step in _steps(from, Offset(600, from.dy), 20)) {
        await drag.moveTo(step);
        await tester.pump(const Duration(milliseconds: 16));
        before.add(top(4));
        after.add(top(6));
      }
      await drag.up();
      while (tester.binding.hasScheduledFrame) {
        await tester.pump(const Duration(milliseconds: 16));
        before.add(top(4));
        after.add(top(6));
      }

      // The list shrinks under its offset, which comes back by an item.
      expect(board.moves, [((list: 'a', index: 5), (list: 'b', index: 1))]);
      expect(after, everyElement(moreOrLessEquals(after.first)));
      expect([
        for (var i = 1; i < before.length; i++) before[i] - before[i - 1],
      ], everyElement(inInclusiveRange(0, 20)));
      expect(before.last, before.first + _extent);
    });

    testWidgets('lets the app build its lists again as an item moves', (
      tester,
    ) async {
      final columns = {
        'a': [0, 1, 2],
        'b': [10],
      };
      Widget column(String id) {
        final items = columns[id]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$id has ${items.length}'),
            Expanded(
              child: AnimatedReorderable.list(
                keyGetter: (index) => ValueKey(items[index]),
                reorder: ReorderOptions(
                  groupId: id,
                  onReorder: (permutations) => permutations.apply(items),
                ),
                listView: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      SizedBox(height: _extent, child: Text('${items[index]}')),
                ),
              ),
            ),
          ],
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => AnimatedReorderableGroup(
                // The app counts the items of each list again.
                onMove: (from, to) => setState(() {
                  final id = columns[from.list]!.removeAt(from.index);
                  columns[to.list]!.insert(to.index, id);
                }),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: column('a')),
                    Expanded(child: column('b')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final drag = await _hold(tester, find.text('1'));
      final from = tester.getCenter(find.text('1'));
      final to = tester.getCenter(find.text('10'));
      for (final step in _steps(from, to, 20)) {
        await drag.moveTo(step);
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getCenter(find.text('1')), _closeTo(step, 1));
      }
      expect(find.text('a has 2'), findsOneWidget);
      expect(find.text('b has 2'), findsOneWidget);

      await drag.up();
      await tester.pumpAndSettle();

      expect(columns, {
        'a': [0, 2],
        'b': [1, 10],
      });
      expect(tester.getTopLeft(find.text('1')).dx, 400);
      expect(
        tester.getTopLeft(find.text('10')).dy,
        tester.getTopLeft(find.text('1')).dy + _extent,
      );
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

void _clipTests() => group('clips', () {
  // Each list under a header of its own.
  _Board headed() => _Board({
    'a': [for (var id = 0; id < 10; id++) id],
    'b': [10, 11],
  }, headerExtent: 50);

  testWidgets('clips an item let go to its list once the list scrolls it '
      'under its header', (tester) async {
    final board = headed();
    await tester.pumpWidget(board.build());
    final header = tester.getRect(find.byKey(const ValueKey('header a')));
    final list = find.byKey(const ValueKey('a'));

    // Item 10 across into the first slot of list a, let go there.
    final drag = await _hold(tester, find.text('10'));
    await _dragAlong(
      tester,
      drag,
      _steps(
        tester.getCenter(find.text('10')),
        tester.getCenter(find.text('0')),
        20,
      ),
    );
    await drag.up();
    await tester.pump();
    expect(board.columns['a']!.first, 10);

    // The list scrolls at once, while the item lands in the group's layer.
    tester
        .state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)),
        )
        .position
        .jumpTo(30);
    await tester.pump();
    expect(find.descendant(of: list, matching: find.text('10')), findsNothing);
    expect(tester.getTopLeft(find.text('10')).dy, lessThan(header.bottom));

    // It goes under the header with the list's other items, where it can't
    // be held either.
    expect(await _colorsIn(tester, header), {_headerColor});
    final hits = tester.hitTestOnBinding(Offset(100, header.bottom - 10));
    expect(
      hits.path.map((x) => x.target),
      isNot(contains(tester.renderObject(find.text('10')))),
    );

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('10')), Offset(0, header.bottom - 30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an item let go partly out of its list as it flies in', (
    tester,
  ) async {
    await tester.pumpWidget(headed().build());
    final header = tester.getRect(find.byKey(const ValueKey('header a')));

    // Item 10 across to the top of list a, partly over its header.
    final drag = await _hold(tester, find.text('10'));
    await _dragAlong(
      tester,
      drag,
      _steps(
        tester.getCenter(find.text('10')),
        Offset(200, header.bottom + 10),
        20,
      ),
    );
    expect(tester.getTopLeft(find.text('10')).dy, lessThan(header.bottom));
    await drag.up();
    await tester.pump();

    // It flies into its slot from where it was let go, over the header.
    expect(await _colorsIn(tester, header), isNot({_headerColor}));
    await tester.pumpAndSettle();
    expect(await _colorsIn(tester, header), {_headerColor});
  });

  testWidgets('shows an item let go as its list scrolls under it at its '
      'edge', (tester) async {
    await tester.pumpWidget(headed().build());
    final header = tester.getRect(find.byKey(const ValueKey('header a')));
    final a = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('a')),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    a.jumpTo(300);
    await tester.pump();

    // Item 10 across to the top edge of list a, partly over its header,
    // held there as the list scrolls back under it.
    final drag = await _hold(tester, find.text('10'));
    await _dragAlong(
      tester,
      drag,
      _steps(
        tester.getCenter(find.text('10')),
        Offset(200, header.bottom + 10),
        20,
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(a.pixels, inExclusiveRange(0, 300));
    await drag.up();
    await tester.pump();

    // The list stops as the item is let go, so it flies into its slot from
    // there, over the header, as it would from a list that stood still.
    expect(await _colorsIn(tester, header), isNot({_headerColor}));
    await tester.pumpAndSettle();
    expect(await _colorsIn(tester, header), {_headerColor});
    expect(tester.takeException(), isNull);
  });

  testWidgets('lets an item held again as it lands go over the header', (
    tester,
  ) async {
    await tester.pumpWidget(headed().build());
    final header = tester.getRect(find.byKey(const ValueKey('header a')));

    // Item 10 into the first slot of list a, which scrolls it as it lands.
    final drag = await _hold(tester, find.text('10'));
    await _dragAlong(
      tester,
      drag,
      _steps(
        tester.getCenter(find.text('10')),
        tester.getCenter(find.text('0')),
        20,
      ),
    );
    await drag.up();
    await tester.pump();
    tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('a')),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .jumpTo(30);
    await tester.pump();
    expect(await _colorsIn(tester, header), {_headerColor});

    // Held again, it goes with the pointer partly over the header.
    final grip = tester.getCenter(find.text('10'));
    final again = await tester.startGesture(grip);
    await _dragAlong(tester, again, [
      ..._steps(grip, grip + const Offset(40, 0), 5),
      ..._steps(grip + const Offset(40, 0), Offset(200, header.bottom + 5), 5),
    ]);
    expect(await _colorsIn(tester, header), isNot({_headerColor}));
    await again.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets("doesn't clip an item to a list that doesn't clip its items", (
    tester,
  ) async {
    await tester.pumpWidget(
      _Board(
        {
          'a': [for (var id = 0; id < 10; id++) id],
          'b': [10, 11],
        },
        headerExtent: 50,
        clipBehavior: Clip.none,
      ).build(),
    );
    final header = tester.getRect(find.byKey(const ValueKey('header a')));

    // Item 10 into the first slot of list a, which scrolls it as it lands.
    final drag = await _hold(tester, find.text('10'));
    await _dragAlong(
      tester,
      drag,
      _steps(
        tester.getCenter(find.text('10')),
        tester.getCenter(find.text('0')),
        20,
      ),
    );
    await drag.up();
    await tester.pump();
    tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('a')),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .jumpTo(30);
    await tester.pump();

    // Its label shows over the header, as the list's own items do.
    final label = tester.getTopLeft(find.text('10')) & const Size(28, 14);
    expect(
      await _colorsIn(tester, label.intersect(header)),
      isNot({_headerColor}),
    );
    await tester.pumpAndSettle();
    expect(
      await _colorsIn(tester, label.intersect(header)),
      isNot({_headerColor}),
    );
  });

  testWidgets('keeps an item let go out of its list until its list really '
      'scrolls', (tester) async {
    await tester.pumpWidget(headed().build());
    final header = tester.getRect(find.byKey(const ValueKey('header a')));

    // Item 10 across to the top of list a, partly over its header.
    final drag = await _hold(tester, find.text('10'));
    await _dragAlong(
      tester,
      drag,
      _steps(
        tester.getCenter(find.text('10')),
        Offset(200, header.bottom + 10),
        20,
      ),
    );
    await drag.up();
    await tester.pump();

    // The list tells its listeners it scrolled, though it didn't move.
    tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('a')),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        // ignore: invalid_use_of_protected_member
        .notifyListeners();
    await tester.pump();

    expect(await _colorsIn(tester, header), isNot({_headerColor}));
    await tester.pumpAndSettle();
  });

  testWidgets('clips an item to where its list is as a board around the '
      'group moves the list', (tester) async {
    final board = _Board(
      {
        'a': [0, 1],
        'b': [for (var id = 10; id < 20; id++) id],
        'c': [20, 21],
      },
      columnWidth: 300,
      headerExtent: 50,
      // Nothing builds the item again on its way, as a flight's end does.
      flight: FlightOptions.none,
    );
    await tester.pumpWidget(board.build());
    final header = tester.getRect(find.byKey(const ValueKey('header b')));
    board.boardScroll.jumpTo(100);
    await tester.pump();

    // Item 20 into the first slot of list b, which spans 200 to 500 now.
    final drag = await _hold(tester, find.text('20'));
    await _dragAlong(
      tester,
      drag,
      _steps(
        tester.getCenter(find.text('20')),
        tester.getCenter(find.text('10')),
        20,
      ),
    );
    await drag.up();
    await tester.pump();

    // List b scrolls it as it lands, then the board moves the list to 300.
    tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('b')),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .jumpTo(30);
    await tester.pump();
    board.boardScroll.jumpTo(0);
    await tester.pump();
    // Halfway to its slot's new place, it spans about 250 to 550.
    await tester.pump();
    await tester.pump(const MotionOptions().duration ~/ 2);
    expect(tester.getRect(find.text('20')).left, closeTo(250, 10));

    // It shows, and can be held, where it is in the list's new place.
    final hits = tester.hitTestOnBinding(Offset(520, header.bottom + 20));
    expect(
      hits.path.map((x) => x.target),
      contains(tester.renderObject(find.text('20'))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
});

void _screenReaderTests() => group('screen readers', () {
  String label(Object list) => 'Move to $list';

  testWidgets('moves an item to another list as a screen reader does', (
    tester,
  ) async {
    final board = _Board({
      'a': [0, 1, 2],
      'b': [10, 11],
    }, moveToListLabel: label);
    await tester.pumpWidget(board.build());
    expect(_moves(tester, 1), contains('Move to b'));
    expect(_moves(tester, 1), isNot(contains('Move to a')));

    _move(tester, 1, 'Move to b');
    final path = <Offset>[];
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      path.add(tester.getTopLeft(find.text('1')));
    }
    await tester.pumpAndSettle();

    expect(board.moves, [((list: 'a', index: 1), (list: 'b', index: 1))]);
    expect(board.columns, {
      'a': [0, 2],
      'b': [10, 1, 11],
    });
    // It goes over to its new slot, without a jump, and keeps its state.
    expect(path.first, _closeTo(const Offset(0, _extent), 1));
    expect(path.last, _closeTo(const Offset(400, _extent), 1));
    for (var i = 1; i < path.length; i++) {
      expect((path[i] - path[i - 1]).distance, lessThan(60));
    }
    expect(board.inits[1], 1);
    expect(_moves(tester, 1), contains('Move to a'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('moves an item to the end of a shorter list', (tester) async {
    final board = _Board({
      'a': [0, 1, 2],
      'b': [10],
    }, moveToListLabel: label);
    await tester.pumpWidget(board.build());

    _move(tester, 2, 'Move to b');
    await tester.pumpAndSettle();

    expect(board.moves, [((list: 'a', index: 2), (list: 'b', index: 1))]);
    expect(board.columns['b'], [10, 2]);
    expect(tester.getTopLeft(find.text('2')), const Offset(400, _extent));
  });

  testWidgets('offers no moves to other lists without their labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Board({
        'a': [0, 1],
        'b': [10],
      }).build(),
    );

    expect(_moves(tester, 1), isNotEmpty);
    expect(_moves(tester, 1), isNot(contains('Move to b')));
  });

  testWidgets("offers no move to a list the app doesn't let an item go to", (
    tester,
  ) async {
    await tester.pumpWidget(
      _Board(
        {
          'a': [0, 1],
          'b': [10],
          'c': [20],
        },
        canMove: (from, to) => to.list != 'b',
        moveToListLabel: label,
      ).build(),
    );

    expect(_moves(tester, 1), contains('Move to c'));
    expect(_moves(tester, 1), isNot(contains('Move to b')));
  });

  testWidgets("flies an item to the other list's look as a screen reader "
      'moves it', (tester) async {
    final board = _Board(
      {
        'a': [0, 1, 2],
        'b': [10, 11],
      },
      thumbs: {'b'},
      moveToListLabel: label,
    );
    await tester.pumpWidget(board.build());

    _move(tester, 1, 'Move to b');
    var flew = false;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      flew |= find.byType(RawImage).evaluate().isNotEmpty;
    }
    await tester.pumpAndSettle();

    expect(flew, isTrue);
    expect(find.byType(RawImage), findsNothing);
    expect(tester.getTopLeft(find.text('thumb 1')), const Offset(400, 50));
  });

  testWidgets('keeps an item in its list when the app refuses its move as '
      'it happens', (tester) async {
    var allow = true;
    final board = _Board(
      {
        'a': [0, 1, 2],
        'b': [10],
      },
      canMove: (from, to) => allow,
      moveToListLabel: label,
    );
    await tester.pumpWidget(board.build());

    _move(tester, 1, 'Move to b');
    allow = false;
    await tester.pumpAndSettle();

    expect(board.moves, isEmpty);
    expect(board.columns['a'], [0, 1, 2]);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('a')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(tester.getTopLeft(find.text('1')), const Offset(0, _extent));
    expect(tester.takeException(), isNull);
  });

  testWidgets('lists the moves in the order of the board', (tester) async {
    // Labels no other test has, which Flutter numbers here first.
    String ordered(Object list) => 'Order: $list';
    await tester.pumpWidget(
      _Board({
        'a': [0, 1, 2],
        'b': [10, 11, 12],
        'c': [20, 21, 22],
      }, moveToListLabel: ordered).build(),
    );

    expect(_moves(tester, 0), [
      'Move down',
      'Move to the end',
      'Order: b',
      'Order: c',
    ]);
    expect(_moves(tester, 11), [
      'Move to the start',
      'Move up',
      'Move down',
      'Move to the end',
      'Order: a',
      'Order: c',
    ]);
    expect(_moves(tester, 22), [
      'Move to the start',
      'Move up',
      'Order: a',
      'Order: b',
    ]);
  });

  testWidgets("takes the screen reader's focus to an item where it lands", (
    tester,
  ) async {
    final focused = _focusedNodes(tester);
    final board = _Board({
      'a': [0, 1, 2],
      'b': [10, 11],
    }, moveToListLabel: label);
    await tester.pumpWidget(board.build());

    _move(tester, 1, 'Move to b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // Not while it's on its way.
    expect(focused, isEmpty);
    await tester.pumpAndSettle();

    expect(board.columns['b'], [10, 1, 11]);
    expect(focused, [tester.getSemantics(find.text('1')).id]);
  });

  testWidgets("gives the screen reader's focus back to an item the app "
      "doesn't let move", (tester) async {
    final focused = _focusedNodes(tester);
    var allow = true;
    await tester.pumpWidget(
      _Board(
        {
          'a': [0, 1, 2],
          'b': [10],
        },
        canMove: (from, to) => allow,
        moveToListLabel: label,
      ).build(),
    );

    _move(tester, 1, 'Move to b');
    allow = false;
    await tester.pumpAndSettle();

    expect(focused, [tester.getSemantics(find.text('1')).id]);
  });
});

/// The ids of the nodes the app moves a screen reader's focus to from now
/// on, in order.
List<int> _focusedNodes(WidgetTester tester) {
  final focused = <int>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      if (message case {'type': 'focus', 'nodeId': final int id}) {
        focused.add(id);
      }
      return null;
    },
  );
  addTearDown(
    () => messenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      null,
    ),
  );
  return focused;
}

void _flightTests() => group('flights', () {
  // List a shows cards, list b thumbnails of half their height.
  _Board designs({FlightOptions flight = const FlightOptions()}) => _Board(
    {
      'a': [0, 1, 2],
      'b': [10, 11],
    },
    thumbs: {'b'},
    flight: flight,
  );

  Future<TestGesture> dragInto(
    WidgetTester tester,
    Finder item,
    Finder over,
  ) async {
    final drag = await _hold(tester, item);
    await _dragAlong(
      tester,
      drag,
      _steps(tester.getCenter(item), tester.getCenter(over), 10),
    );
    return drag;
  }

  Finder thumbOf(int id) =>
      find.ancestor(of: find.text('thumb $id'), matching: find.byType(_Thumb));

  testWidgets("flies an item from its old list's look to its new one's", (
    tester,
  ) async {
    // A flight long enough to catch the shuttle on its way.
    final board = designs(
      flight: const FlightOptions(duration: Duration(milliseconds: 300)),
    );
    await tester.pumpWidget(board.build());

    // The point of the card the pointer holds.
    final card = tester.getRect(find.byType(_Item).at(1));
    final held = tester.getCenter(find.text('1'));
    final grip = Offset(
      (held.dx - card.left) / card.width,
      (held.dy - card.top) / card.height,
    );
    final pointer = tester.getCenter(find.text('thumb 11'));
    final drag = await dragInto(tester, find.text('1'), find.text('thumb 11'));
    expect(board.moves.single.$2.list, 'b');
    await tester.pump(const Duration(milliseconds: 100));

    // The card shows as it last showed, an image, as the thumbnail fades
    // in: the old list builds nothing for it again.
    expect(find.byType(RawImage), findsOneWidget);
    expect(find.text('thumb 1'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    final shuttle = tester.getRect(find.byType(RawImage));
    // On its way from the card's height to the thumbnail's, which the
    // drag's decoration makes 5% bigger.
    expect(shuttle.height, inExclusiveRange(0.55 * _extent, _extent));
    // It holds the same point of the shuttle as of the card.
    expect(
      shuttle.topLeft +
          Offset(grip.dx * shuttle.width, grip.dy * shuttle.height),
      _closeTo(pointer, 1),
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RawImage), findsNothing);
    expect(tester.getSize(thumbOf(1)).height, _extent / 2);
    expect(tester.getRect(thumbOf(1)).contains(pointer), isTrue);

    await drag.up();
    await tester.pumpAndSettle();
    expect(board.columns['b'], [10, 1, 11]);
    expect(tester.getTopLeft(find.text('thumb 1')), const Offset(400, 50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('moves the items of the new list to their slots as the gap '
      'there fits the list\'s look', (tester) async {
    final board = _Board(
      {
        'a': [0, 1, 2],
        'b': [10, 11, 12, 13],
      },
      thumbs: {'b'},
      rebuildsOnMove: true,
    );
    await tester.pumpWidget(board.build());
    final tops = {
      for (final id in [11, 12, 13]) id: <double>[],
    };
    void record() {
      for (final MapEntry(key: id, value: frames) in tops.entries) {
        frames.add(tester.getTopLeft(find.text('thumb $id')).dy);
      }
    }

    // Across into list b, straight over thumbnail 11, whose place it takes.
    final drag = await _hold(tester, find.text('0'));
    final from = tester.getCenter(find.text('0'));
    final to = tester.getCenter(find.text('thumb 11'));
    for (final step in _steps(from, to, 10)) {
      await drag.moveTo(step);
      await tester.pump(const Duration(milliseconds: 16));
      record();
    }
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      record();
    }

    // The gap is as big as the card until the item lays out as a
    // thumbnail. The thumbnails after it head for their slots as the gap
    // shrinks, rather than past them, and get there without a jump.
    expect(board.moves, [((list: 'a', index: 0), (list: 'b', index: 1))]);
    for (final MapEntry(key: id, value: frames) in tops.entries) {
      final slot = (id - 10 + 1) * _extent / 2;
      expect(frames, everyElement(lessThanOrEqualTo(slot + 1)), reason: '$id');
      expect(
        [for (var i = 1; i < frames.length; i++) frames[i] - frames[i - 1]],
        everyElement(inInclusiveRange(-1, 10)),
        reason: '$id',
      );
      expect(frames.last, slot, reason: '$id');
    }
    await drag.up();
    await tester.pumpAndSettle();
  });

  testWidgets('turns a flight back from where it is', (tester) async {
    final board = designs();
    await tester.pumpWidget(board.build());

    final drag = await dragInto(tester, find.text('1'), find.text('thumb 11'));
    await tester.pump(const Duration(milliseconds: 100));
    // Back over its old list, mid-flight.
    await _dragAlong(
      tester,
      drag,
      _steps(tester.getCenter(find.text('thumb 1')), const Offset(200, 150), 5),
    );

    expect(board.moves.map((x) => x.$2.list), ['b', 'a']);
    // It flies from the shuttle as it showed, an image, as the card fades
    // in, for the whole flight from the turn on.
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(RawImage), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    await drag.up();
    await tester.pumpAndSettle();

    expect(board.columns, {
      'a': [0, 1, 2],
      'b': [10, 11],
    });
    expect(tester.getTopLeft(find.text('1')), const Offset(0, _extent));
    expect(find.byType(RawImage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lands an item let go mid-flight once it has flown', (
    tester,
  ) async {
    // A flight that takes longer than the way back to its slot.
    final board = designs(flight: const FlightOptions(duration: _second));
    await tester.pumpWidget(board.build());

    final drag = await dragInto(tester, find.text('1'), find.text('thumb 11'));
    await drag.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    // Still in the group's layer, flying.
    expect(find.byType(RawImage), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(RawImage), findsNothing);
    expect(tester.getTopLeft(find.text('thumb 1')), const Offset(400, 50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps flying an item let go as its new list scrolls', (
    tester,
  ) async {
    final board = _Board(
      {
        'a': [0, 1, 2],
        'b': [for (var id = 10; id < 30; id++) id],
      },
      thumbs: {'b'},
      // A flight that outlasts the item's way back to its slot.
      flight: const FlightOptions(duration: Duration(seconds: 3)),
      decoration: ItemDecoration.none,
    );
    await tester.pumpWidget(board.build());
    final drag = await dragInto(tester, find.text('0'), thumbOf(10));
    await drag.up();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byType(RawImage), findsOneWidget);

    // The list scrolls, which builds the items that come into sight.
    tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('b')),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .jumpTo(60);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(RawImage), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(RawImage), findsNothing);
  });

  testWidgets('shows the new look at once with no flight', (tester) async {
    final board = designs(flight: FlightOptions.none);
    await tester.pumpWidget(board.build());

    final drag = await dragInto(tester, find.text('1'), find.text('thumb 11'));
    await tester.pump();

    expect(find.byType(RawImage), findsNothing);
    expect(tester.getSize(thumbOf(1)).height, _extent / 2);
    await drag.up();
    await tester.pumpAndSettle();
  });

  testWidgets("builds the shuttle with the group's builder", (tester) async {
    final animations = <double>[];
    final board = designs(
      // As a hero shuttle shows by default: the new look alone.
      flight: FlightOptions(
        shuttleBuilder: (context, animation, from, to) {
          animations.add(animation.value);
          return to;
        },
      ),
    );
    await tester.pumpWidget(board.build());

    final drag = await dragInto(tester, find.text('1'), find.text('thumb 11'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(animations, isNotEmpty);
    expect(find.byType(RawImage), findsNothing);
    // Fitted to the shuttle, which is on its way from the card's height.
    expect(
      tester.getRect(thumbOf(1)).height,
      inExclusiveRange(_extent / 2, _extent),
    );
    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.getSize(thumbOf(1)).height, _extent / 2);
  });
});

void _boardTests() => group('board', () {
  for (final inside in [false, true]) {
    final around = inside ? 'the group' : 'its lists';

    testWidgets('keeps a dragged item under the pointer as a board around '
        '$around scrolls', (tester) async {
      final board = _Board(
        {
          'a': [0, 1],
          'b': [10, 11],
          'c': [20, 21],
        },
        columnWidth: 300,
        groupInsideTheBoard: inside,
      );
      await tester.pumpWidget(board.build());

      final drag = await _hold(tester, find.text('1'));
      final held = tester.getCenter(find.text('1')) + const Offset(40, 0);
      await drag.moveTo(held);
      await tester.pump();

      board.boardScroll.jumpTo(100);
      await tester.pump();

      expect(tester.getCenter(find.text('1')), _closeTo(held, 1));
      await drag.up();
      await tester.pumpAndSettle();
    });

    testWidgets('lands an item let go on its slot as a board around '
        '$around scrolls', (tester) async {
      final board = _Board(
        {
          'a': [0, 1],
          'b': [10, 11],
          'c': [20, 21],
        },
        columnWidth: 300,
        groupInsideTheBoard: inside,
      );
      await tester.pumpWidget(board.build());

      final drag = await _hold(tester, find.text('1'));
      await drag.moveBy(const Offset(40, 0));
      await tester.pump();
      await drag.up();
      final list = find.byKey(const ValueKey('a'));
      Offset relative() =>
          tester.getTopLeft(find.text('1')) - tester.getTopLeft(list);
      // A layer that moves with the board takes the item along at once.
      final path = [if (inside) relative()];
      board.boardScroll.jumpTo(100);

      // Its way back, relative to its list, which the board moved: it
      // heads for its slot there, rather than where the slot was.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        path.add(relative());
      }
      expect(path.last, _closeTo(const Offset(0, _extent), 0.5));
      for (var i = 1; i < path.length; i++) {
        expect((path[i] - path[i - 1]).distance, lessThan(20));
      }
    });

    testWidgets('scrolls a board around $around to its lists out of sight', (
      tester,
    ) async {
      final board = _Board(
        {
          'a': [0, 1],
          'b': [10, 11],
          'c': [20, 21],
        },
        // The last column is out of sight.
        columnWidth: 400,
        groupInsideTheBoard: inside,
      );
      await tester.pumpWidget(board.build());

      // Straight to the edge, over the middle column, and still there.
      final drag = await _hold(tester, find.text('0'));
      const edge = Offset(795, 50);
      await _dragAlong(tester, drag, [edge]);
      // Held still at the edge, it scrolls the board, and goes into the
      // column the board brings under it.
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(board.boardScroll.offset, 400);
      expect(tester.getCenter(find.text('0')), _closeTo(edge, 1));
      await drag.up();
      await tester.pumpAndSettle();

      expect(board.moves.map((x) => x.$2.list), ['b', 'c']);
      expect(board.columns['c'], [0, 20, 21]);
      // It lands in the last column, which shows at the screen's edge.
      expect(tester.getTopLeft(find.text('0')), const Offset(400, 0));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('leaves a board around a list with no group id as an item of '
      'it is held at the edge', (tester) async {
    final board = _Board(
      {
        'a': [0, 1],
        'b': [10, 11],
        'c': [20, 21],
      },
      // The last column is out of sight.
      columnWidth: 400,
      withoutGroupId: {'a'},
    );
    await tester.pumpWidget(board.build());

    final drag = await _hold(tester, find.text('0'));
    await _dragAlong(tester, drag, [const Offset(795, 50)]);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(board.boardScroll.offset, 0);
    await drag.up();
    await tester.pumpAndSettle();
    expect(board.moves, isEmpty);
    expect(tester.takeException(), isNull);
  });
});

/// A board of lists side by side in a group, each with a list of ids.
class _Board {
  _Board(
    Map<String, List<int>> columns, {
    this.widths = const {},
    this.grids = const {},
    this.paddings = const {},
    this.withoutGroupId = const {},
    this.canMove,
    this.columnWidth,
    this.groupInsideTheBoard = false,
    this.thumbs = const {},
    this.flight = const FlightOptions(),
    this.rebuildsOnMove = false,
    this.headerExtent = 0,
    this.decoration = const ItemDecoration(),
    this.clipBehavior = Clip.hardEdge,
    this.moveToListLabel,
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

  /// The width of each column of a board that scrolls sideways, or null
  /// for columns that share the screen.
  final double? columnWidth;

  /// Whether the board's view that scrolls sideways is around the group,
  /// rather than inside it, around the lists.
  final bool groupInsideTheBoard;
  final boardScroll = ScrollController();

  /// The columns that show their items as thumbnails, rather than cards.
  final Set<String> thumbs;
  final FlightOptions flight;

  /// Whether the app builds the board again as an item moves, as one that
  /// shows how many items each list has would.
  final bool rebuildsOnMove;
  StateSetter? _setState;

  /// The extent of a header of [_headerColor] above each list, if any.
  final double headerExtent;

  /// How the lists decorate their held items.
  final ItemDecoration decoration;

  /// How the lists clip their items.
  final Clip clipBehavior;

  /// The labels of the screen reader's moves to the lists, if any.
  final String Function(Object list)? moveToListLabel;

  final moves = <(ItemPlace, ItemPlace)>[];

  /// The drag callbacks each column got: its id, the event and the index.
  final events = <(String, String, int)>[];

  /// How many times each item's state was created.
  final inits = <int, int>{};

  Widget build() => MaterialApp(
    home: Scaffold(
      body: RepaintBoundary(
        key: _screen,
        child: StatefulBuilder(
          builder: (context, setState) {
            _setState = setState;
            return _board();
          },
        ),
      ),
    ),
  );

  Widget _board() {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final id in columns.keys)
          switch (widths[id] ?? columnWidth) {
            final width? => SizedBox(width: width, child: _column(id)),
            null => Expanded(child: _column(id)),
          },
      ],
    );
    if (columnWidth == null) return _group(row);
    Widget scroll(Widget child) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: boardScroll,
      child: child,
    );
    return groupInsideTheBoard ? scroll(_group(row)) : _group(scroll(row));
  }

  Widget _group(Widget child) => AnimatedReorderableGroup(
    onMove: (from, to) {
      moves.add((from, to));
      final id = columns[from.list]!.removeAt(from.index);
      columns[to.list]!.insert(to.index, id);
      if (rebuildsOnMove) _setState!(() {});
    },
    canMove: canMove,
    flight: flight,
    moveToListLabel: moveToListLabel,
    child: child,
  );

  Widget _column(String id) {
    final list = _list(id);
    if (headerExtent == 0) return list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          key: ValueKey('header $id'),
          color: _headerColor,
          child: SizedBox(height: headerExtent),
        ),
        Expanded(child: list),
      ],
    );
  }

  Widget _list(String id) {
    final items = columns[id]!;
    final reorder = ReorderOptions(
      groupId: withoutGroupId.contains(id) ? null : id,
      onReorder: (permutations) => permutations.apply(items),
      decoration: decoration,
      callbacks: ItemDragCallbacks(
        onStart: (_, index) => events.add((id, 'start', index)),
        onUpdate: (_, index) => events.add((id, 'update', index)),
        onEnd: (_, index) => events.add((id, 'end', index)),
      ),
    );
    Widget item(BuildContext context, int index) => thumbs.contains(id)
        ? _Thumb(id: items[index])
        : _Item(
            id: items[index],
            onInit: () =>
                inits.update(items[index], (n) => n + 1, ifAbsent: () => 1),
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
          clipBehavior: clipBehavior,
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
        clipBehavior: clipBehavior,
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

/// An item as a thumbnail, half a card's height.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.id});

  final int id;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: _extent / 2, child: Text('thumb $id'));
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

/// What a board paints on, which [_colorsIn] takes as an image.
const _screen = ValueKey('screen');

const _headerColor = Color(0xFF00FF00);

/// The colors of the pixels in [rect] on the screen, as last painted.
Future<Set<Color>> _colorsIn(WidgetTester tester, Rect rect) async {
  final screen = find.byKey(_screen);
  final topLeft = tester
      .renderObject<RenderBox>(screen)
      .globalToLocal(rect.topLeft);
  final (pixels, width) = (await tester.runAsync(() async {
    final image = await captureImage(screen.evaluate().single);
    final pixels = await image.toByteData();
    final width = image.width;
    image.dispose();
    return (pixels!, width);
  }))!;
  Color at(int x, int y) {
    final i = (y * width + x) * 4;
    return Color.fromARGB(
      pixels.getUint8(i + 3),
      pixels.getUint8(i),
      pixels.getUint8(i + 1),
      pixels.getUint8(i + 2),
    );
  }

  return {
    for (var y = topLeft.dy.ceil(); y < topLeft.dy + rect.height; y++)
      for (var x = topLeft.dx.ceil(); x < topLeft.dx + rect.width; x++)
        at(x, y),
  };
}

/// The labels of the moves a screen reader can make with the item [label]
/// shows.
List<String> _moves(WidgetTester tester, Object label) => [
  for (final id
      in tester
              .getSemantics(find.text('$label'))
              .getSemanticsData()
              .customSemanticsActionIds ??
          const <int>[])
    CustomSemanticsAction.getAction(id)!.label!,
];

/// Makes the move named [name] with the item [label] shows, as a screen
/// reader does.
void _move(WidgetTester tester, Object label, String name) {
  final node = tester.getSemantics(find.text('$label'));
  node.owner!.performAction(
    node.id,
    SemanticsAction.customAction,
    CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: name)),
  );
}
