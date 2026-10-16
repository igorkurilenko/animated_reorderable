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

      key.currentState!.insertItem(
        0,
        (context, index, animation) => Text(labels[index]),
      );
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
              onReorder: (permutations) => permutations.apply(items),
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
}

/// A list of [labels] keyed by label, rebuilt from scratch like immutable
/// state would be.
Widget _labels(
  List<String> labels, {
  Key? key,
  void Function(Permutations permutations)? onReorder,
}) => MaterialApp(
  home: Scaffold(
    body: AnimatedReorderable.list(
      key: key,
      keyGetter: (index) => ValueKey(labels[index]),
      onReorder: onReorder,
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

ScrollPosition _scrollPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

/// Resizes the test view to [size] in logical pixels until the test ends.
void _resize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
}

/// A list of ids shown as stateful items of a fixed extent.
class _TestList {
  _TestList(
    int count, {
    this.grid = false,
    this.gridDelegate = const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
    ),
    this.swipeToRemoveSpringDescription = _defaultSpring,
  }) : items = List.generate(count, (i) => i);

  final List<int> items;
  final bool grid;
  final SliverGridDelegate gridDelegate;
  final SpringDescription swipeToRemoveSpringDescription;
  final key = GlobalKey<AnimatedReorderableState>();

  /// How many times each item's state was created.
  final inits = <int, int>{};

  AnimatedReorderableState get state => key.currentState!;

  Widget build() => MaterialApp(home: Scaffold(body: buildList()));

  Widget buildList() => grid
      ? AnimatedReorderable.grid(
          key: key,
          keyGetter: (index) => ValueKey(items[index]),
          onReorder: (permutations) => permutations.apply(items),
          gridView: GridView.builder(
            gridDelegate: gridDelegate,
            itemCount: items.length,
            itemBuilder: (context, index) => _item(items[index]),
          ),
        )
      : AnimatedReorderable.list(
          key: key,
          keyGetter: (index) => ValueKey(items[index]),
          onReorder: (permutations) => permutations.apply(items),
          onSwipeToRemove: removeAt,
          swipeToRemoveSpringDescription: swipeToRemoveSpringDescription,
          listView: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => _item(items[index]),
          ),
        );

  void insert(int index, int id) {
    items.insert(index, id);
    state.insertItem(index, (context, index, animation) => _item(items[index]));
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
      SizedBox(height: _extent, child: Text('${widget.id}'));
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
