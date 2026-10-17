import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _extent = 100.0;

/// The package's default fling spring.
const _defaultSpring = SpringDescription(mass: 1, stiffness: 500, damping: 75);

void main() {
  group('disposal', () {
    testWidgets('disposes animations once items stop moving', (tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());

      list.state.reorderItem(0, destIndex: 4);
      await tester.pumpAndSettle();
      list.insert(0, 5);
      await tester.pumpAndSettle();
      list.removeAt(0);
      await tester.pumpAndSettle();

      expect(_trackedTickers(tester), 0);
    });

    testWidgets('can be disposed while off-screen items are moving', (
      tester,
    ) async {
      final list = _TestList(50);
      await tester.pumpWidget(list.build());

      list.state.reorderItem(0, destIndex: 40);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      list.state.reorderItem(40, destIndex: 39);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('can be disposed while an inserted item is moving', (
      tester,
    ) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());

      list.insert(0, 5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      list.insert(0, 6);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposes the animations of held and interrupted items', (
      tester,
    ) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());

      list.insert(0, 5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      list.removeAt(0);
      await tester.pumpAndSettle();
      final drag = await _holdAndDrag(tester, find.text('0'), 11);
      await drag.up();
      await tester.pumpAndSettle();
      await tester.fling(find.text('2'), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();

      expect(list.items, [1, 0, 3, 4]);
      expect(_trackedTickers(tester), 0);
    });

    testWidgets('can be disposed while an item is dragged', (tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());

      final drag = await _holdAndDrag(tester, find.text('0'), 6);
      await tester.pumpWidget(const SizedBox());
      await drag.moveBy(const Offset(0, 20));
      await drag.up();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('can be disposed while a removed item fades out', (
      tester,
    ) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());

      list.removeAt(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());

      expect(tester.takeException(), isNull);
    });

    testWidgets('can be disposed while a swiped item flies out', (
      tester,
    ) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());

      await tester.fling(find.text('1'), const Offset(-400, 0), 2000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());

      expect(tester.takeException(), isNull);
    });

    testWidgets('disposes the animations of the default drag decoration', (
      tester,
    ) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());
      final curvedAnimations = _undisposed('CurvedAnimation');

      final drag = await tester.startGesture(tester.getCenter(find.text('0')));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      for (var i = 0; i < 10; i++) {
        await drag.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await drag.up();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());

      expect(curvedAnimations, isEmpty);
    });
  });

  group('configuration', () {
    testWidgets('builds items with the latest item builder', (tester) async {
      await tester.pumpWidget(_labels(const ['a', 'b']));
      await tester.pumpWidget(_labels(const ['A', 'B']));

      expect(find.text('A'), findsOneWidget);
      expect(find.text('a'), findsNothing);
    });

    testWidgets('keys new items with the latest key getter', (tester) async {
      final key = GlobalKey<AnimatedReorderableState>();
      await tester.pumpWidget(_labels(const ['b', 'c'], key: key));
      const labels = ['a', 'b', 'c'];
      await tester.pumpWidget(_labels(labels, key: key));

      key.currentState!.insertItem(0);
      await tester.pumpAndSettle();

      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('flings removed items with swipeToRemoveSpringDescription', (
      tester,
    ) async {
      Future<double> flungOffset(SpringDescription spring) async {
        final list = _TestList(5, swipeToRemoveSpringDescription: spring);
        await tester.pumpWidget(list.build());
        await tester.fling(find.text('1'), const Offset(-400, 0), 2000);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final offset = tester.getTopLeft(find.text('1')).dx;
        await tester.pumpAndSettle();
        return offset;
      }

      final stiff = await flungOffset(_defaultSpring);
      final soft = await flungOffset(
        const SpringDescription(mass: 1, stiffness: 10, damping: 10),
      );

      expect(soft, greaterThan(stiff + 50));
    });

    testWidgets(
      'springs swiped items back with swipeToRemoveSpringDescription',
      (tester) async {
        Future<double> springOffset(SpringDescription spring) async {
          final list = _TestList(5, swipeToRemoveSpringDescription: spring);
          await tester.pumpWidget(list.build());
          // Too short and too slow to remove the item.
          await tester.timedDrag(
            find.text('1'),
            const Offset(-300, 0),
            const Duration(seconds: 1),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          final offset = tester.getTopLeft(find.text('1')).dx;
          await tester.pumpAndSettle();
          expect(list.items, [0, 1, 2, 3, 4]);
          return offset;
        }

        final stiff = await springOffset(_defaultSpring);
        final soft = await springOffset(
          const SpringDescription(mass: 1, stiffness: 10, damping: 10),
        );

        expect(soft, lessThan(stiff - 50));
      },
    );

    testWidgets('calls the latest onReorder', (tester) async {
      final key = GlobalKey<AnimatedReorderableState>();
      final calls = <String>[];
      Widget build(String name) => _labels(
        const ['a', 'b', 'c'],
        key: key,
        onReorder: (_) => calls.add(name),
      );
      await tester.pumpWidget(build('first'));
      await tester.pumpWidget(build('second'));

      key.currentState!.reorderItem(0, destIndex: 1);
      await tester.pumpAndSettle();

      expect(calls, ['second']);
    });
  });

  group('latest configuration', () {
    testWidgets('swipes items in the latest direction', (tester) async {
      final list = _TestList(5, swipeToRemoveDirection: AxisDirection.left);
      await tester.pumpWidget(list.build());
      list.swipeToRemoveDirection = AxisDirection.right;
      await tester.pumpWidget(list.build());

      await tester.fling(find.text('1'), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();
      expect(list.items, [0, 1, 2, 3, 4]);

      await tester.fling(find.text('1'), const Offset(400, 0), 2000);
      await tester.pumpAndSettle();
      expect(list.items, [0, 2, 3, 4]);
    });

    testWidgets('drags only the latest draggable items', (tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());
      list.draggableGetter = (index) => index != 0;
      await tester.pumpWidget(list.build());

      final drag = await _holdAndDrag(tester, find.text('0'), 11);
      await drag.up();
      await tester.pumpAndSettle();

      expect(list.items, [0, 1, 2, 3, 4]);
    });

    testWidgets('decorates dragged items with the latest decorator', (
      tester,
    ) async {
      Widget build(String name) => MaterialApp(
        home: Scaffold(
          body: AnimatedReorderable.list(
            keyGetter: (index) => ValueKey(index),
            reorder: ReorderOptions(
              onReorder: (_) {},
              decoration: ItemDecoration(
                decorator: (child, index, animation) =>
                    KeyedSubtree(key: ValueKey(name), child: child),
              ),
            ),
            listView: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) =>
                  SizedBox(height: _extent, child: Text('$index')),
            ),
          ),
        ),
      );
      await tester.pumpWidget(build('first'));
      await tester.pumpWidget(build('second'));

      final drag = await _holdAndDrag(tester, find.text('0'), 2);

      expect(find.byKey(const ValueKey('second')), findsOneWidget);
      expect(find.byKey(const ValueKey('first')), findsNothing);
      await drag.up();
      await tester.pumpAndSettle();
    });

    testWidgets('reports to the latest callbacks', (tester) async {
      final first = <String>[];
      final second = <String>[];
      await tester.pumpWidget(_withCallbacks(first));
      await tester.pumpWidget(
        _withCallbacks(
          second,
          onSwipeToRemove: (index) => second.add('remove $index'),
        ),
      );

      final drag = await _holdAndDrag(tester, find.text('0'), 2);
      await drag.up();
      await tester.pumpAndSettle();
      await tester.fling(find.text('1'), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();

      expect(first, isEmpty);
      expect(second, containsAll(['drag end 0', 'swipe end 1', 'remove 1']));
    });
  });

  group('rendered items', () {
    testWidgets('tells which items are rendered', (tester) async {
      final list = _TestList(50);
      await tester.pumpWidget(list.build());

      expect(list.state.isItemRendered(0), isTrue);
      expect(list.state.isItemRendered(40), isFalse);
    });

    testWidgets('gives the build context of a rendered item', (tester) async {
      final list = _TestList(50);
      await tester.pumpWidget(list.build());

      final context = list.state.getRenderedItemBuildContext(2)!;

      expect(
        find.descendant(
          of: find.byElementPredicate((element) => element == context),
          matching: find.byType(_Item),
        ),
        findsOneWidget,
      );
      expect(
        context.findAncestorStateOfType<AnimatedReorderableState>(),
        list.state,
      );
      expect(tester.getTopLeft(find.text('2')).dy, 200);
      expect(list.state.getRenderedItemBuildContext(40), isNull);
    });
  });

  group('z-order', () {
    testWidgets('lifts a dragged item above the moving items', (tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());

      final drag = await _holdAndDrag(tester, find.text('0'), 11);

      expect(_paintOrder(tester).last, 0);
      await drag.up();
      await tester.pumpAndSettle();
    });

    testWidgets('shows a removed item under the moving items', (tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());

      list.removeAt(1);
      await tester.pump();

      expect(_paintOrder(tester).first, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('shows a removed item at its z-index', (tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());

      list.items.removeAt(1);
      list.state.removeItem(
        1,
        (context, animation) => list.buildItem(1),
        zIndex: 1,
      );
      await tester.pump();

      expect(_paintOrder(tester).last, 1);
      await tester.pumpAndSettle();
    });
  });

  group('builds', () {
    // Pins the count the package has today, so a change that builds
    // moving items more often shows up.
    testWidgets('builds moving items at most once a frame', (tester) async {
      var builds = 0;
      final items = [0, 1, 2, 3, 4];
      final key = GlobalKey<AnimatedReorderableState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedReorderable.list(
              key: key,
              keyGetter: (index) => ValueKey(items[index]),
              reorder: ReorderOptions(
                onReorder: (permutations) => permutations.apply(items),
              ),
              listView: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  builds++;
                  return SizedBox(
                    height: _extent,
                    child: Text('${items[index]}'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      builds = 0;

      key.currentState!.reorderItem(0, destIndex: 3);
      var frames = 0;
      await tester.pump();
      while (tester.binding.hasScheduledFrame) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }

      expect(builds, lessThanOrEqualTo(138));
      expect(frames, 33);
    });
  });

  group('scroll controller', () {
    testWidgets('wraps a primary list view', (tester) async {
      await tester.pumpWidget(_scrollable(primary: true));

      expect(tester.takeException(), isNull);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('uses the primary scroll controller by default', (
      tester,
    ) async {
      await tester.pumpWidget(_scrollable());
      final primary = PrimaryScrollController.of(
        tester.element(find.byType(Scrollable)),
      );

      expect(primary.hasClients, isTrue);
      primary.jumpTo(10 * _extent);
      await tester.pump();
      expect(find.text('0'), findsNothing);
    });

    testWidgets('shares the primary scroll controller with another list', (
      tester,
    ) async {
      final left = _TestList(10);
      final right = _TestList(10);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Expanded(child: left.buildList()),
                Expanded(child: right.buildList()),
              ],
            ),
          ),
        ),
      );

      left.state.reorderItem(0, destIndex: 2);
      await tester.pumpAndSettle();
      await tester.drag(find.text('3').last, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(left.items, [1, 2, 0, 3, 4, 5, 6, 7, 8, 9]);
      // Only the right list scrolled its first items away.
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('keeps the list view controller', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_scrollable(controller: controller));

      expect(controller.hasClients, isTrue);
      expect(
        PrimaryScrollController.of(tester.element(find.byType(Scrollable)))
            .hasClients,
        isFalse,
      );
    });
  });

  testWidgets('moves items off-screen along the list', (tester) async {
    final list = _TestList(50);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(left: 300),
            child: list.buildList(),
          ),
        ),
      ),
    );

    list.state.reorderItem(0, destIndex: 40);
    final lefts = <double>[];
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
      final item = find.text('0');
      if (item.evaluate().isNotEmpty) lefts.add(tester.getTopLeft(item).dx);
    }

    expect(lefts, isNotEmpty);
    expect(lefts, everyElement(300));
  });

  testWidgets('moves removed items with the scroll after a clamp', (
    tester,
  ) async {
    final list = _TestList(10);
    await tester.pumpWidget(list.build());
    final position = _scrollPosition(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();

    // The list shrinks under its offset, which clamps it without notifying
    // the scroll controller's listeners.
    list.removeAt(9);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final top = tester.getTopLeft(find.text('9')).dy;
    position.jumpTo(position.pixels - 50);
    await tester.pump();

    expect(tester.getTopLeft(find.text('9')).dy - top, moreOrLessEquals(50));
  });

  testWidgets('keeps a fling going when the list rebuilds', (tester) async {
    final list = _TestList(60);
    await tester.pumpWidget(list.build());
    await tester.fling(find.text('3'), const Offset(0, -200), 2000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final pixels = _scrollPosition(tester).pixels;

    await tester.pumpWidget(list.build());
    await tester.pump(const Duration(milliseconds: 50));

    expect(_scrollPosition(tester).pixels, greaterThan(pixels));
  });

  group('resize', () {
    testWidgets('keeps the first visible item of a list in place', (
      tester,
    ) async {
      final list = _TestList(60);
      await tester.pumpWidget(list.build());
      _scrollPosition(tester).jumpTo(20 * _extent + 30);
      await tester.pump();

      _resize(tester, const Size(400, 600));
      await tester.pump();

      expect(_scrollPosition(tester).pixels, 20 * _extent + 30);
      expect(tester.getTopLeft(find.text('20')).dy, -30);
    });

    testWidgets('keeps the first visible item of a grid in place', (
      tester,
    ) async {
      final grid = _TestList(
        200,
        grid: true,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisExtent: _extent,
        ),
      );
      await tester.pumpWidget(grid.build());
      // Four columns, so item 80 starts row 20.
      _scrollPosition(tester).jumpTo(20 * _extent + 30);
      await tester.pump();

      // Two columns, so item 80 starts row 40.
      _resize(tester, const Size(400, 600));
      await tester.pump();

      expect(_scrollPosition(tester).pixels, 40 * _extent + 30);
      expect(tester.getTopLeft(find.text('80')).dy, -30);
    });

    testWidgets('scales the hidden part of a grid item that scales', (
      tester,
    ) async {
      // Three columns of squares, which scale with the width.
      final grid = _TestList(60, grid: true);
      await tester.pumpWidget(grid.build());
      const side = 800 / 3;
      _scrollPosition(tester).jumpTo(5 * side + 100);
      await tester.pump();

      _resize(tester, const Size(400, 600));
      await tester.pump();

      expect(tester.getTopLeft(find.text('15')).dy, moreOrLessEquals(-50));
    });

    testWidgets('lays out moving items as the list would', (tester) async {
      final items = List.generate(10, (i) => i);
      final key = GlobalKey<AnimatedReorderableState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedReorderable.list(
              key: key,
              keyGetter: (index) => ValueKey(items[index]),
              reorder: ReorderOptions(
                onReorder: (permutations) => permutations.apply(items),
              ),
              listView: ListView.builder(
                itemCount: items.length,
                // Taller when narrow, as wrapping text would be.
                itemBuilder: (context, index) => LayoutBuilder(
                  builder: (context, constraints) => SizedBox(
                    height: constraints.maxWidth < 600 ? 75 : 50,
                    child: Text('${items[index]}'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Rect rectOf(int id) => tester.getRect(
        find.ancestor(of: find.text('$id'), matching: find.byType(SizedBox)),
      );

      key.currentState!.reorderItem(0, destIndex: 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      _resize(tester, const Size(400, 600));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(rectOf(0).size, const Size(400, 75));
      expect(rectOf(5).top, 5 * 75);
      await tester.pumpAndSettle();
      expect(rectOf(0), const Rect.fromLTWH(0, 3 * 75, 400, 75));
    });

    testWidgets('fits removed items to the list in place', (tester) async {
      final list = _TestList(10);
      await tester.pumpWidget(list.build());

      list.removeAt(4);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      _resize(tester, const Size(400, 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        tester.getRect(_itemWithId(4)),
        const Rect.fromLTWH(0, 4 * _extent, 400, _extent),
      );
    });

    testWidgets('keeps a dragged item under the pointer', (tester) async {
      // Three columns of squares, which scale with the width.
      final grid = _TestList(9, grid: true);
      await tester.pumpWidget(grid.build());
      final drag = await tester.startGesture(tester.getCenter(_itemWithId(4)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      for (var i = 0; i < 2; i++) {
        await drag.moveBy(const Offset(0, 20));
        await tester.pump();
      }
      final pointer = tester.getCenter(_itemWithId(4));

      _resize(tester, const Size(400, 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final center = tester.getCenter(_itemWithId(4));
      expect(center.dx, moreOrLessEquals(pointer.dx));
      expect(center.dy, moreOrLessEquals(pointer.dy));
      await drag.up();
      await tester.pumpAndSettle();
    });

    testWidgets('keeps a dragged item under the pointer as it grows', (
      tester,
    ) async {
      final extent = ValueNotifier(_extent);
      addTearDown(extent.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedReorderable.list(
              keyGetter: (index) => ValueKey(index),
              reorder: const ReorderOptions(onReorder: _ignore),
              listView: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) => ValueListenableBuilder(
                  valueListenable: extent,
                  builder: (context, extent, _) => SizedBox(
                    height: index == 0 ? extent : _extent,
                    child: Text('$index'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // A quarter of the way down the item.
      final drag = await tester.startGesture(const Offset(10, 25));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await drag.moveBy(const Offset(0, 20));
      await tester.pump();
      expect(tester.getTopLeft(find.text('0')).dy, 20);

      extent.value = 2 * _extent;
      await tester.pump();
      await tester.pump();

      // Still a quarter of the way down, under the pointer at 45.
      expect(tester.getTopLeft(find.text('0')).dy, moreOrLessEquals(-5));
      await drag.up();
      await tester.pumpAndSettle();
    });

    testWidgets('keeps a swiped item in its slot', (tester) async {
      final grid = _TestList(
        9,
        grid: true,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisExtent: _extent,
        ),
      );
      await tester.pumpWidget(grid.build());
      // Four columns, so item 5 is in the second row.
      final swipe = await tester.startGesture(tester.getCenter(_itemWithId(5)));
      for (var i = 0; i < 5; i++) {
        await swipe.moveBy(const Offset(-20, 0));
        await tester.pump();
      }

      // Two columns, so item 5 moves to the right of the third row.
      _resize(tester, const Size(400, 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final center = tester.getCenter(_itemWithId(5));
      expect(center.dx, moreOrLessEquals(300 - 100));
      expect(center.dy, moreOrLessEquals(2.5 * _extent));
      await swipe.up();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('moves item elements along with their items', (tester) async {
    final list = _TestList(5);
    await tester.pumpWidget(list.build());
    final element = list.state.getRenderedItemBuildContext(0);

    list.insert(0, 5);
    await tester.pumpAndSettle();

    expect(list.state.getRenderedItemBuildContext(1), same(element));
  });

  group('item state', () {
    testWidgets('survives a reorder', (tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());
      final states = list.states(tester);

      list.state.reorderItem(0, destIndex: 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(_Item), findsNWidgets(5));
      await tester.pumpAndSettle();

      expect(list.states(tester), states);
      expect(list.inits.values, everyElement(1));
    });

    testWidgets('survives an insert', (tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());
      final states = list.states(tester);

      list.insert(0, 5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(_Item), findsNWidgets(6));
      await tester.pumpAndSettle();

      expect(list.states(tester), containsPair(0, states[0]));
      expect(list.states(tester), containsPair(4, states[4]));
      expect(list.inits.values, everyElement(1));
    });

    testWidgets('survives a remove', (tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());
      final states = list.states(tester);

      list.removeAt(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(_Item), findsNWidgets(5));
      await tester.pumpAndSettle();

      expect(list.states(tester), {...states}..remove(0));
      expect(list.inits.values, everyElement(1));
    });

    testWidgets('survives a reorder in a grid', (tester) async {
      final list = _TestList(6, grid: true);
      await tester.pumpWidget(list.build());
      final states = list.states(tester);

      list.state.reorderItem(0, destIndex: 4);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(_Item), findsNWidgets(6));
      await tester.pumpAndSettle();

      expect(list.items, [1, 2, 3, 4, 0, 5]);
      expect(list.states(tester), states);
      expect(list.inits.values, everyElement(1));
    });

    testWidgets('survives a drag', (tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());
      final states = list.states(tester);

      final drag = await tester.startGesture(tester.getCenter(find.text('0')));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      for (var i = 0; i < 11; i++) {
        await drag.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await drag.up();
      await tester.pumpAndSettle();

      expect(list.items, [1, 2, 0, 3, 4]);
      expect(list.states(tester), states);
      expect(list.inits.values, everyElement(1));
    });

    testWidgets('survives a swipe that removes another item', (tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());
      final states = list.states(tester);

      await tester.fling(find.text('1'), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();

      expect(list.items, [0, 2, 3, 4]);
      expect(list.states(tester), {...states}..remove(1));
      expect(list.inits.values, everyElement(1));
    });
  });

  group('insert transition', () {
    Widget enter(Widget child, int index, Animation<double> animation) =>
        _Entrance(animation: animation, child: child);

    testWidgets('runs forward while an item enters', (tester) async {
      final list = _TestList(3, insertTransition: enter);
      await tester.pumpWidget(list.build());

      list.insert(0, 3);
      await tester.pump();
      expect(_entranceOf(tester, 3).value, 0);
      await tester.pump(const Duration(milliseconds: 250));
      expect(_entranceOf(tester, 3).value, closeTo(0.5, 0.01));
      await tester.pumpAndSettle();

      expect(_entranceOf(tester, 3).value, 1);
    });

    testWidgets('builds every other item through it, complete', (tester) async {
      final list = _TestList(3, insertTransition: enter);
      await tester.pumpWidget(list.build());

      list.insert(0, 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect([
        for (final id in [0, 1, 2]) _entranceOf(tester, id).value,
      ], everyElement(1));
    });

    testWidgets('enters a grid', (tester) async {
      final list = _TestList(6, grid: true, insertTransition: enter);
      await tester.pumpWidget(list.build());

      list.insert(0, 6);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(_entranceOf(tester, 6).value, closeTo(0.5, 0.01));
    });

    testWidgets('keeps the state of an item that has entered', (tester) async {
      final list = _TestList(3, insertTransition: enter);
      await tester.pumpWidget(list.build());

      list.insert(0, 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final state = list.states(tester)[3];
      await tester.pumpAndSettle();
      await tester.pumpWidget(list.build());

      expect(list.states(tester)[3], same(state));
      expect(list.inits.values, everyElement(1));
    });

    testWidgets('keeps the state of an entering item that moves', (
      tester,
    ) async {
      final list = _TestList(3, insertTransition: enter);
      await tester.pumpWidget(list.build());

      list.insert(0, 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final state = list.states(tester)[3];
      list.state.reorderItem(0, destIndex: 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // The overlay shows it on its way, still entering.
      expect(_entranceOf(tester, 3).value, closeTo(0.4, 0.01));
      await tester.pumpAndSettle();

      expect(list.items, [0, 1, 3, 2]);
      expect(_tops(tester, list.items), [0, 100, 200, 300]);
      expect(list.states(tester)[3], same(state));
      expect(list.inits.values, everyElement(1));
      expect(_entranceOf(tester, 3).value, 1);
    });

    testWidgets('removes an entering item from where it got to', (
      tester,
    ) async {
      final list = _TestList(3, insertTransition: enter);
      await tester.pumpWidget(list.build());
      final controllers = _undisposed('AnimationController');

      list.insert(0, 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final removals = <double>[];
      list.items.removeAt(0);
      list.state.removeItem(0, (context, animation) {
        removals.add(animation.value);
        return list.buildItem(3);
      });
      await tester.pump();

      expect(removals.first, closeTo(0.5, 0.01));
      // The removed item builder animates it from here on.
      expect(_entranceOf(tester, 3).value, 1);
      await tester.pumpAndSettle();

      expect(_itemWithId(3), findsNothing);
      expect(controllers, isEmpty);
      expect(_trackedTickers(tester), 0);
    });

    testWidgets('lets an item stop entering when the list goes', (
      tester,
    ) async {
      final list = _TestList(3, insertTransition: enter);
      await tester.pumpWidget(list.build());
      final controllers = _undisposed('AnimationController');

      list.insert(0, 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpWidget(const SizedBox());

      expect(controllers, isEmpty);
    });

    testWidgets('uses the latest transition', (tester) async {
      final list = _TestList(3, insertTransition: enter);
      await tester.pumpWidget(list.build());

      list.insert(0, 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      list.insertTransition = (child, index, animation) =>
          _Entrance(animation: animation, label: 'latest', child: child);
      await tester.pumpWidget(list.build());

      final entrance = tester.widget<_Entrance>(_entranceFinder(3));
      expect(entrance.label, 'latest');
      expect(entrance.animation.value, closeTo(0.5, 0.01));
    });

    testWidgets('lets an item in at once without a transition', (tester) async {
      final list = _TestList(3);
      await tester.pumpWidget(list.build());

      list.insert(0, 3);
      await tester.pump();

      expect(_itemWithId(3), findsOneWidget);
      expect(find.byType(_Entrance), findsNothing);
      await tester.pumpAndSettle();
      expect(_tops(tester, list.items), [0, 100, 200, 300]);
    });
  });

  group('insert again while removed', () {
    Future<_TestList> reinsert(WidgetTester tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());
      list.removeAt(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      list.insert(1, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      return list;
    }

    testWidgets('shows the item and the one animating out', (tester) async {
      final list = await reinsert(tester);

      expect(_itemWithId(1), findsNWidgets(2));
      await tester.pumpAndSettle();

      expect(list.items, [0, 1, 2, 3, 4]);
      _expectEachItemOnce(list.items);
      expect(_tops(tester, list.items), [0, 100, 200, 300, 400]);
      expect(_trackedTickers(tester), 0);
    });

    testWidgets('moves an item inserted again at once', (tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());
      list.removeAt(1);
      list.insert(1, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      list.state.reorderItem(1, destIndex: 3);
      await tester.pumpAndSettle();

      expect(list.items, [0, 2, 3, 1, 4]);
      _expectEachItemOnce(list.items);
      expect(_tops(tester, list.items), [0, 100, 200, 300, 400]);
    });

    testWidgets('moves the item', (tester) async {
      final list = await reinsert(tester);

      list.state.reorderItem(1, destIndex: 3);
      await tester.pumpAndSettle();

      expect(list.items, [0, 2, 3, 1, 4]);
      _expectEachItemOnce(list.items);
      expect(_tops(tester, list.items), [0, 100, 200, 300, 400]);
      expect(_trackedTickers(tester), 0);
    });
  });

  testWidgets('removes an item that moves off-screen', (tester) async {
    final notifiers = _undisposed('ChangeNotifier');
    final list = _TestList(50);
    await tester.pumpWidget(list.build());

    list.state.reorderItem(0, destIndex: 40);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    list.removeAt(40);
    await tester.pumpAndSettle();

    expect(list.items.take(6), [1, 2, 3, 4, 5, 6]);
    _expectEachItemOnce([1, 2, 3, 4, 5, 6]);
    expect(_itemWithId(0), findsNothing);
    expect(_trackedTickers(tester), 0);
    await tester.pumpWidget(const SizedBox());
    // The items' placeholder sizes.
    expect(notifiers.whereType<ValueListenable<Size?>>(), isEmpty);
  });

  group('drag', () {
    Future<TestGesture> hold(WidgetTester tester, Offset position) async {
      final drag = await tester.startGesture(position);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      return drag;
    }

    testWidgets('scrolls the list while an item is held at its edge', (
      tester,
    ) async {
      final list = _TestList(50);
      await tester.pumpWidget(list.build());
      // The item reaches past the bottom of the list.
      final drag = await _holdAndDrag(tester, find.text('0'), 26);
      final pixels = _scrollPosition(tester).pixels;

      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(_scrollPosition(tester).pixels, greaterThan(pixels + 200));
      // It takes the place of the items scrolled under it.
      expect(list.items.indexOf(0), greaterThan(7));
      await drag.up();
      final released = _scrollPosition(tester).pixels;
      await tester.pumpAndSettle();
      expect(_scrollPosition(tester).pixels, released);
    });

    testWidgets('takes the place of an item once while over it', (
      tester,
    ) async {
      final heights = [50.0, 200.0, 100.0, 100.0];
      final items = [0, 1, 2, 3];
      var reorders = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedReorderable.list(
              keyGetter: (index) => ValueKey(items[index]),
              reorder: ReorderOptions(
                onReorder: (permutations) {
                  reorders++;
                  permutations.apply(items);
                },
              ),
              listView: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) => SizedBox(
                  height: heights[items[index]],
                  child: Text('${items[index]}'),
                ),
              ),
            ),
          ),
        ),
      );
      final drag = await hold(tester, const Offset(10, 25));

      // Over the tall item, which then moves up under the pointer.
      await drag.moveBy(const Offset(0, 50));
      await tester.pump();
      await drag.moveBy(const Offset(0, 5));
      await tester.pump();

      expect(reorders, 1);
      expect(items, [1, 0, 2, 3]);
      await drag.up();
      await tester.pumpAndSettle();
    });

    testWidgets('takes the place of an item it comes back to', (tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());
      final drag = await hold(tester, const Offset(10, 50));

      // Over item 2, which then moves up past the pointer.
      await drag.moveBy(const Offset(0, 200));
      await tester.pump();
      expect(list.items, [1, 2, 0, 3, 4]);
      await drag.moveBy(const Offset(0, -60));
      await tester.pump();

      expect(list.items, [1, 0, 2, 3, 4]);
      await drag.up();
      await tester.pumpAndSettle();
    });

    testWidgets('drags an item without onReorder', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedReorderable.list(
              keyGetter: (index) => ValueKey(index),
              reorder: ReorderOptions(
                callbacks: ItemDragCallbacks(
                  onStart: (details, index) => calls.add('start $index'),
                  onEnd: (details, index) => calls.add('end $index'),
                ),
              ),
              listView: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) =>
                    SizedBox(height: _extent, child: Text('$index')),
              ),
            ),
          ),
        ),
      );

      final drag = await _holdAndDrag(tester, find.text('0'), 6);

      // It follows the pointer, as decorated, and takes no other item's
      // place.
      expect(tester.getTopLeft(find.text('0')).dy, closeTo(120, 1));
      expect(tester.getTopLeft(find.text('1')).dy, 100);
      await drag.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('0')).dy, 0);
      expect(calls, ['start 0', 'end 0']);
    });

    for (final (name, decorator) in [
      ('the default decorator', _keepDecorator),
      ('no decorator', null),
    ]) {
      testWidgets('decorates a dragged item with $name', (tester) async {
        Widget build() => MaterialApp(
          home: Scaffold(
            body: decorator == _keepDecorator
                ? AnimatedReorderable.list(
                    keyGetter: (index) => ValueKey(index),
                    reorder: const ReorderOptions(onReorder: _ignore),
                    listView: _fiveLabels(),
                  )
                : AnimatedReorderable.list(
                    keyGetter: (index) => ValueKey(index),
                    reorder: const ReorderOptions(
                      onReorder: _ignore,
                      decoration: ItemDecoration.none,
                    ),
                    listView: _fiveLabels(),
                  ),
          ),
        );
        await tester.pumpWidget(build());
        final transitions = _transitionsAround(tester, find.text('0'));

        final drag = await _holdAndDrag(tester, find.text('0'), 2);

        expect(
          _transitionsAround(tester, find.text('0')),
          transitions + (decorator == null ? 0 : 2),
        );
        await drag.up();
        await tester.pumpAndSettle();
      });

      testWidgets('decorates a swiped item with $name', (tester) async {
        Widget build() => MaterialApp(
          home: Scaffold(
            body: decorator == _keepDecorator
                ? AnimatedReorderable.list(
                    keyGetter: (index) => ValueKey(index),
                    swipeToRemove: const SwipeToRemoveOptions(
                      onSwipeToRemove: _ignore,
                    ),
                    listView: _fiveLabels(),
                  )
                : AnimatedReorderable.list(
                    keyGetter: (index) => ValueKey(index),
                    swipeToRemove: const SwipeToRemoveOptions(
                      onSwipeToRemove: _ignore,
                      decoration: ItemDecoration.none,
                    ),
                    listView: _fiveLabels(),
                  ),
          ),
        );
        await tester.pumpWidget(build());
        final transitions = _transitionsAround(tester, find.text('0'));

        final swipe = await tester.startGesture(
          tester.getCenter(find.text('0')),
        );
        await swipe.moveBy(const Offset(-30, 0));
        await tester.pump();
        await swipe.moveBy(const Offset(-30, 0));
        await tester.pump();

        expect(
          _transitionsAround(tester, find.text('0')),
          transitions + (decorator == null ? 0 : 2),
        );
        await swipe.up();
        await tester.pumpAndSettle();
      });
    }

    testWidgets('does not move an item that is not reorderable', (
      tester,
    ) async {
      final list = _TestList(5)..reorderableGetter = (index) => index != 0;
      await tester.pumpWidget(list.build());

      final drag = await _holdAndDrag(tester, find.text('0'), 11);
      await drag.up();
      await tester.pumpAndSettle();

      expect(list.items, [0, 1, 2, 3, 4]);
      expect(list.reorders, 0);
    });
  });

  group('two changes in a frame', () {
    testWidgets('removes an item and inserts one at the end of a grid', (
      tester,
    ) async {
      final list = _TestList(4, grid: true);
      await tester.pumpWidget(list.build());

      list
        ..removeAt(2)
        ..insert(3, 9);
      // Each frame shows every item as itself, moving or not.
      do {
        await tester.pump(const Duration(milliseconds: 50));
        _expectEachItemOnce(list.items);
      } while (tester.binding.hasScheduledFrame);

      expect(list.items, [0, 1, 3, 9]);
    });

    for (final (name, count, change, items) in [
      (
        'inserts two items',
        4,
        (_TestList list) => list
          ..insert(0, 4)
          ..insert(0, 5),
        [5, 4, 0, 1, 2, 3],
      ),
      (
        'removes two items',
        5,
        (_TestList list) => list
          ..removeAt(0)
          ..removeAt(0),
        [2, 3, 4],
      ),
      (
        'inserts an item and removes another',
        5,
        (_TestList list) => list
          ..insert(0, 5)
          ..removeAt(2),
        [5, 0, 2, 3, 4],
      ),
      (
        'reorders twice',
        5,
        (_TestList list) => list.state
          ..reorderItem(0, destIndex: 2)
          ..reorderItem(3, destIndex: 0),
        [3, 1, 2, 0, 4],
      ),
    ]) {
      testWidgets(name, (tester) async {
        final list = _TestList(count);
        await tester.pumpWidget(list.build());

        change(list);
        // Each frame shows every item as itself, moving or not.
        do {
          await tester.pump(const Duration(milliseconds: 50));
          _expectEachItemOnce(items);
        } while (tester.binding.hasScheduledFrame);

        expect(list.items, items);
        expect(_tops(tester, items), [
          for (final (index, _) in items.indexed) index * _extent,
        ]);
      });
    }
  });

  group('swipe to remove', () {
    for (final (scrollDirection, direction) in [
      (Axis.vertical, AxisDirection.left),
      (Axis.vertical, AxisDirection.right),
      (Axis.horizontal, AxisDirection.up),
      (Axis.horizontal, AxisDirection.down),
    ]) {
      group(direction.name, () {
        final forward = _unit(direction);
        // The item's extent along its swipe axis.
        final extent = scrollDirection == Axis.vertical ? 800.0 : 600.0;
        double along(Offset offset) =>
            offset.dx * forward.dx + offset.dy * forward.dy;
        // Long enough to scroll, so the list competes for drags.
        _TestList createList() => _TestList(
          20,
          scrollDirection: scrollDirection,
          swipeToRemoveDirection: direction,
        );
        final items = List.generate(20, (i) => i);
        final removed = [...items]..remove(1);

        testWidgets('springs an item back from a short swipe', (tester) async {
          final list = createList();
          await tester.pumpWidget(list.build());
          final slot = tester.getTopLeft(_itemWithId(1));

          await tester.timedDrag(
            _itemWithId(1),
            forward * extent * 0.5,
            const Duration(seconds: 1),
          );
          await tester.pumpAndSettle();

          expect(list.items, items);
          expect(tester.getTopLeft(_itemWithId(1)), slot);
        });

        testWidgets('removes an item swiped far enough', (tester) async {
          final list = createList();
          await tester.pumpWidget(list.build());

          await tester.timedDrag(
            _itemWithId(1),
            forward * extent * 0.7,
            const Duration(seconds: 2),
          );
          await tester.pumpAndSettle();

          expect(list.items, removed);
        });

        testWidgets('removes an item flung fast enough', (tester) async {
          final list = createList();
          await tester.pumpWidget(list.build());

          await tester.fling(_itemWithId(1), forward * extent * 0.2, 2000);
          await tester.pumpAndSettle();

          expect(list.items, removed);
        });

        testWidgets('springs an item back from a fling the other way', (
          tester,
        ) async {
          final list = createList();
          await tester.pumpWidget(list.build());
          final slot = tester.getTopLeft(_itemWithId(1));

          await tester.fling(_itemWithId(1), -forward * extent * 0.2, 2000);
          await tester.pumpAndSettle();

          expect(list.items, items);
          expect(tester.getTopLeft(_itemWithId(1)), slot);
        });

        testWidgets('scrolls the list from a drag along it', (tester) async {
          final list = createList();
          await tester.pumpWidget(list.build());
          final slot = tester.getTopLeft(_itemWithId(1));
          final back = scrollDirection == Axis.vertical
              ? const Offset(0, -1)
              : const Offset(-1, 0);

          await tester.drag(_itemWithId(1), back * 200);
          await tester.pumpAndSettle();

          final pixels = _scrollPosition(tester).pixels;
          expect(pixels, greaterThan(100));
          expect(tester.getTopLeft(_itemWithId(1)) - slot, back * pixels);
          expect(list.items, items);
        });

        testWidgets('damps a pull the other way', (tester) async {
          final list = createList();
          await tester.pumpWidget(list.build());
          final slot = tester.getTopLeft(_itemWithId(1));

          final swipe = await tester.startGesture(
            tester.getCenter(_itemWithId(1)),
          );
          final offsets = <double>[];
          for (final distance in const [30.0, -30.0, -30.0, -30.0]) {
            await swipe.moveBy(forward * distance);
            await tester.pump();
            offsets.add(along(tester.getTopLeft(_itemWithId(1)) - slot));
          }

          // Freely back to its slot and past it, then a third as far.
          expect(offsets, [30, 0, -30, -40]);
          await swipe.up();
          await tester.pumpAndSettle();
        });

        testWidgets('keeps a swiped item on its axis', (tester) async {
          final list = createList();
          await tester.pumpWidget(list.build());
          final slot = tester.getTopLeft(_itemWithId(1));
          final across = Offset(forward.dy, forward.dx);

          final swipe = await tester.startGesture(
            tester.getCenter(_itemWithId(1)),
          );
          await swipe.moveBy(forward * 50);
          await tester.pump();
          await swipe.moveBy(forward * 20 + across * 40);
          await tester.pump();

          expect(tester.getTopLeft(_itemWithId(1)) - slot, forward * 70);
          await swipe.up();
          await tester.pumpAndSettle();
        });

        testWidgets('flings a removed item out through its edge', (
          tester,
        ) async {
          final list = createList();
          await tester.pumpWidget(list.build());
          final slot = tester.getTopLeft(_itemWithId(1));

          await tester.fling(_itemWithId(1), forward * extent * 0.2, 2000);
          final offsets = <Offset>[];
          for (var i = 0; i < 11; i++) {
            await tester.pump(const Duration(milliseconds: 50));
            offsets.add(tester.getTopLeft(_itemWithId(1)) - slot);
          }

          for (var i = 1; i < offsets.length; i++) {
            expect(along(offsets[i]), greaterThan(along(offsets[i - 1])));
          }
          // Its decoration scales it a little about its center.
          expect(
            offsets.map((offset) => offset - forward * along(offset)),
            everyElement(_offsetCloseTo(Offset.zero, 3)),
          );
          // On its way to just outside the overlay, which covers the list.
          expect(
            along(offsets.last),
            allOf(lessThan(extent), greaterThan(extent * 0.95)),
          );
          await tester.pumpAndSettle();
        });
      });
    }
  });

  group('grid', () {
    // Three columns of squares.
    const side = 800 / 3;

    testWidgets('takes a grid delegate of another type', (tester) async {
      Widget build(SliverGridDelegate gridDelegate) => MaterialApp(
        home: Scaffold(
          body: AnimatedReorderable.grid(
            keyGetter: (index) => ValueKey(index),
            gridView: GridView.builder(
              gridDelegate: gridDelegate,
              itemCount: 9,
              itemBuilder: (context, index) => _Item(id: index, onInit: () {}),
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        build(
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
        ),
      );

      await tester.pumpWidget(
        build(
          const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // Four columns.
      expect(tester.getTopLeft(_itemWithId(4)), const Offset(0, 200));
    });

    testWidgets('moves items aside for an inserted item', (tester) async {
      // Three rows, on the screen.
      final grid = _TestList(8, grid: true);
      await tester.pumpWidget(grid.build());

      grid.insert(0, 9);
      final path = await _pathUntilSettled(
        tester,
        _itemWithId(2),
        onFrame: () => _expectEachItemOnce(grid.items),
      );

      _expectStraightPath(
        path,
        const Offset(2 * side, 0),
        const Offset(0, side),
      );
      expect(tester.getTopLeft(_itemWithId(9)), Offset.zero);
      expect(grid.inits.values, everyElement(1));
    });

    testWidgets('moves items into the place of a removed item', (tester) async {
      final grid = _TestList(9, grid: true);
      await tester.pumpWidget(grid.build());

      grid.removeAt(0);
      final path = await _pathUntilSettled(
        tester,
        _itemWithId(3),
        onFrame: () => _expectEachItemOnce(grid.items),
      );

      _expectStraightPath(
        path,
        const Offset(0, side),
        const Offset(2 * side, 0),
      );
      expect(_itemWithId(0), findsNothing);
      expect(grid.inits.values, everyElement(1));
    });
  });

  group('reorder off-screen', () {
    for (final (scrollDirection, reverse, edge) in [
      (Axis.vertical, false, AxisDirection.down),
      (Axis.vertical, true, AxisDirection.up),
      (Axis.horizontal, false, AxisDirection.right),
      (Axis.horizontal, true, AxisDirection.left),
    ]) {
      final forward = _unit(edge);
      final viewportExtent = scrollDirection == Axis.vertical ? 600.0 : 800.0;
      _TestList createList() =>
          _TestList(50, scrollDirection: scrollDirection, reverse: reverse);

      testWidgets('moves an item out through the ${edge.name} edge', (
        tester,
      ) async {
        final list = createList();
        await tester.pumpWidget(list.build());
        final slot = tester.getTopLeft(_itemWithId(0));

        list.state.reorderItem(0, destIndex: 40);
        final path = await _pathUntilSettled(tester, _itemWithId(0));

        // To just outside the overlay.
        _expectStraightPath(path, slot, slot + forward * viewportExtent);
        expect(_itemWithId(0), findsNothing);
        expect(list.items.indexOf(0), 40);
      });

      testWidgets('moves an item in through the ${edge.name} edge', (
        tester,
      ) async {
        final list = createList();
        await tester.pumpWidget(list.build());
        final slot = tester.getRect(_itemWithId(0));

        list.state.reorderItem(40, destIndex: 0);
        final path = await _pathUntilSettled(
          tester,
          _itemWithId(40),
          // As big as its slot all the way.
          onFrame: () => expect(tester.getSize(_itemWithId(40)), slot.size),
        );

        // From just outside the overlay.
        _expectStraightPath(
          path,
          slot.topLeft + forward * viewportExtent,
          slot.topLeft,
        );
        expect(list.items.indexOf(40), 0);
      });
    }

    testWidgets('moves an item in along a padded list', (tester) async {
      final list = _TestList(
        50,
        padding: const EdgeInsets.only(left: 300, right: 100),
      );
      await tester.pumpWidget(list.build());
      final slot = tester.getRect(_itemWithId(0));

      list.state.reorderItem(40, destIndex: 0);
      final path = await _pathUntilSettled(
        tester,
        _itemWithId(40),
        onFrame: () => expect(tester.getSize(_itemWithId(40)), slot.size),
      );

      _expectStraightPath(
        path,
        slot.topLeft + const Offset(0, 600),
        slot.topLeft,
      );
    });
  });

  group('scroll', () {
    for (final (scrollDirection, reverse, shift) in [
      (Axis.vertical, false, const Offset(0, -50)),
      (Axis.vertical, true, const Offset(0, 50)),
      (Axis.horizontal, false, const Offset(-50, 0)),
      (Axis.horizontal, true, const Offset(50, 0)),
    ]) {
      testWidgets('moves moving items with a ${reverse ? 'reversed ' : ''}'
          '${scrollDirection.name} list', (tester) async {
        final list = _TestList(
          50,
          scrollDirection: scrollDirection,
          reverse: reverse,
        );
        await tester.pumpWidget(list.build());
        list.state.reorderItem(0, destIndex: 3);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final position = tester.getTopLeft(_itemWithId(0));

        _scrollPosition(tester).jumpTo(50);
        await tester.pump();

        expect(tester.getTopLeft(_itemWithId(0)) - position, shift);
        await tester.pumpAndSettle();
        expect(list.items.indexOf(0), 3);
      });
    }
  });

  group('children delegate', () {
    testWidgets('reorders the children of a list view', (tester) async {
      final list = _ChildrenList(5);
      await tester.pumpWidget(list.build());

      list.state.reorderItem(0, destIndex: 2);
      await tester.pumpWidget(list.build());
      await tester.pumpAndSettle();

      expect(list.items, [1, 2, 0, 3, 4]);
      expect(_tops(tester, list.items), [0, 100, 200, 300, 400]);
      expect(list.inits.values, everyElement(1));
    });

    testWidgets('inserts into the children of a list view', (tester) async {
      final list = _ChildrenList(5);
      await tester.pumpWidget(list.build());

      list.items.insert(0, 5);
      list.state.insertItem(0);
      await tester.pumpWidget(list.build());
      await tester.pumpAndSettle();

      expect(_tops(tester, list.items), [0, 100, 200, 300, 400, 500]);
      expect(list.inits.values, everyElement(1));
    });

    testWidgets("finds moved items with the list view's callback", (
      tester,
    ) async {
      final list = _ChildrenList(5, builder: true);
      await tester.pumpWidget(list.build());

      list.items.insert(0, 5);
      list.state.insertItem(0);
      await tester.pumpAndSettle();

      expect(list.foundKeys, isNotEmpty);
      expect(_tops(tester, list.items), [0, 100, 200, 300, 400, 500]);
      expect(list.inits.values, everyElement(1));
    });
  });

  group('errors', () {
    Widget noRemovedItem(BuildContext context, Animation<double> _) =>
        const SizedBox();

    testWidgets('checks the index of an inserted item', (tester) async {
      final list = _TestList(3);
      await tester.pumpWidget(list.build());

      expect(() => list.state.insertItem(-1), throwsRangeError);
      expect(() => list.state.insertItem(4), throwsRangeError);
      list.insert(3, 3);
      await tester.pumpAndSettle();
      expect(_itemWithId(3), findsOneWidget);
    });

    testWidgets('checks the index of a removed item', (tester) async {
      final list = _TestList(3);
      await tester.pumpWidget(list.build());

      expect(() => list.state.removeItem(-1, noRemovedItem), throwsRangeError);
      expect(() => list.state.removeItem(3, noRemovedItem), throwsRangeError);
    });

    testWidgets('checks the index of a reordered item', (tester) async {
      final list = _TestList(3);
      await tester.pumpWidget(list.build());

      expect(() => list.state.reorderItem(-1, destIndex: 0), throwsRangeError);
      expect(() => list.state.reorderItem(3, destIndex: 0), throwsRangeError);
    });

    testWidgets('checks the destination of a reordered item', (tester) async {
      final key = GlobalKey<AnimatedReorderableState>();
      final reorders = <Permutations>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedReorderable.list(
              key: key,
              // Keys any index, so only the check can stop a bad one.
              keyGetter: (index) => ValueKey(index),
              reorder: ReorderOptions(onReorder: reorders.add),
              listView: ListView.builder(
                itemCount: 3,
                itemBuilder: (context, index) => Text('$index'),
              ),
            ),
          ),
        ),
      );

      expect(
        () => key.currentState!.reorderItem(0, destIndex: 3),
        throwsRangeError,
      );
      expect(
        () => key.currentState!.reorderItem(0, destIndex: -1),
        throwsRangeError,
      );
      expect(reorders, isEmpty);
    });

    testWidgets('needs onReorder to reorder', (tester) async {
      final key = GlobalKey<AnimatedReorderableState>();
      await tester.pumpWidget(_labels(const ['a', 'b'], key: key));

      expect(
        () => key.currentState!.reorderItem(0, destIndex: 1),
        throwsStateError,
      );
    });

    testWidgets('reorders only reorderable items', (tester) async {
      final key = GlobalKey<AnimatedReorderableState>();
      final labels = ['a', 'b', 'c'];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedReorderable.list(
              key: key,
              keyGetter: (index) => ValueKey(labels[index]),
              reorder: ReorderOptions(
                reorderableGetter: (index) => index != 1,
                onReorder: (permutations) => permutations.apply(labels),
              ),
              listView: ListView.builder(
                itemCount: labels.length,
                itemBuilder: (context, index) => Text(labels[index]),
              ),
            ),
          ),
        ),
      );

      expect(
        () => key.currentState!.reorderItem(1, destIndex: 0),
        throwsArgumentError,
      );
      expect(
        () => key.currentState!.reorderItem(0, destIndex: 1),
        throwsArgumentError,
      );
      expect(labels, ['a', 'b', 'c']);
    });

    testWidgets('needs an item count to insert', (tester) async {
      final key = GlobalKey<AnimatedReorderableState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedReorderable.list(
              key: key,
              keyGetter: (index) => ValueKey(index),
              listView: ListView.builder(
                itemBuilder: (context, index) => Text('$index'),
              ),
            ),
          ),
        ),
      );

      expect(() => key.currentState!.insertItem(0), throwsStateError);
      expect(
        () => key.currentState!.removeItem(0, noRemovedItem),
        throwsStateError,
      );
    });

    testWidgets('supports only the children delegates of the framework', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedReorderable.list(
              keyGetter: (index) => ValueKey(index),
              listView: ListView.custom(childrenDelegate: _OtherDelegate()),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isUnsupportedError);
    });
  });

  group('callbacks', () {
    testWidgets('report a swipe', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _withCallbacks(
          calls,
          onSwipeToRemove: (index) => calls.add('remove $index'),
        ),
      );

      final swipe = await tester.startGesture(tester.getCenter(find.text('1')));
      await swipe.moveBy(const Offset(-30, 0));
      await tester.pump();
      await swipe.moveBy(const Offset(-20, 40));
      await tester.pump();
      await swipe.up();
      await tester.pumpAndSettle();

      expect(calls, [
        'swipe start 1',
        'swipe update 1 Offset(-30.0, 0.0) -30.0',
        'swipe update 1 Offset(-20.0, 0.0) -20.0',
        'swipe end 1',
      ]);
    });

    testWidgets('report a swipe that removes an item', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _withCallbacks(
          calls,
          onSwipeToRemove: (index) => calls.add('remove $index'),
        ),
      );

      await tester.fling(find.text('1'), const Offset(-200, 0), 2000);
      await tester.pumpAndSettle();

      expect(calls.first, 'swipe start 1');
      expect(
        calls.skip(1).take(calls.length - 3),
        everyElement(startsWith('swipe update 1')),
      );
      expect(calls.reversed.take(2), ['remove 1', 'swipe end 1']);
    });

    testWidgets('report a drag', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_withCallbacks(calls));

      final drag = await tester.startGesture(tester.getCenter(find.text('0')));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      for (var i = 0; i < 11; i++) {
        await drag.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await drag.up();
      await tester.pumpAndSettle();

      expect(calls.first, 'drag start 0');
      expect(calls.last, 'drag end 2');
      expect(calls, contains('drag update 0 Offset(0.0, 20.0) null'));
      expect(calls, contains('drag update 2 Offset(0.0, 20.0) null'));
    });
  });
}

/// A list of [labels] keyed by label, rebuilt from scratch like immutable
/// state would be.
Widget _labels(
  List<String> labels, {
  Key? key,
  PermutationsCallback? onReorder,
}) => MaterialApp(
  home: Scaffold(
    body: AnimatedReorderable.list(
      key: key,
      keyGetter: (index) => ValueKey(labels[index]),
      reorder: ReorderOptions(onReorder: onReorder),
      listView: ListView.builder(
        itemCount: labels.length,
        itemBuilder: (context, index) => Text(labels[index]),
      ),
    ),
  ),
);

/// A long list of numbers that scrolls with [controller] or as [primary]
/// says.
Widget _scrollable({ScrollController? controller, bool? primary}) =>
    MaterialApp(
      home: Scaffold(
        body: AnimatedReorderable.list(
          keyGetter: (index) => ValueKey(index),
          listView: ListView.builder(
            controller: controller,
            primary: primary,
            itemCount: 50,
            itemBuilder: (context, index) =>
                SizedBox(height: _extent, child: Text('$index')),
          ),
        ),
      ),
    );

/// A callback that does nothing.
void _ignore(Object? _) {}

/// Stands for a decorator the test leaves at its default.
Widget _keepDecorator(Widget child, int index, Animation<double> animation) =>
    child;

/// Five labels of the test's extent.
ListView _fiveLabels() => ListView.builder(
  itemCount: 5,
  itemBuilder: (context, index) =>
      SizedBox(height: _extent, child: Text('$index')),
);

/// How many scale and fade transitions are around [finder].
int _transitionsAround(WidgetTester tester, Finder finder) => find
    .ancestor(
      of: finder,
      matching: find.byWidgetPredicate(
        (widget) => widget is ScaleTransition || widget is FadeTransition,
      ),
    )
    .evaluate()
    .length;

/// Holds the item at [finder] until a drag starts and drags it down by
/// [steps] steps of 20 pixels, a frame each.
Future<TestGesture> _holdAndDrag(
  WidgetTester tester,
  Finder finder,
  int steps,
) async {
  final drag = await tester.startGesture(tester.getCenter(finder));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  for (var i = 0; i < steps; i++) {
    await drag.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 16));
  }
  return drag;
}

/// The ids of the items from the bottom one up.
List<int> _paintOrder(WidgetTester tester) => [
  for (final item in tester.widgetList<_Item>(find.byType(_Item))) item.id,
];

Finder _itemWithId(int id) =>
    find.byWidgetPredicate((widget) => widget is _Item && widget.id == id);

ScrollPosition _scrollPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

/// Resizes the test view to [size] in logical pixels until the test ends.
void _resize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
}

/// One logical pixel in [direction].
Offset _unit(AxisDirection direction) => switch (direction) {
  AxisDirection.left => const Offset(-1, 0),
  AxisDirection.right => const Offset(1, 0),
  AxisDirection.up => const Offset(0, -1),
  AxisDirection.down => const Offset(0, 1),
};

/// The tops of the items with [ids].
List<double> _tops(WidgetTester tester, List<int> ids) => [
  for (final id in ids) tester.getTopLeft(_itemWithId(id)).dy,
];

/// Where [finder] is after each frame until the animations end, or until it
/// is gone. Calls [onFrame] after each frame.
Future<List<Offset>> _pathUntilSettled(
  WidgetTester tester,
  Finder finder, {
  VoidCallback? onFrame,
}) async {
  final path = <Offset>[];
  do {
    await tester.pump(const Duration(milliseconds: 50));
    onFrame?.call();
    if (finder.evaluate().isEmpty) break;
    path.add(tester.getTopLeft(finder));
  } while (tester.binding.hasScheduledFrame);
  return path;
}

/// Expects every item of [ids] to show once, as itself.
void _expectEachItemOnce(List<int> ids) {
  for (final id in ids) {
    expect(_itemWithId(id), findsOneWidget, reason: 'item $id');
  }
}

/// Expects [path] to go straight from [from] to [to], never back.
void _expectStraightPath(List<Offset> path, Offset from, Offset to) {
  expect(path.first, from);
  expect(path.last, to);
  final direction = (to - from) / (to - from).distance;
  var traveled = 0.0;
  for (final position in path) {
    final offset = position - from;
    final along = offset.dx * direction.dx + offset.dy * direction.dy;
    expect(offset - direction * along, _offsetCloseTo(Offset.zero, 1e-6));
    expect(along, greaterThanOrEqualTo(traveled));
    traveled = along;
  }
}

Matcher _offsetCloseTo(Offset expected, double epsilon) => predicate<Offset>(
  (offset) => (offset - expected).distance < epsilon,
  'within $epsilon of $expected',
);

/// A list view of children, or with [builder] a list view builder that
/// finds its children by key.
class _ChildrenList {
  _ChildrenList(int count, {this.builder = false})
    : items = List.generate(count, (i) => i);

  final List<int> items;
  final bool builder;
  final key = GlobalKey<AnimatedReorderableState>();
  final inits = <int, int>{};

  /// The keys the list view builder's callback was asked to find.
  final foundKeys = <Key>[];

  AnimatedReorderableState get state => key.currentState!;

  Widget build() => MaterialApp(
    home: Scaffold(
      body: AnimatedReorderable.list(
        key: key,
        keyGetter: (index) => ValueKey(items[index]),
        reorder: ReorderOptions(
          onReorder: (permutations) => permutations.apply(items),
        ),
        listView: builder
            ? ListView.builder(
                itemCount: items.length,
                findChildIndexCallback: (key) {
                  foundKeys.add(key);
                  final index = items.indexOf((key as ValueKey<int>).value);
                  return index < 0 ? null : index;
                },
                itemBuilder: (context, index) => item(items[index]),
              )
            : ListView(children: [for (final id in items) item(id)]),
      ),
    ),
  );

  Widget item(int id) => _Item(
    id: id,
    onInit: () => inits.update(id, (n) => n + 1, ifAbsent: () => 1),
  );
}

/// A list of five labels that records its drag and swipe callbacks in
/// [calls].
Widget _withCallbacks(
  List<String> calls, {
  SwipeToRemoveCallback? onSwipeToRemove,
}) {
  final labels = ['0', '1', '2', '3', '4'];
  String update(String name, DragUpdateDetails details, int index) =>
      '$name update $index ${details.delta} ${details.primaryDelta}';
  return MaterialApp(
    home: Scaffold(
      body: AnimatedReorderable.list(
        keyGetter: (index) => ValueKey(labels[index]),
        reorder: ReorderOptions(
          onReorder: (permutations) => permutations.apply(labels),
          callbacks: ItemDragCallbacks(
            onStart: (details, index) => calls.add('drag start $index'),
            onUpdate: (details, index) =>
                calls.add(update('drag', details, index)),
            onEnd: (details, index) => calls.add('drag end $index'),
          ),
        ),
        swipeToRemove: SwipeToRemoveOptions(
          onSwipeToRemove: onSwipeToRemove,
          callbacks: ItemDragCallbacks(
            onStart: (details, index) => calls.add('swipe start $index'),
            onUpdate: (details, index) =>
                calls.add(update('swipe', details, index)),
            onEnd: (details, index) => calls.add('swipe end $index'),
          ),
        ),
        listView: ListView.builder(
          itemCount: labels.length,
          itemBuilder: (context, index) =>
              SizedBox(height: _extent, child: Text(labels[index])),
        ),
      ),
    ),
  );
}

/// A children delegate that is not one of the framework's.
class _OtherDelegate extends SliverChildDelegate {
  @override
  Widget? build(BuildContext context, int index) => null;

  @override
  bool shouldRebuild(covariant SliverChildDelegate oldDelegate) => false;
}

/// A list of ids shown as stateful items of a fixed extent.
class _TestList {
  _TestList(
    int count, {
    this.grid = false,
    this.gridDelegate = const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
    ),
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.padding,
    this.swipeToRemoveDirection,
    this.swipeToRemoveSpringDescription = _defaultSpring,
    this.insertTransition,
  }) : items = List.generate(count, (i) => i);

  final List<int> items;
  final bool grid;
  final SliverGridDelegate gridDelegate;
  final Axis scrollDirection;
  final bool reverse;
  final EdgeInsets? padding;

  /// The swipe direction of every item, or null for the default one.
  AxisDirection? swipeToRemoveDirection;
  final SpringDescription swipeToRemoveSpringDescription;

  /// The transition items enter with, or null for none.
  AnimatedItemDecorator? insertTransition;
  BoolGetter? draggableGetter;
  BoolGetter? reorderableGetter;
  final key = GlobalKey<AnimatedReorderableState>();

  /// How many times the list was reordered.
  int reorders = 0;

  /// How many times each item's state was created.
  final inits = <int, int>{};

  AnimatedReorderableState get state => key.currentState!;

  Widget build() => MaterialApp(home: Scaffold(body: buildList()));

  Widget buildList() => grid
      ? AnimatedReorderable.grid(
          key: key,
          keyGetter: (index) => ValueKey(items[index]),
          reorder: ReorderOptions(
            onReorder: (permutations) => permutations.apply(items),
          ),
          swipeToRemove: SwipeToRemoveOptions(
            onSwipeToRemove: removeAt,
            directionGetter: _swipeToRemoveDirectionGetter,
          ),
          insertTransition: insertTransition,
          gridView: GridView.builder(
            scrollDirection: scrollDirection,
            reverse: reverse,
            padding: padding,
            gridDelegate: gridDelegate,
            itemCount: items.length,
            itemBuilder: (context, index) => _item(items[index]),
          ),
        )
      : AnimatedReorderable.list(
          key: key,
          keyGetter: (index) => ValueKey(items[index]),
          reorder: ReorderOptions(
            onReorder: (permutations) {
              reorders++;
              permutations.apply(items);
            },
            draggableGetter: draggableGetter,
            reorderableGetter: reorderableGetter,
          ),
          swipeToRemove: SwipeToRemoveOptions(
            onSwipeToRemove: removeAt,
            directionGetter: _swipeToRemoveDirectionGetter,
            springDescription: swipeToRemoveSpringDescription,
          ),
          insertTransition: insertTransition,
          listView: ListView.builder(
            scrollDirection: scrollDirection,
            reverse: reverse,
            padding: padding,
            itemCount: items.length,
            itemBuilder: (context, index) => _item(items[index]),
          ),
        );

  AxisDirectionGetter? get _swipeToRemoveDirectionGetter =>
      switch (swipeToRemoveDirection) {
        final direction? => (_) => direction,
        null => null,
      };

  void insert(int index, int id) {
    items.insert(index, id);
    state.insertItem(index);
  }

  void removeAt(int index) {
    final id = items.removeAt(index);
    state.removeItem(index, (context, animation) => _item(id));
  }

  /// The state of each item by its id.
  Map<int, State> states(WidgetTester tester) => {
    for (final state in tester.stateList<_ItemState>(find.byType(_Item)))
      state.widget.id: state,
  };

  Widget buildItem(int id) => _item(id);

  Widget _item(int id) => _Item(
    id: id,
    onInit: () => inits.update(id, (n) => n + 1, ifAbsent: () => 1),
  );
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
      SizedBox.square(dimension: _extent, child: Text('${widget.id}'));
}

/// The objects of [className] created from now on that are not disposed yet.
Set<Object> _undisposed(String className) {
  final undisposed = Set<Object>.identity();
  void listener(ObjectEvent event) {
    if (event is ObjectCreated && event.className == className) {
      undisposed.add(event.object);
    } else if (event is ObjectDisposed) {
      undisposed.remove(event.object);
    }
  }

  FlutterMemoryAllocations.instance.addListener(listener);
  addTearDown(() => FlutterMemoryAllocations.instance.removeListener(listener));
  return undisposed;
}

int _trackedTickers(WidgetTester tester) {
  final state = tester.state(
    find.byWidgetPredicate((widget) => widget is AnimatedReorderable),
  );
  final tracking = RegExp(r'tracking (\d+) ticker').firstMatch('$state');
  return tracking == null ? 0 : int.parse(tracking.group(1)!);
}

/// The entrance transitions around the item with [id], the closest first.
Finder _entranceFinder(int id) =>
    find.ancestor(of: _itemWithId(id), matching: find.byType(_Entrance));

/// The animation of the closest entrance transition around the item with
/// [id].
Animation<double> _entranceOf(WidgetTester tester, int id) =>
    tester.widget<_Entrance>(_entranceFinder(id).first).animation;

/// A transition an item enters with, which tests can find.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.animation, this.label, required this.child});

  final Animation<double> animation;
  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: animation, child: child);
}
