// Measures how long the frames of the package's moves take on a device.
// See README.md for how to run it.

import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // The engine draws the frames, as in an app.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'frame times',
    (tester) async {
      var bench = _Bench(60);
      await tester.pumpWidget(bench.build());
      await _wait(1000);
      final top = tester.getTopLeft(find.byKey(bench.key));
      final tileExtent = tester.getSize(find.byType(Card).first).height + 8;
      final secondTile = top + Offset(200, tileExtent * 1.5);

      await _measure(binding, tester, 'reorder', () async {
        for (var i = 0; i < 6; i++) {
          bench.state.reorderItem(0, destIndex: 7);
          await _wait(700);
          bench.state.reorderItem(7, destIndex: 0);
          await _wait(700);
        }
      });

      await _measure(binding, tester, 'drag', () async {
        for (var i = 0; i < 2; i++) {
          await _dragThereAndBack(tester, secondTile, const Offset(0, 4), 120);
        }
      });

      await _measure(binding, tester, 'removes', () async {
        for (var round = 0; round < 3; round++) {
          for (var i = 0; i < 4; i++) {
            bench.remove(1);
            await _wait(100);
          }
          await _wait(800);
        }
      });

      await _measure(binding, tester, 'swipes', () async {
        for (var i = 0; i < 4; i++) {
          final clock = Stopwatch()..start();
          final swipe = await tester.createGesture();
          await swipe.down(secondTile, timeStamp: clock.elapsed);
          for (var j = 0; j < 10; j++) {
            await swipe.moveBy(const Offset(-25, 0), timeStamp: clock.elapsed);
            await _wait(8);
          }
          await swipe.up(timeStamp: clock.elapsed);
          await _wait(900);
        }
      });

      bench = _Bench(1000);
      await tester.pumpWidget(bench.build());
      await _wait(1000);
      await _measure(binding, tester, 'long reorder', () async {
        for (var i = 0; i < 3; i++) {
          bench.state.reorderItem(0, destIndex: 999);
          await _wait(700);
          bench.state.reorderItem(999, destIndex: 0);
          await _wait(700);
        }
      });

      bench = _Bench(1000, columns: 12);
      await tester.pumpWidget(bench.build());
      await _wait(1000);
      final cell = tester.getSize(find.byType(Card).first).width;
      await _measure(binding, tester, 'grid drag', () async {
        await _dragThereAndBack(
          tester,
          top + Offset(cell / 2, cell / 2),
          Offset(cell / 12, cell / 9),
          120,
        );
      });
    },
    // Semantics run only under an assistive technology, which most users
    // don't have on. --dart-define=SEMANTICS=true measures as under one.
    semanticsEnabled: const bool.fromEnvironment('SEMANTICS'),
  );
}

/// Records the frame times of [action] as [scenario], and fails it if
/// anything threw.
Future<void> _measure(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String scenario,
  Future<void> Function() action,
) async {
  await binding.watchPerformance(action, reportKey: scenario);
  expect(tester.takeException(), isNull, reason: scenario);
}

/// Long-presses at [start], drags by [step] every 8 ms [steps] times, then
/// back the same way, and lets go.
Future<void> _dragThereAndBack(
  WidgetTester tester,
  Offset start,
  Offset step,
  int steps,
) async {
  // The pointer's speed at the end comes from the times of its moves.
  final clock = Stopwatch()..start();
  final drag = await tester.createGesture();
  await drag.down(start, timeStamp: clock.elapsed);
  await _wait(650);
  for (final move in [step, -step]) {
    for (var i = 0; i < steps; i++) {
      await drag.moveBy(move, timeStamp: clock.elapsed);
      await _wait(8);
    }
  }
  await drag.up(timeStamp: clock.elapsed);
  await _wait(1000);
}

Future<void> _wait(int milliseconds) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

/// A list of cards, or a grid of [columns] small ones.
class _Bench {
  _Bench(int count, {this.columns}) : items = List.generate(count, (i) => i);

  final List<int> items;
  final int? columns;
  final key = GlobalKey<AnimatedReorderableState>();

  AnimatedReorderableState get state => key.currentState!;

  Widget build() => MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: switch (columns) {
          null => AnimatedReorderable.list(
            key: key,
            keyGetter: (index) => ValueKey(items[index]),
            reorder: ReorderOptions(
              onReorder: (permutations) => permutations.apply(items),
            ),
            swipeToRemove: SwipeToRemoveOptions(onSwipeToRemove: remove),
            listView: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => _tile(items[index]),
            ),
          ),
          final int columns => AnimatedReorderable.grid(
            key: key,
            keyGetter: (index) => ValueKey(items[index]),
            reorder: ReorderOptions(
              onReorder: (permutations) => permutations.apply(items),
            ),
            gridView: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) => _cell(items[index]),
            ),
          ),
        },
      ),
    ),
  );

  void remove(int index) {
    final id = items.removeAt(index);
    state.removeItem(
      index,
      (context, animation) =>
          FadeTransition(opacity: animation, child: _tile(id)),
    );
  }
}

Widget _tile(int id) => Card(
  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  child: ListTile(
    leading: CircleAvatar(child: Text('${id % 100}')),
    title: Text('Item $id'),
    subtitle: const Text('A line of secondary text'),
    trailing: const Icon(Icons.drag_handle),
  ),
);

Widget _cell(int id) => Card(
  margin: const EdgeInsets.all(1),
  child: Center(child: Text('$id', style: const TextStyle(fontSize: 9))),
);
