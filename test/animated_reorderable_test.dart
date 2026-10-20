import 'dart:math' as math;

import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:animated_reorderable/src/widget/overlayed_items_layer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _extent = 100.0;

/// The package's default motion duration.
const _motionDuration = Duration(milliseconds: 250);

/// The package's default insert and remove duration.
const _insertDuration = Duration(milliseconds: 300);

/// The package's default fling spring.
const _defaultSpring = SpringDescription(
  mass: 1,
  stiffness: 2000,
  damping: 150,
);

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

  group('in place', () {
    /// The ids of the items the overlay shows, above the list or under it.
    List<int> overlayed(WidgetTester tester) => [
      for (final item in tester.widgetList<_Item>(
        find.descendant(
          of: find.byType(OverlayedItemsLayer),
          matching: find.byType(_Item),
        ),
      ))
        item.id,
    ]..sort();

    // The view shows the slots of items 0 to 5, and the list lays out 6 to
    // 8 too, out of sight.

    testWidgets('moves the items a reorder moves in place, in the list', (
      tester,
    ) async {
      final list = _TestList(10);
      await tester.pumpWidget(list.build());

      list.state.reorderItem(2, destIndex: 4);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(overlayed(tester), isEmpty);
      final top = tester.getTopLeft(_itemWithId(2)).dy;
      expect(top, greaterThan(2 * _extent));
      expect(top, lessThan(4 * _extent));
      expect(_paintedTopLeft(tester, _itemWithId(2)).dy, top);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_itemWithId(2)).dy, 4 * _extent);
    });

    testWidgets('lets a pointer take an item moving in place where it shows', (
      tester,
    ) async {
      final list = _TestList(10);
      await tester.pumpWidget(list.build());
      list.state.reorderItem(2, destIndex: 4);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // Its middle, which the decoration of a swiped item doesn't move.
      double middle() => tester.getCenter(_itemWithId(2)).dy;
      final shown = middle();
      expect(shown, greaterThan(2.5 * _extent));
      expect(shown, lessThan(4.5 * _extent));

      // A swipe takes it where it shows, between its slots.
      final swipe = await tester.startGesture(tester.getCenter(_itemWithId(2)));
      await swipe.moveBy(const Offset(-30, 0));
      await tester.pump();

      expect(overlayed(tester), [2]);
      expect(middle(), shown);
      // It goes on to its slot as it is swiped, without a jump.
      final middles = [shown];
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        middles.add(middle());
      }
      expect(middles.last, 4.5 * _extent);
      expect(_steps(middles), everyElement(inInclusiveRange(0, 20)));
      await swipe.up();
      await tester.pumpAndSettle();
      expect(list.items, [0, 1, 3, 4, 2, 5, 6, 7, 8, 9]);
    });

    testWidgets('lets a long press take a grid item moving in place where it '
        'shows', (tester) async {
      final items = List.generate(30, (i) => i);
      final key = GlobalKey<AnimatedReorderableState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedReorderable.grid(
              key: key,
              keyGetter: (index) => ValueKey(items[index]),
              // Slow, so the item is still on its way once a long press
              // holds it.
              motion: const MotionOptions(duration: Duration(seconds: 3)),
              reorder: ReorderOptions(
                onReorder: (permutations) => permutations.apply(items),
              ),
              gridView: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    _Item(id: items[index], onInit: () {}),
              ),
            ),
          ),
        ),
      );
      Offset middle() => tester.getCenter(_itemWithId(0));

      key.currentState!.reorderItem(0, destIndex: 4);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final middles = [middle()];
      final drag = await tester.startGesture(middles.first);
      // It goes on in place until the long press holds it, from where it
      // shows then.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        middles.add(middle());
      }

      expect(overlayed(tester), [0]);
      final distances = [
        for (var i = 1; i < middles.length; i++)
          (middles[i] - middles[i - 1]).distance,
      ];
      expect(distances, everyElement(lessThan(10)));
      final held = middle();
      await drag.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(middle(), held + const Offset(0, 40));
      await drag.up();
      await tester.pumpAndSettle();
    });

    testWidgets('gives each item its semantic index, once', (tester) async {
      final list = _TestList(10);
      await tester.pumpWidget(list.build());

      final indexes = [
        for (final semantics in tester.widgetList<IndexedSemantics>(
          find.byType(IndexedSemantics),
        ))
          semantics.index,
      ];

      expect(indexes.take(6), [0, 1, 2, 3, 4, 5]);
      expect(indexes.toSet(), hasLength(indexes.length));
    });

    testWidgets('moves an item that goes out of sight on its way in place '
        'on from where it shows', (tester) async {
      final list = _TestList(10);
      await tester.pumpWidget(list.build());
      list.state.reorderItem(2, destIndex: 4);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final tops = [tester.getTopLeft(_itemWithId(2)).dy];

      // Three items in at the top push its slot out of sight.
      for (final id in [10, 11, 12]) {
        list.insert(0, id);
      }
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        tops.add(tester.getTopLeft(_itemWithId(2)).dy);
      }

      // Items 4 and 5 go out of sight with it.
      expect(overlayed(tester), [2, 4, 5]);
      expect(_steps(tops), everyElement(inInclusiveRange(0, 40)));
      await tester.pumpAndSettle();
    });

    testWidgets('moves an item an insert pushes out of sight through the '
        'overlay', (tester) async {
      final list = _TestList(10);
      await tester.pumpWidget(list.build());

      list.insert(3, 100);
      await tester.pump();

      // Items 3 and 4 move down in place, and 6 to 8 stay out of sight.
      final lifted = overlayed(tester);
      await tester.pumpAndSettle();

      expect(lifted, [5]);
    });

    testWidgets('moves an item a remove brings into sight in place', (
      tester,
    ) async {
      final list = _TestList(10);
      await tester.pumpWidget(list.build());

      list.removeAt(3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Item 3 fades out under the list, and 4 to 6 move up in place: 6
      // from out of sight.
      expect(overlayed(tester), [3]);
      expect(tester.getTopLeft(_itemWithId(6)).dy, greaterThan(5 * _extent));
      expect(tester.getTopLeft(_itemWithId(6)).dy, lessThan(600));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_itemWithId(6)).dy, 5 * _extent);
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

    testWidgets('lifts an item held again above the items flying back', (
      tester,
    ) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());
      // Item 0 and then item 2 are let go, and fly back to their slots.
      for (final id in [0, 2]) {
        final drag = await _holdAndDrag(tester, find.text('$id'), 1);
        await drag.up();
        await tester.pump();
      }

      final drag = await tester.startGesture(tester.getCenter(find.text('0')));
      await drag.moveBy(const Offset(0, 40));
      await tester.pump();

      // It follows the pointer, so it was held again on its way back.
      expect(tester.getTopLeft(find.text('0')).dy, greaterThan(20));
      expect(_paintOrder(tester).last, 0);
      await drag.up();
      await tester.pumpAndSettle();
    });

    testWidgets('shows a removed item under the moving items', (tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());

      list.removeAt(1);
      await tester.pump();

      // Items 2 to 4 move up, and item 0 stays in its slot. It shows under
      // them all, the list's own items too.
      final order = _paintOrder(tester);
      for (final id in [2, 3, 4]) {
        expect(order.indexOf(1), lessThan(order.indexOf(id)), reason: '$id');
      }
      expect(order.first, 1);
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

    testWidgets('keeps an item swiped away above the items it flies over', (
      tester,
    ) async {
      // Item 1, in the middle column, flies out over item 0.
      final list = _TestList(6, grid: true);
      await tester.pumpWidget(list.build());

      await tester.timedDrag(
        _itemWithId(1),
        const Offset(-800 / 3 * 0.7, 0),
        const Duration(seconds: 1),
      );
      await tester.pump();

      expect(list.items, isNot(contains(1)));
      final order = _paintOrder(tester);
      expect(order.indexOf(0), lessThan(order.indexOf(1)));
      expect(order.last, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('keeps an item removed on its way out of sight above the '
        'list', (tester) async {
      final list = _TestList(10);
      await tester.pumpWidget(list.build());
      // Item 0 goes out of sight through the overlay, above the list.
      list.state.reorderItem(0, destIndex: 8);
      await tester.pump();
      await tester.pump(_motionDuration * 0.3);
      expect(_paintOrder(tester).last, 0);

      list.removeAt(8);
      await tester.pump();

      expect(_paintOrder(tester).last, 0);
      await tester.pumpAndSettle();
    });
  });

  group('paints', () {
    testWidgets('paints each item on one layer of its own', (tester) async {
      final list = _TestList(10);
      await tester.pumpWidget(list.build());

      for (final id in [0, 5]) {
        var layers = 0;
        for (
          RenderObject? node = tester.renderObject(_itemWithId(id));
          node != null && node is! RenderSliver;
          node = node.parent
        ) {
          if (node.isRepaintBoundary) layers++;
        }
        expect(layers, 1, reason: '$id');
      }
    });

    testWidgets('paints a moving item on a layer of its own, where it is', (
      tester,
    ) async {
      final list = _TestList(10);
      await tester.pumpWidget(list.build());

      list.state.reorderItem(0, destIndex: 4);
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          _paintedTopLeft(tester, _itemWithId(0)),
          tester.getTopLeft(_itemWithId(0)),
        );
      }

      expect(tester.getTopLeft(_itemWithId(0)).dy, greaterThan(0));
      await tester.pumpAndSettle();
    });

    testWidgets('moves an item without painting it again', (tester) async {
      var paints = 0;
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
                itemBuilder: (context, index) => SizedBox(
                  height: _extent,
                  child: CustomPaint(painter: _PaintCounter(() => paints++)),
                ),
              ),
            ),
          ),
        ),
      );

      key.currentState!.reorderItem(0, destIndex: 4);
      // The moving items paint once as they enter the overlay.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      paints = 0;
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(tester.hasRunningAnimations, isTrue);
      expect(paints, 0);
      await tester.pumpAndSettle();
    });
  });

  group('builds', () {
    /// A list of 10 items that tells which items it built.
    Widget buildList(
      GlobalKey<AnimatedReorderableState> key,
      List<int> items,
      Set<int> built,
    ) => AnimatedReorderable.list(
      key: key,
      keyGetter: (index) => ValueKey(items[index]),
      reorder: ReorderOptions(
        onReorder: (permutations) => permutations.apply(items),
      ),
      listView: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          built.add(items[index]);
          return SizedBox(height: _extent, child: Text('${items[index]}'));
        },
      ),
    );

    testWidgets('builds only the items a change moves', (tester) async {
      final built = <int>{};
      final items = List.generate(10, (i) => i);
      final key = GlobalKey<AnimatedReorderableState>();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: buildList(key, items, built))),
      );
      built.clear();

      key.currentState!.reorderItem(2, destIndex: 4);
      await tester.pumpAndSettle();

      expect(built, {2, 3, 4});
    });

    testWidgets('builds every item again when the app builds its view again', (
      tester,
    ) async {
      final built = <int>{};
      final items = List.generate(10, (i) => i);
      final key = GlobalKey<AnimatedReorderableState>();
      late StateSetter setState;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setter) {
                setState = setter;
                return buildList(key, items, built);
              },
            ),
          ),
        ),
      );
      final shown = {...built};
      built.clear();

      setState(() {});
      await tester.pump();

      expect(built, shown);
    });

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

      expect(builds, lessThanOrEqualTo(10));
      // The move starts in the frame that lays the items out in their new
      // slots.
      expect(frames, (_motionDuration.inMilliseconds / 16).ceil());
    });

    testWidgets('builds no item while items move', (tester) async {
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

      key.currentState!.reorderItem(0, destIndex: 3);
      // The overlay builds the moving items as they enter it, and the list
      // builds the item that stays once it leaves the overlay.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      builds = 0;
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(tester.hasRunningAnimations, isTrue);
      expect(builds, 0);
      await tester.pumpAndSettle();
    });

    testWidgets('builds moving items with the latest item builder', (
      tester,
    ) async {
      final items = [0, 1, 2, 3, 4];
      final key = GlobalKey<AnimatedReorderableState>();
      Widget build(String label) => MaterialApp(
        home: Scaffold(
          body: AnimatedReorderable.list(
            key: key,
            keyGetter: (index) => ValueKey(items[index]),
            reorder: ReorderOptions(
              onReorder: (permutations) => permutations.apply(items),
            ),
            listView: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => SizedBox(
                height: _extent,
                child: Text('$label ${items[index]}'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(build('old'));
      key.currentState!.reorderItem(0, destIndex: 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.pumpWidget(build('new'));

      expect(tester.hasRunningAnimations, isTrue);
      for (final id in [0, 1, 2, 3]) {
        expect(find.text('new $id'), findsOneWidget, reason: 'item $id');
      }
      await tester.pumpAndSettle();
    });

    testWidgets('builds a moving item that is removed with its removed item '
        'builder', (tester) async {
      final grid = _TestList(9, grid: true);
      await tester.pumpWidget(grid.build());
      grid.state.reorderItem(0, destIndex: 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Item 2 moves, as a grid item with the constraints it fades out with.
      final index = grid.items.indexOf(2);
      grid.items.removeAt(index);
      grid.state.removeItem(
        index,
        (context, animation) => const Text('removed'),
      );
      await tester.pump();

      expect(find.text('removed'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('builds moving items again when their indexes change', (
      tester,
    ) async {
      final items = [0, 1, 2, 3, 4, 5];
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
                itemBuilder: (context, index) => SizedBox(
                  height: _extent,
                  child: Text('${items[index]} at $index'),
                ),
              ),
            ),
          ),
        ),
      );
      // Every item the list shows moves.
      key.currentState!.reorderItem(0, destIndex: 5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Each moves on by a slot, and builds at its new index.
      items.insert(0, 100);
      key.currentState!.insertItem(0);
      await tester.pump();

      expect(tester.hasRunningAnimations, isTrue);
      for (final id in [1, 2, 3, 4, 5]) {
        expect(find.text('$id at $id'), findsOneWidget, reason: 'item $id');
      }
      await tester.pumpAndSettle();
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

  testWidgets('moves the items before a removed one down into its place as '
      'the list clamps', (tester) async {
    final list = _TestList(10);
    await tester.pumpWidget(list.build());
    final position = _scrollPosition(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    double top(int id) => tester.getTopLeft(find.text('$id')).dy;
    final before = [top(4)];
    final after = [top(6)];

    // The list shrinks under its offset, which comes back by an item: the
    // items after the removed one stay where they show, and those before
    // it come down into its place rather than jump there.
    list.removeAt(5);
    while (tester.binding.hasScheduledFrame) {
      await tester.pump(const Duration(milliseconds: 16));
      before.add(top(4));
      after.add(top(6));
    }

    expect(after, everyElement(moreOrLessEquals(after.first)));
    expect(_steps(before), everyElement(inInclusiveRange(0, 20)));
    expect(before.last, before.first + _extent);
  });

  testWidgets('moves an item that comes down on its way as another removal '
      'clamps the list', (tester) async {
    final list = _TestList(10);
    await tester.pumpWidget(list.build());
    final position = _scrollPosition(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    final tops = [tester.getTopLeft(find.text('4')).dy];

    list.removeAt(5);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      tops.add(tester.getTopLeft(find.text('4')).dy);
    }
    list.removeAt(5);
    while (tester.binding.hasScheduledFrame) {
      await tester.pump(const Duration(milliseconds: 16));
      tops.add(tester.getTopLeft(find.text('4')).dy);
    }

    expect(_steps(tops), everyElement(inInclusiveRange(0, 25)));
    expect(tops.last, tops.first + 2 * _extent);
  });

  testWidgets('moves the items with the content as a resize clamps the '
      'list', (tester) async {
    final list = _TestList(10);
    await tester.pumpWidget(list.build());
    final position = _scrollPosition(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(find.text('4')).dy;

    // The view grows by an item under the list's offset, as any view's.
    _resize(tester, const Size(800, 700));
    await tester.pump();

    expect(tester.getTopLeft(find.text('4')).dy, top + _extent);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('moves the items in sight a slot as an item goes or comes far '
      'above them', (tester) async {
    final list = _TestList(50);
    await tester.pumpWidget(list.build());
    _scrollPosition(tester).jumpTo(20 * _extent);
    await tester.pumpAndSettle();
    double top() => tester.getTopLeft(find.text('22')).dy;
    final tops = [top()];

    list.removeAt(0);
    while (tester.binding.hasScheduledFrame) {
      await tester.pump(const Duration(milliseconds: 16));
      tops.add(top());
    }
    expect(_steps(tops), everyElement(inInclusiveRange(-20, 0)));
    expect(tops.last, tops.first - _extent);

    list.insert(0, 100);
    tops.removeRange(0, tops.length - 1);
    while (tester.binding.hasScheduledFrame) {
      await tester.pump(const Duration(milliseconds: 16));
      tops.add(top());
    }
    expect(_steps(tops), everyElement(inInclusiveRange(0, 20)));
    expect(tops.last, tops.first + _extent);
  });

  testWidgets(
    'moves the items of a grid down a row as a removal of its '
    'last row clamps it',
    (tester) async {
      final list = _TestList(10, grid: true);
      await tester.pumpWidget(list.build());
      final position = _scrollPosition(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final row = tester.getSize(find.byType(_Item).first).height;
      final tops = [tester.getTopLeft(find.text('6')).dy];

      // Item 9 is alone in the last row.
      list.removeAt(9);
      while (tester.binding.hasScheduledFrame) {
        await tester.pump(const Duration(milliseconds: 16));
        tops.add(tester.getTopLeft(find.text('6')).dy);
      }

      expect(_steps(tops), everyElement(inInclusiveRange(0, row / 6)));
      expect(tops.last, moreOrLessEquals(tops.first + row));
      // Whether the physics clamp, or bounce as on macOS and iOS.
    },
    variant: TargetPlatformVariant(const {
      TargetPlatform.android,
      TargetPlatform.macOS,
    }),
  );

  testWidgets('puts a shrink-wrapped list at the start of its space', (
    tester,
  ) async {
    await tester.pumpWidget(_TestList(3, shrinkWrap: true).build());

    expect(tester.getTopLeft(find.text('0')), Offset.zero);
  });

  /// [list] in a column of a scroll view, which gives it no height limit.
  Widget inColumn(_TestList list) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: Column(children: [list.buildList()])),
    ),
  );

  testWidgets('drags an item of a shrink-wrapped list in a column', (
    tester,
  ) async {
    final list = _TestList(3, shrinkWrap: true);
    await tester.pumpWidget(inColumn(list));

    final drag = await _holdAndDrag(tester, find.text('0'), 6);
    await drag.up();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(list.items, [1, 0, 2]);
  });

  testWidgets('removes an item of a shrink-wrapped grid in a column', (
    tester,
  ) async {
    final list = _TestList(6, grid: true, shrinkWrap: true);
    await tester.pumpWidget(inColumn(list));

    list.removeAt(0);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('0'), findsNothing);
  });

  testWidgets(
    "keeps a shrink-wrapped grid's rows from jumping as a removal of its "
    'last row leaves it shorter than its space',
    (tester) async {
      final list = _TestList(
        10,
        grid: true,
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.5,
        ),
      );
      await tester.pumpWidget(list.build());
      final position = _scrollPosition(tester);
      final clamp = position.maxScrollExtent;
      position.jumpTo(clamp);
      await tester.pumpAndSettle();
      final row = tester.getSize(find.byType(_Item).first).height;
      final tops = [tester.getTopLeft(find.text('6')).dy];

      // Item 9 is alone in the last row, and the three rows left fit.
      list.removeAt(9);
      while (tester.binding.hasScheduledFrame) {
        await tester.pump(const Duration(milliseconds: 16));
        tops.add(tester.getTopLeft(find.text('6')).dy);
      }

      expect(_steps(tops), everyElement(inInclusiveRange(0, row / 6)));
      expect(tops.last, moreOrLessEquals(tops.first + clamp));
      // At the start of its space, shorter than it.
      expect(tester.getTopLeft(find.text('0')).dy, 0);
    },
    variant: TargetPlatformVariant(const {
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  for (final clipBehavior in [Clip.hardEdge, Clip.none]) {
    testWidgets('clips moving items as the list does, with '
        '${clipBehavior.name}', (tester) async {
      final items = List.generate(50, (i) => i);
      final key = GlobalKey<AnimatedReorderableState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                height: 300,
                child: AnimatedReorderable.list(
                  key: key,
                  keyGetter: (index) => ValueKey(items[index]),
                  reorder: ReorderOptions(
                    onReorder: (permutations) => permutations.apply(items),
                  ),
                  listView: ListView.builder(
                    clipBehavior: clipBehavior,
                    itemCount: items.length,
                    itemBuilder: (context, index) => SizedBox(
                      height: _extent,
                      child: Text('${items[index]}'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      key.currentState!.reorderItem(0, destIndex: 40);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(_motionDuration * 0.7);

      // On its way out through the bottom edge.
      final item = tester.getRect(find.text('0'));
      expect(item.top, lessThan(300));
      expect(item.bottom, greaterThan(300));
      // Both the layer above the list and the one under it.
      final layers = find.byType(OverlayedItemsLayer);
      expect(layers, findsNWidgets(2));
      for (final layer in layers.evaluate()) {
        final renderObject = layer.renderObject!;
        final clip = paints
          ..clipRect(rect: Offset.zero & (renderObject as RenderBox).size);
        expect(renderObject, clipBehavior == Clip.none ? isNot(clip) : clip);
      }
      await tester.pumpAndSettle();
    });
  }

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

    testWidgets('moves an item to its slot when an item above it grows by a '
        'pixel', (tester) async {
      final items = [0, 1, 2, 3, 4];
      final heights = {0: _extent};
      final key = GlobalKey<AnimatedReorderableState>();
      Widget build() => MaterialApp(
        home: Scaffold(
          body: AnimatedReorderable.list(
            key: key,
            keyGetter: (index) => ValueKey(items[index]),
            reorder: ReorderOptions(
              onReorder: (permutations) => permutations.apply(items),
            ),
            listView: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => SizedBox(
                height: heights[items[index]] ?? _extent,
                child: Text('${items[index]}'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(build());
      key.currentState!.reorderItem(1, destIndex: 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      heights[0] = _extent + 1;
      await tester.pumpWidget(build());
      final tops = <double>[];
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        tops.add(tester.getTopLeft(find.text('1')).dy);
      }

      expect(tops.last, 3 * _extent + 1);
      // It eases into the slot rather than jumps there as it lands.
      final steps = [
        for (var i = 1; i < tops.length; i++) (tops[i] - tops[i - 1]).abs(),
      ].where((step) => step > 0);
      expect(steps.last, lessThan(0.5));
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

  group('screen readers', () {
    testWidgets('find items a reorder moves in place in their new slots', (
      tester,
    ) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());
      final slots = _semanticsRects(tester, [0, 1, 2]);
      final node = tester.getSemantics(find.text('0')).id;

      list.state.reorderItem(0, destIndex: 2);
      await tester.pumpAndSettle();

      expect(list.items, [1, 2, 0, 3, 4]);
      expect(_semanticsRects(tester, [1, 2, 0]), slots);
      // The screen reader stays on the item it was on.
      expect(tester.getSemantics(find.text('0')).id, node);
    });

    const allMoves = [
      'Move to the start',
      'Move up',
      'Move down',
      'Move to the end',
    ];

    testWidgets('can move each item', (tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());

      expect(
        _moves(tester, 0),
        unorderedEquals(['Move down', 'Move to the end']),
      );
      expect(_moves(tester, 2), unorderedEquals(allMoves));
      expect(
        _moves(tester, 4),
        unorderedEquals(['Move to the start', 'Move up']),
      );
      // Under the item's index, as in ReorderableList.
      expect(tester.getSemantics(find.text('2')).parent!.indexInParent, 2);
    });

    testWidgets('moves an item as a reorder does', (tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());
      final node = tester.getSemantics(find.text('0')).id;

      _move(tester, 0, 'Move down');
      await tester.pump();
      await tester.pump(_motionDuration ~/ 2);

      expect(list.items, [1, 0, 2, 3, 4]);
      expect(list.reorders, 1);
      // On its way in place.
      expect(
        tester.getTopLeft(_itemWithId(0)).dy,
        inExclusiveRange(0, _extent),
      );
      await tester.pumpAndSettle();
      expect(_moves(tester, 0), unorderedEquals(allMoves));
      expect(tester.getSemantics(find.text('0')).id, node);

      _move(tester, 0, 'Move to the end');
      await tester.pumpAndSettle();
      expect(list.items, [1, 2, 3, 4, 0]);

      _move(tester, 0, 'Move up');
      await tester.pumpAndSettle();
      expect(list.items, [1, 2, 3, 0, 4]);

      _move(tester, 0, 'Move to the start');
      await tester.pumpAndSettle();
      expect(list.items, [0, 1, 2, 3, 4]);
      expect(list.reorders, 4);
    });

    testWidgets('names each move after the way it takes the item', (
      tester,
    ) async {
      // Moves the middle one of three items with the move named [name].
      Future<List<int>> move(
        _TestList list,
        String name, {
        TextDirection textDirection = TextDirection.ltr,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Directionality(
                textDirection: textDirection,
                child: list.buildList(),
              ),
            ),
          ),
        );
        _move(tester, 1, name);
        await tester.pumpAndSettle();
        return list.items;
      }

      const forward = [0, 2, 1];
      const back = [1, 0, 2];
      const rtl = TextDirection.rtl;
      expect(await move(_TestList(3), 'Move down'), forward);
      // Up the screen, on to the end of a reversed list.
      expect(await move(_TestList(3, reverse: true), 'Move down'), back);
      final horizontal = Axis.horizontal;
      expect(
        await move(_TestList(3, scrollDirection: horizontal), 'Move right'),
        forward,
      );
      expect(
        await move(
          _TestList(3, scrollDirection: horizontal),
          'Move right',
          textDirection: rtl,
        ),
        back,
      );
      // Along a grid's row.
      expect(await move(_TestList(3, grid: true), 'Move right'), forward);
      expect(
        await move(_TestList(3, grid: true), 'Move right', textDirection: rtl),
        back,
      );
      expect(
        await move(
          _TestList(3, grid: true, scrollDirection: horizontal),
          'Move down',
        ),
        forward,
      );
    });

    testWidgets('keeps the moves of the item at the end up to date', (
      tester,
    ) async {
      final list = _TestList(3);
      await tester.pumpWidget(list.build());
      const atTheEnd = ['Move to the start', 'Move up'];
      expect(_moves(tester, 2), unorderedEquals(atTheEnd));

      list.insert(3, 3);
      await tester.pumpAndSettle();
      expect(_moves(tester, 2), unorderedEquals(allMoves));
      final moveDown = _semanticMove(tester, 2, 'Move down');

      list.removeAt(3);
      await tester.pumpAndSettle();
      expect(_moves(tester, 2), unorderedEquals(atTheEnd));

      // A move it could make before does nothing now.
      moveDown();
      await tester.pumpAndSettle();
      expect(list.items, [0, 1, 2]);
      expect(list.reorders, 0);
    });

    testWidgets('moves an item past items that cannot be reordered', (
      tester,
    ) async {
      final list = _TestList(4)..reorderableGetter = (index) => index != 1;
      await tester.pumpWidget(list.build());

      expect(_moves(tester, 1), isEmpty);
      expect(
        _moves(tester, 0),
        unorderedEquals(['Move down', 'Move to the end']),
      );

      _move(tester, 0, 'Move down');
      await tester.pumpAndSettle();

      expect(list.items, [2, 1, 0, 3]);
    });

    testWidgets('moves an item a row back or forward in a grid', (
      tester,
    ) async {
      // Three rows of three.
      final list = _TestList(9, grid: true);
      await tester.pumpWidget(list.build());

      expect(
        _moves(tester, 4),
        unorderedEquals([
          'Move to the start',
          'Move left',
          'Move up',
          'Move right',
          'Move down',
          'Move to the end',
        ]),
      );
      // No row before the first, or after the last.
      expect(_moves(tester, 1), isNot(contains('Move up')));
      expect(_moves(tester, 7), isNot(contains('Move down')));

      _move(tester, 4, 'Move down');
      await tester.pumpAndSettle();
      expect(list.items.indexOf(4), 7);

      _move(tester, 4, 'Move up');
      await tester.pumpAndSettle();
      expect(list.items, List.generate(9, (i) => i));
    });

    testWidgets('moves an item a row past items that cannot be reordered', (
      tester,
    ) async {
      final list = _TestList(9, grid: true)
        ..reorderableGetter = (index) => index != 7;
      await tester.pumpWidget(list.build());

      _move(tester, 4, 'Move down');
      await tester.pumpAndSettle();

      expect(list.items.indexOf(4), 8);
      expect(list.items[7], 7);
    });

    testWidgets("names a grid's row moves after its scroll axis", (
      tester,
    ) async {
      // Its rows run down the screen, and the next one is to the right.
      final list = _TestList(9, grid: true, scrollDirection: Axis.horizontal);
      await tester.pumpWidget(list.build());

      expect(_moves(tester, 4), containsAll(['Move left', 'Move right']));
      _move(tester, 4, 'Move right');
      await tester.pumpAndSettle();

      expect(list.items.indexOf(4), 7);
    });

    testWidgets('offers no row moves in a grid of one column', (tester) async {
      final list = _TestList(
        3,
        grid: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          childAspectRatio: 4,
        ),
      );
      await tester.pumpWidget(list.build());

      expect(_moves(tester, 1), hasLength(4));
      expect(_moves(tester, 1), isNot(contains('Move up')));
    });

    testWidgets('keeps the row moves up to date as a resize changes the '
        'columns', (tester) async {
      final list = _TestList(
        12,
        grid: true,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
        ),
      );
      await tester.pumpWidget(list.build());
      // Four columns: item 3 ends the first row.
      expect(_moves(tester, 3), isNot(contains('Move up')));

      // Three: it starts the second.
      _resize(tester, const Size(600, 600));
      await tester.pump();
      await tester.pump();

      expect(_moves(tester, 3), contains('Move up'));
      _move(tester, 3, 'Move up');
      await tester.pumpAndSettle();
      expect(list.items.indexOf(3), 0);
    });

    testWidgets('cannot move an item that cannot be dragged', (tester) async {
      final list = _TestList(3)..draggableGetter = (index) => index != 0;
      await tester.pumpWidget(list.build());

      expect(_moves(tester, 0), isEmpty);
      // Another item can still take its place.
      _move(tester, 1, 'Move up');
      await tester.pumpAndSettle();

      expect(list.items, [1, 0, 2]);
    });

    testWidgets('cannot move items without onReorder', (tester) async {
      await tester.pumpWidget(_labels(const ['a', 'b', 'c']));

      expect(_moves(tester, 'b'), isEmpty);
    });

    testWidgets("names the moves in the app's language", (tester) async {
      final list = _TestList(2);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [_GermanMoves.delegate],
          home: Scaffold(body: list.buildList()),
        ),
      );

      expect(
        _moves(tester, 0),
        unorderedEquals(['Nach unten verschieben', 'An das Ende verschieben']),
      );
    });

    testWidgets('names the moves without localizations', (tester) async {
      final list = _TestList(2);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: list.buildList(),
        ),
      );

      expect(
        _moves(tester, 0),
        unorderedEquals(['Move down', 'Move to the end']),
      );
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
      await tester.pump(_insertDuration ~/ 2);
      expect(_entranceOf(tester, 3).value, closeTo(0.5, 0.01));
      await tester.pumpAndSettle();

      expect(_entranceOf(tester, 3).value, 1);
    });

    testWidgets('builds every other item through it, complete', (tester) async {
      final list = _TestList(3, insertTransition: enter);
      await tester.pumpWidget(list.build());

      list.insert(0, 3);
      await tester.pump();
      await tester.pump(_insertDuration ~/ 2);

      expect([
        for (final id in [0, 1, 2]) _entranceOf(tester, id).value,
      ], everyElement(1));
    });

    testWidgets('enters a grid', (tester) async {
      final list = _TestList(6, grid: true, insertTransition: enter);
      await tester.pumpWidget(list.build());

      list.insert(0, 6);
      await tester.pump();
      await tester.pump(_insertDuration ~/ 2);

      expect(_entranceOf(tester, 6).value, closeTo(0.5, 0.01));
    });

    testWidgets('keeps the state of an item that has entered', (tester) async {
      final list = _TestList(3, insertTransition: enter);
      await tester.pumpWidget(list.build());

      list.insert(0, 3);
      await tester.pump();
      await tester.pump(_insertDuration ~/ 2);
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
      expect(
        _entranceOf(tester, 3).value,
        closeTo(200 / _insertDuration.inMilliseconds, 0.01),
      );
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
      await tester.pump(_insertDuration ~/ 2);
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
      await tester.pump(_insertDuration ~/ 2);
      await tester.pumpWidget(const SizedBox());

      expect(controllers, isEmpty);
    });

    testWidgets('uses the latest transition', (tester) async {
      final list = _TestList(3, insertTransition: enter);
      await tester.pumpWidget(list.build());

      list.insert(0, 3);
      await tester.pump();
      await tester.pump(_insertDuration ~/ 2);
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

    for (final (cause, change) in [
      // It builds the items that come into sight.
      (
        'its list scrolls',
        (WidgetTester tester, _TestList list) async =>
            _scrollPosition(tester).jumpTo(60),
      ),
      // As an app that sets state as a drag ends does.
      (
        'the app builds the list again',
        (WidgetTester tester, _TestList list) =>
            tester.pumpWidget(list.build()),
      ),
    ]) {
      testWidgets('fades an item let go back in as $cause', (tester) async {
        final list = _TestList(60);
        await tester.pumpWidget(list.build());
        double opacity() => tester
            .widget<FadeTransition>(
              find
                  .ancestor(
                    of: find.text('1'),
                    matching: find.byType(FadeTransition),
                  )
                  .first,
            )
            .opacity
            .value;

        // Held in its place until it has faded, and let go there.
        final drag = await _holdAndDrag(tester, find.text('1'), 0);
        await tester.pump(const Duration(seconds: 1));
        await drag.up();
        final opacities = [opacity()];
        for (var i = 0; i < 40; i++) {
          if (i == 2) await change(tester, list);
          await tester.pump(const Duration(milliseconds: 16));
          opacities.add(opacity());
        }

        expect(opacities.first, lessThan(0.75));
        expect(opacities.last, 1);
        expect([
          for (var i = 1; i < opacities.length; i++)
            opacities[i] - opacities[i - 1],
        ], everyElement(inInclusiveRange(0, 0.05)));
      });
    }

    testWidgets('keeps a list in an item working after the item is dragged', (
      tester,
    ) async {
      final inner = _TestList(2);
      final sections = ['a', 'b'];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedReorderable.list(
              keyGetter: (index) => ValueKey(sections[index]),
              reorder: ReorderOptions(
                onReorder: (permutations) => permutations.apply(sections),
              ),
              listView: ListView.builder(
                itemCount: sections.length,
                itemBuilder: (context, index) => Column(
                  children: [
                    SizedBox(height: 50, child: Text(sections[index])),
                    SizedBox(
                      height: 2 * _extent,
                      child: sections[index] == 'a' ? inner.buildList() : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Section a, by its header, after section b: the outer list moves it,
      // with the inner list, into its layer and back.
      final outer = await _holdAndDrag(tester, find.text('a'), 15);
      await outer.up();
      await tester.pumpAndSettle();
      expect(sections, ['b', 'a']);

      final drag = await _holdAndDrag(tester, find.text('0'), 6);
      await drag.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(inner.items, [1, 0]);
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

  group('landing', () {
    /// The tops of the item [finder] finds over [frames] frames.
    Future<List<double>> track(
      WidgetTester tester,
      Finder finder,
      int frames,
    ) async {
      final tops = <double>[];
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        tops.add(tester.getTopLeft(finder).dy);
      }
      return tops;
    }

    /// How far an item at [tops], one a frame, moves each frame.
    List<double> steps(List<double> tops) => [
      for (var i = 1; i < tops.length; i++) tops[i] - tops[i - 1],
    ];

    testWidgets('moves an item on when its place moves as it gets there', (
      tester,
    ) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());
      list.state.reorderItem(0, destIndex: 1);
      await tester.pump();
      // It moves from this frame on, and is in its new place at the end.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(_motionDuration);
      final tops = [tester.getTopLeft(_itemWithId(1)).dy];

      // Its move ends on the next frame, before the list lays it out in
      // the place it moves to now.
      list.state.reorderItem(1, destIndex: 0);
      tops.addAll(await track(tester, _itemWithId(1), 40));

      expect(tops.first, 0);
      expect(tops.last, _extent);
      expect(steps(tops), everyElement(inInclusiveRange(0, 20)));
    });

    testWidgets('moves an item let go on when its place moves as it gets '
        'back', (tester) async {
      /// Lets item 0 go a little way from its slot, and counts the frames
      /// it takes to fly back, or flies it back for [frames] frames.
      Future<(_TestList, int)> letGo({int? frames}) async {
        final list = _TestList(5);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(list.build());
        final drag = await _holdAndDrag(tester, find.text('0'), 1);
        await drag.up();
        var flown = 0;
        while (frames == null ? tester.hasRunningAnimations : flown < frames) {
          await tester.pump(const Duration(milliseconds: 16));
          flown++;
        }
        return (list, flown);
      }

      final (_, frames) = await letGo();
      final (list, _) = await letGo(frames: frames - 1);
      final tops = [tester.getTopLeft(_itemWithId(0)).dy];
      // It gets back on the next frame, before the list lays it out in the
      // place it moves to now.
      list.state.reorderItem(1, destIndex: 0);
      tops.addAll(await track(tester, _itemWithId(0), 40));

      expect(tops.first, moreOrLessEquals(0, epsilon: 0.5));
      expect(tops.last, _extent);
      // Up the last bit of the way back, then down to the new place.
      expect(steps(tops), everyElement(inInclusiveRange(-0.5, 20)));
    });
  });

  group('fling', () {
    const frame = Duration(milliseconds: 16);

    /// How far the default spring takes an item let go [way] px from its
    /// place, moving toward it at [speed] px a frame, from the first frame
    /// of its fling to the next.
    double firstStep(double way, {required double speed}) {
      double seconds(Duration duration) =>
          duration.inMicroseconds / Duration.microsecondsPerSecond;
      return SpringSimulation(
        _defaultSpring,
        0,
        way,
        speed / seconds(frame),
      ).x(seconds(frame));
    }

    /// Swipes item 1 [distance] px along [forward], and lets it go moving
    /// back at [speed] px a frame. Returns where it is let go.
    Future<Offset> swipeAndLetGo(
      WidgetTester tester,
      Offset forward, {
      required double distance,
      required double speed,
    }) async {
      // The pointer's speed at the end comes from the times of its moves.
      var time = Duration.zero;
      final swipe = await tester.createGesture();
      await swipe.down(tester.getCenter(_itemWithId(1)), timeStamp: time);
      Future<void> move(Offset offset) async {
        time += frame;
        await swipe.moveBy(offset, timeStamp: time);
        await tester.pump(frame);
      }

      // Long enough back that the pointer's speed is all it goes at.
      for (var i = 0; i < (distance + 8 * speed) / 10; i++) {
        await move(forward * 10);
      }
      for (var i = 0; i < 8; i++) {
        await move(-forward * speed);
      }
      final letGo = tester.getTopLeft(_itemWithId(1));
      await swipe.up(timeStamp: time);
      return letGo;
    }

    /// Where item 1 is after each frame until it settles.
    Future<List<Offset>> track(WidgetTester tester) async {
      final path = <Offset>[];
      while (tester.binding.hasScheduledFrame) {
        await tester.pump(frame);
        path.add(tester.getTopLeft(_itemWithId(1)));
      }
      return path;
    }

    for (final (scrollDirection, direction) in [
      (Axis.vertical, AxisDirection.left),
      (Axis.horizontal, AxisDirection.up),
    ]) {
      group(direction.name, () {
        final forward = _unit(direction);

        /// How far item 1 gets back toward its place over 4 frames, once
        /// it is swiped 200 px away and let go moving back at [speed] px a
        /// frame. A short swipe like this flings it back.
        Future<double> wayBack(
          WidgetTester tester, {
          required double speed,
        }) async {
          final list = _TestList(
            10,
            scrollDirection: scrollDirection,
            swipeToRemoveDirection: direction,
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(list.build());
          final letGo = await swipeAndLetGo(
            tester,
            forward,
            distance: 200,
            speed: speed,
          );
          for (var i = 0; i < 4; i++) {
            await tester.pump(frame);
          }
          final back = letGo - tester.getTopLeft(_itemWithId(1));
          await tester.pumpAndSettle();
          expect(list.items, List.generate(10, (i) => i));
          return back.dx * forward.dx + back.dy * forward.dy;
        }

        testWidgets('flings an item let go moving toward its place on '
            'toward it', (tester) async {
          final still = await wayBack(tester, speed: 0);
          final toward = await wayBack(tester, speed: 30);

          expect(toward, greaterThan(still + 1));
        });

        testWidgets('flings an item let go moving away from its place on '
            'away first', (tester) async {
          final still = await wayBack(tester, speed: 0);
          final away = await wayBack(tester, speed: -10);

          expect(away, lessThan(still - 1));
        });
      });
    }

    testWidgets('flings an item on at the speed it is let go', (tester) async {
      final list = _TestList(10);
      await tester.pumpWidget(list.build());

      // Moving back to its place at 30 px a frame.
      final letGo = await swipeAndLetGo(
        tester,
        const Offset(-1, 0),
        distance: 200,
        speed: 30,
      );
      final xs = [letGo.dx];
      for (var i = 0; i < 3; i++) {
        await tester.pump(frame);
        xs.add(tester.getTopLeft(_itemWithId(1)).dx);
      }

      // The first frame of a fling shows the item where it was let go,
      // and the next one where the spring takes it from there at that
      // speed, rather than from rest.
      expect(_steps(xs)[1], closeTo(firstStep(200, speed: 30), 2));
      expect(
        firstStep(200, speed: 30) - firstStep(200, speed: 0),
        greaterThan(5),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('flings an item let go after a drag on at the speed it is '
        'let go', (tester) async {
      final list = _TestList(10);
      await tester.pumpWidget(list.build());
      final slot = tester.getCenter(_itemWithId(1));
      // Its middle, which the decoration of a dragged item doesn't move.
      double middle() => tester.getCenter(_itemWithId(1)).dx;

      var time = Duration.zero;
      final drag = await tester.createGesture();
      await drag.down(slot, timeStamp: time);
      const hold = Duration(milliseconds: 600);
      await tester.pump(hold);
      time += hold;
      Future<void> move(Offset offset) async {
        time += frame;
        await drag.moveBy(offset, timeStamp: time);
        await tester.pump(frame);
      }

      // Across its row, where no other item is, and back at 30 px a frame,
      // long enough that it is all it goes at, to 50 px from its place.
      for (var i = 0; i < 29; i++) {
        await move(const Offset(10, 0));
      }
      for (var i = 0; i < 8; i++) {
        await move(const Offset(-30, 0));
      }
      final xs = [middle()];
      await drag.up(timeStamp: time);
      for (var i = 0; i < 3; i++) {
        await tester.pump(frame);
        xs.add(middle());
      }

      // The first frame of a fling shows the item where it was let go,
      // and the next one where the spring takes it from there at that
      // speed, rather than from rest.
      expect(-_steps(xs)[1], closeTo(firstStep(50, speed: 30), 2));
      expect(
        firstStep(50, speed: 30) - firstStep(50, speed: 0),
        greaterThan(5),
      );
      await tester.pumpAndSettle();
      expect(tester.getCenter(_itemWithId(1)), slot);
      expect(list.reorders, 0);
    });

    // A fling is a spring's: it doesn't stop at either end of its way.
    testWidgets('lets a bouncy spring take an item back past its place', (
      tester,
    ) async {
      final list = _TestList(
        10,
        swipeToRemoveSpringDescription: SpringDescription.withDampingRatio(
          mass: 1,
          stiffness: 500,
          ratio: 0.2,
        ),
      );
      await tester.pumpWidget(list.build());
      final slot = tester.getTopLeft(_itemWithId(1));

      await swipeAndLetGo(tester, const Offset(-1, 0), distance: 200, speed: 0);
      final path = await track(tester);

      expect(list.items, List.generate(10, (i) => i));
      expect(path.last, slot);
      expect(path.map((p) => p.dx).reduce(math.max), greaterThan(slot.dx));
    });

    testWidgets('lets a bouncy spring take an item let go after a drag back '
        'past its place', (tester) async {
      final list = _TestList(
        10,
        reorderSpringDescription: SpringDescription.withDampingRatio(
          mass: 1,
          stiffness: 500,
          ratio: 0.2,
        ),
      );
      await tester.pumpWidget(list.build());
      final slot = tester.getCenter(_itemWithId(1));
      // Its middle, which the decoration of a dragged item doesn't move.
      double middle() => tester.getCenter(_itemWithId(1)).dx;

      // Across its row, where no other item is, held still, and let go.
      var time = Duration.zero;
      final drag = await tester.createGesture();
      await drag.down(slot, timeStamp: time);
      const hold = Duration(milliseconds: 600);
      await tester.pump(hold);
      time += hold;
      for (var i = 0; i < 20; i++) {
        time += frame;
        await drag.moveBy(const Offset(10, 0), timeStamp: time);
        await tester.pump(frame);
      }
      time += const Duration(milliseconds: 200);
      await tester.pump(const Duration(milliseconds: 200));
      await drag.up(timeStamp: time);
      final xs = <double>[];
      while (tester.binding.hasScheduledFrame) {
        await tester.pump(frame);
        xs.add(middle());
      }

      expect(list.reorders, 0);
      expect(xs.last, slot.dx);
      expect(xs.reduce(math.min), lessThan(slot.dx - 1));
    });

    testWidgets('carries an item let go moving away from its place on before '
        'it heads back', (tester) async {
      final list = _TestList(
        10,
        swipeToRemoveSpringDescription: const SpringDescription(
          mass: 10,
          stiffness: 50,
          damping: 45,
        ),
      );
      await tester.pumpWidget(list.build());
      final slot = tester.getTopLeft(_itemWithId(1));

      final letGo = await swipeAndLetGo(
        tester,
        const Offset(-1, 0),
        distance: 200,
        speed: -10,
      );
      final path = await track(tester);

      expect(list.items, List.generate(10, (i) => i));
      expect(path.last, slot);
      expect(path.map((p) => p.dx).reduce(math.min), lessThan(letGo.dx));
    });
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
          // Within the removal, which ends with the item out of sight.
          for (var i = 0; i < 11; i++) {
            await tester.pump(_insertDuration ~/ 12);
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

    // Out of sight, the list has not built the item, so the package works
    // out where it comes in from before the item is built.
    group('builds an item it brings in from out of sight under', () {
      for (final (ancestor, buildItem) in <(String, Widget Function(int))>[
        (
          'a Material, as a ListTile needs',
          (id) => ListTile(title: Text('$id')),
        ),
        (
          'a MediaQuery, as a CircleAvatar needs',
          (id) => SizedBox(height: 56, child: CircleAvatar(child: Text('$id'))),
        ),
        (
          'an inherited widget of the app',
          (id) => Builder(
            builder: (context) => SizedBox(
              height: context
                  .dependOnInheritedWidgetOfExactType<_Extent>()!
                  .value,
              child: Text('$id'),
            ),
          ),
        ),
      ]) {
        group(ancestor, () {
          late List<int> items;
          final key = GlobalKey<AnimatedReorderableState>();
          Future<void> pumpList(WidgetTester tester) async {
            items = List.generate(1000, (i) => i);
            await tester.pumpWidget(
              MaterialApp(
                home: _Extent(
                  value: 64,
                  child: Scaffold(
                    body: AnimatedReorderable.list(
                      key: key,
                      keyGetter: (index) => ValueKey(items[index]),
                      reorder: ReorderOptions(
                        onReorder: (permutations) => permutations.apply(items),
                      ),
                      listView: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            buildItem(items[index]),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          testWidgets('from below', (tester) async {
            await pumpList(tester);

            key.currentState!.reorderItem(999, destIndex: 0);
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(items.first, 999);
            expect(find.text('999'), findsOneWidget);
          });

          testWidgets('from above', (tester) async {
            await pumpList(tester);
            final scroll = _scrollPosition(tester);
            scroll.jumpTo(scroll.maxScrollExtent);
            await tester.pumpAndSettle();

            key.currentState!.reorderItem(0, destIndex: 999);
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(items.last, 0);
            expect(find.text('0'), findsOneWidget);
          });
        });
      }
    });

    // The list lays the item out in its slot before it moves, so it comes in
    // at its own size, however much bigger than the others it is.
    testWidgets('brings an item in from just outside the view, at its own '
        'size', (tester) async {
      final items = List.generate(50, (i) => i);
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
                itemBuilder: (context, index) => SizedBox(
                  height: items[index] == 0 ? 2 * _extent : _extent,
                  child: Text('${items[index]}'),
                ),
              ),
            ),
          ),
        ),
      );
      final scroll = _scrollPosition(tester);
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();

      key.currentState!.reorderItem(0, destIndex: 49);
      final tops = <double>[];
      while (tester.binding.hasScheduledFrame) {
        await tester.pump(const Duration(milliseconds: 16));
        tops.add(tester.getTopLeft(find.text('0')).dy);
        expect(tester.getSize(find.text('0')).height, 2 * _extent);
      }

      expect(tops.first, -2 * _extent);
      expect(tops.last, 500);
      expect(_steps(tops), everyElement(greaterThanOrEqualTo(0)));
    });

    testWidgets('keeps an item from out of sight as big as its slot when '
        'the theme sizes it', (tester) async {
      final items = List.generate(50, (i) => i);
      final key = GlobalKey<AnimatedReorderableState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 60)),
          ),
          home: Scaffold(
            body: AnimatedReorderable.list(
              key: key,
              keyGetter: (index) => ValueKey(items[index]),
              reorder: ReorderOptions(
                onReorder: (permutations) => permutations.apply(items),
              ),
              listView: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) => Text('${items[index]}'),
              ),
            ),
          ),
        ),
      );
      final slot = tester.getSize(find.text('0'));

      key.currentState!.reorderItem(40, destIndex: 0);
      await _pathUntilSettled(
        tester,
        find.text('40'),
        onFrame: () {
          if (find.text('40').evaluate().isNotEmpty) {
            expect(tester.getSize(find.text('40')), slot);
          }
        },
      );

      expect(items.first, 40);
    });

    testWidgets('lets an item a reorder moved out of sight come into sight '
        'later as any item does', (tester) async {
      final list = _TestList(50);
      await tester.pumpWidget(list.build());

      // Neither slot shows.
      list.state.reorderItem(45, destIndex: 46);
      await tester.pumpAndSettle();
      final scroll = _scrollPosition(tester);
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pump();

      expect(tester.hasRunningAnimations, isFalse);
      final bottom = tester.getTopLeft(_itemWithId(49)).dy;
      expect(tester.getTopLeft(_itemWithId(45)).dy, bottom - 3 * _extent);
      expect(tester.getTopLeft(_itemWithId(46)).dy, bottom - 4 * _extent);
    });

    testWidgets('brings a grid item in from out of sight along its column', (
      tester,
    ) async {
      final list = _TestList(60, grid: true);
      await tester.pumpWidget(list.build());
      // The first of three columns, not the middle one.
      final slot = tester.getTopLeft(_itemWithId(0));
      expect(slot.dx, 0);

      list.state.reorderItem(50, destIndex: 0);
      final path = await _pathUntilSettled(tester, _itemWithId(50));

      _expectStraightPath(path, Offset(slot.dx, 600), slot);
    });

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

    for (final step in [0.1, 1 / 3]) {
      testWidgets('keeps moving items on course while the list scrolls by '
          '${step.toStringAsFixed(2)} px a frame and rebuilds', (tester) async {
        final list = _TestList(30);
        await tester.pumpWidget(list.build());
        final position = _scrollPosition(tester);
        list.state.reorderItem(2, destIndex: 5);

        // Rounding leaves the moving items a hair off their slots.
        final frames = _motionDuration.inMilliseconds ~/ 16 + 3;
        for (var i = 0; i < frames; i++) {
          position.jumpTo(position.pixels + step);
          await tester.pump(const Duration(milliseconds: 16));
          if (i.isOdd) await tester.pumpWidget(list.build());
        }

        expect(tester.hasRunningAnimations, isFalse);
      });
    }
  });

  group('moving again', () {
    /// The tops of the item [finder] finds over [frames] frames.
    Future<List<double>> track(
      WidgetTester tester,
      Finder finder,
      int frames,
    ) async {
      final tops = <double>[];
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        tops.add(tester.getTopLeft(finder).dy);
      }
      return tops;
    }

    testWidgets('moves items at once when animations are off', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final list = _TestList(5);
      await tester.pumpWidget(list.build());

      list.state.reorderItem(0, destIndex: 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      list.state.reorderItem(3, destIndex: 2);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.getTopLeft(_itemWithId(0)).dy, 2 * _extent);
    });

    testWidgets('keeps an item going as items above it go one by one', (
      tester,
    ) async {
      final list = _TestList(16);
      await tester.pumpWidget(list.build());

      final tops = <double>[];
      for (var i = 0; i < 4; i++) {
        list.removeAt(0);
        tops.addAll(await track(tester, _itemWithId(4), 12));
      }
      tops.addAll(await track(tester, _itemWithId(4), 40));

      expect(tops.last, 0);
      expect(_steps(tops), everyElement(lessThanOrEqualTo(0)));
      expect(_deadStops(tops), isEmpty);
    });

    testWidgets('keeps an item going as items come in above it one by one', (
      tester,
    ) async {
      final list = _TestList(8);
      await tester.pumpWidget(list.build());

      final tops = <double>[];
      for (var i = 0; i < 4; i++) {
        list.insert(0, 100 + i);
        tops.addAll(await track(tester, _itemWithId(0), 12));
      }
      tops.addAll(await track(tester, _itemWithId(0), 40));

      expect(tops.last, 4 * _extent);
      expect(_steps(tops), everyElement(greaterThanOrEqualTo(0)));
      expect(_deadStops(tops), isEmpty);
    });

    testWidgets('turns an item around without a dead stop', (tester) async {
      final list = _TestList(5);
      await tester.pumpWidget(list.build());

      list.state.reorderItem(0, destIndex: 1);
      final tops = await track(tester, _itemWithId(1), 10);
      list.state.reorderItem(1, destIndex: 0);
      tops.addAll(await track(tester, _itemWithId(1), 50));

      expect(list.items, [0, 1, 2, 3, 4]);
      expect(tops.last, _extent);
      expect(_deadStops(tops), isEmpty);
    });

    testWidgets('keeps an item moving out of sight on time as the list '
        'changes', (tester) async {
      final list = _TestList(50);
      await tester.pumpWidget(list.build());

      list.state.reorderItem(0, destIndex: 40);
      await tester.pump();
      // It moves from this frame on.
      await tester.pump(const Duration(milliseconds: 200));
      // The list lays out again, and the item heads for the same place.
      list.removeAt(45);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(_motionDuration - const Duration(milliseconds: 8));

      expect(_itemWithId(0), findsNothing);
    });

    testWidgets('finishes each move when the motion gets shorter', (
      tester,
    ) async {
      final items = [0, 1, 2, 3, 4];
      final key = GlobalKey<AnimatedReorderableState>();
      Widget build(Duration duration) => MaterialApp(
        home: Scaffold(
          body: AnimatedReorderable.list(
            key: key,
            keyGetter: (index) => ValueKey(items[index]),
            motion: MotionOptions(duration: duration),
            reorder: ReorderOptions(
              onReorder: (permutations) => permutations.apply(items),
            ),
            listView: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  SizedBox(height: _extent, child: Text('${items[index]}')),
            ),
          ),
        ),
      );
      await tester.pumpWidget(build(const Duration(seconds: 1)));
      key.currentState!.reorderItem(0, destIndex: 2);
      final tops = await track(tester, find.text('0'), 10);

      await tester.pumpWidget(build(const Duration(milliseconds: 100)));
      key.currentState!.reorderItem(2, destIndex: 3);
      tops.addAll(await track(tester, find.text('0'), 80));

      expect(tops.last, 3 * _extent);
      // It gets there on its way rather than jumps there at the end.
      expect(_steps(tops), everyElement(inInclusiveRange(0, 40)));
    });
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

/// How far an item at [positions], one a frame, moves each frame.
List<double> _steps(List<double> positions) => [
  for (var i = 1; i < positions.length; i++) positions[i] - positions[i - 1],
];

/// The frames at which an item at [positions], one a frame, stops dead: it
/// moves over 2 px the frame before and under 0.25 px the frame after.
List<int> _deadStops(List<double> positions) => [
  for (var i = 1; i < positions.length - 1; i++)
    if ((positions[i] - positions[i - 1]).abs() > 2 &&
        (positions[i + 1] - positions[i]).abs() < 0.25)
      i,
];

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
    this.shrinkWrap = false,
    this.padding,
    this.swipeToRemoveDirection,
    this.swipeToRemoveSpringDescription = _defaultSpring,
    this.reorderSpringDescription = _defaultSpring,
    this.insertTransition,
  }) : items = List.generate(count, (i) => i);

  final List<int> items;
  final bool grid;
  final SliverGridDelegate gridDelegate;
  final Axis scrollDirection;
  final bool reverse;
  final bool shrinkWrap;
  final EdgeInsets? padding;

  /// The swipe direction of every item, or null for the default one.
  AxisDirection? swipeToRemoveDirection;
  final SpringDescription swipeToRemoveSpringDescription;
  final SpringDescription reorderSpringDescription;

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
            onReorder: (permutations) {
              reorders++;
              permutations.apply(items);
            },
            draggableGetter: draggableGetter,
            reorderableGetter: reorderableGetter,
            springDescription: reorderSpringDescription,
          ),
          swipeToRemove: SwipeToRemoveOptions(
            onSwipeToRemove: removeAt,
            directionGetter: _swipeToRemoveDirectionGetter,
          ),
          insertTransition: insertTransition,
          gridView: GridView.builder(
            scrollDirection: scrollDirection,
            reverse: reverse,
            shrinkWrap: shrinkWrap,
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
            springDescription: reorderSpringDescription,
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
            shrinkWrap: shrinkWrap,
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

/// An extent the app gives its items from above the list.
class _Extent extends InheritedWidget {
  const _Extent({required this.value, required super.child});

  final double value;

  @override
  bool updateShouldNotify(_Extent oldWidget) => value != oldWidget.value;
}

/// Calls [onPaint] each time it paints.
class _PaintCounter extends CustomPainter {
  _PaintCounter(this.onPaint);

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) => onPaint();

  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => false;
}

/// Where the layers that [finder]'s widget is painted on put its top left
/// corner, as the engine composes them.
Offset _paintedTopLeft(WidgetTester tester, Finder finder) {
  RenderObject? boundary = tester.renderObject(finder);
  while (boundary != null && !boundary.isRepaintBoundary) {
    boundary = boundary.parent;
  }
  var transform = Matrix4.identity();
  // The root layer scales logical pixels to the device's.
  for (Layer? layer = boundary!.debugLayer; layer?.parent != null;) {
    if (layer case final OffsetLayer offsetLayer) {
      final own = layer is TransformLayer
          ? layer.transform ?? Matrix4.identity()
          : Matrix4.identity();
      transform =
          Matrix4.translationValues(
            offsetLayer.offset.dx,
            offsetLayer.offset.dy,
            0,
          ) *
          own *
          transform;
    }
    layer = layer!.parent;
  }
  return MatrixUtils.transformPoint(transform, Offset.zero);
}

/// Where a screen reader finds the items with [ids], in the device's pixels.
List<Rect> _semanticsRects(WidgetTester tester, List<int> ids) => [
  for (final id in ids) _semanticsRect(tester.getSemantics(find.text('$id'))),
];

Rect _semanticsRect(SemanticsNode node) {
  var rect = node.rect;
  for (SemanticsNode? n = node; n != null; n = n.parent) {
    if (n.transform case final transform?) {
      rect = MatrixUtils.transformRect(transform, rect);
    }
  }
  return rect;
}

/// The names of the moves a screen reader can make with the item [label]
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

/// What the move named [name] of the item with [id] does, as it is built
/// now.
VoidCallback _semanticMove(WidgetTester tester, int id, String name) {
  final semantics = tester.widget<Semantics>(
    find.ancestor(
      of: find.text('$id'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.customSemanticsActions != null,
      ),
    ),
  );
  return semantics.properties.customSemanticsActions![CustomSemanticsAction(
    label: name,
  )]!;
}

/// Two of the names Flutter's German localizations give the moves.
class _GermanMoves extends DefaultWidgetsLocalizations {
  const _GermanMoves();

  static const delegate = _GermanMovesDelegate();

  @override
  String get reorderItemDown => 'Nach unten verschieben';

  @override
  String get reorderItemToEnd => 'An das Ende verschieben';
}

class _GermanMovesDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const _GermanMovesDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture(const _GermanMoves());

  @override
  bool shouldReload(_GermanMovesDelegate old) => false;
}
