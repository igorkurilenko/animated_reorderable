import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _extent = 100.0;

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
  });
}

/// A list of ids shown as stateful items of a fixed extent.
class _TestList {
  _TestList(int count) : items = List.generate(count, (i) => i);

  final List<int> items;
  final key = GlobalKey<AnimatedReorderableState>();

  AnimatedReorderableState get state => key.currentState!;

  Widget build() => MaterialApp(
    home: Scaffold(
      body: AnimatedReorderable.list(
        key: key,
        keyGetter: (index) => ValueKey(items[index]),
        onReorder: (permutations) => permutations.apply(items),
        listView: ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) => _Item(id: items[index]),
        ),
      ),
    ),
  );

  void insert(int index, int id) {
    items.insert(index, id);
    state.insertItem(
      index,
      (context, index, animation) => _Item(id: items[index]),
    );
  }

  void removeAt(int index) {
    final id = items.removeAt(index);
    state.removeItem(index, (context, animation) => _Item(id: id));
  }
}

class _Item extends StatefulWidget {
  const _Item({required this.id});

  final int id;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: _extent, child: Text('${widget.id}'));
}

int _trackedTickers(WidgetTester tester) {
  final state = tester.state(
    find.byWidgetPredicate((widget) => widget is AnimatedReorderable),
  );
  final tracking = RegExp(r'tracking (\d+) ticker').firstMatch('$state');
  return tracking == null ? 0 : int.parse(tracking.group(1)!);
}
