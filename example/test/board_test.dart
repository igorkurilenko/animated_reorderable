import 'package:example/animated_reorderable_board/animated_reorderable_board.0.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('drags a task into Done, which strikes its title through', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AnimatedReorderableBoardSample());
    const title = 'Show typing indicators in group chats';
    final from = tester.getCenter(find.text(title));
    final to = tester.getCenter(find.byType(DoneTaskCard).first);

    // A finger holds the card a moment first.
    final drag = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    for (var i = 1; i <= 20; i++) {
      await drag.moveTo(Offset.lerp(from, to, i / 20)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pumpAndSettle();

    final done = find.descendant(
      of: find.byType(DoneTaskCard),
      matching: find.text(title),
    );
    expect(done, findsOneWidget);
    expect(
      tester.widget<Text>(done).style?.decoration,
      TextDecoration.lineThrough,
    );
    // The headers count the tasks again: 6 to do and 5 done.
    expect(find.text('6'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolls a narrow board to Done while a card is held at its '
      'edge', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AnimatedReorderableBoardSample());
    const title = 'Show typing indicators in group chats';
    var pointer = tester.getCenter(find.text(title));
    final drag = await tester.startGesture(pointer);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    Future<void> moveTo(Offset target) async {
      final start = pointer;
      for (var i = 1; i <= 20; i++) {
        pointer = Offset.lerp(start, target, i / 20)!;
        await drag.moveTo(pointer);
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    // Done is out of sight until the board scrolls it in.
    double done() => tester.getCenter(find.byType(DoneTaskCard).first).dx;
    expect(done(), greaterThan(390));
    await moveTo(Offset(386, pointer.dy));
    for (var i = 0; i < 300 && done() > 390 - 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(done(), lessThan(390 - 80));
    await moveTo(tester.getCenter(find.byType(DoneTaskCard).first));
    await drag.up();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(DoneTaskCard),
        matching: find.text(title),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
