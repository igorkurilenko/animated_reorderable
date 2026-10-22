import 'package:example/kanban/board.dart';
import 'package:example/kanban/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The board's first task to do, which the tests move to Done.
const _title = 'Show typing indicators in group chats';

void main() {
  testWidgets('drags a task into Done, which strikes its title through', (
    tester,
  ) async {
    setScreen(tester, const Size(1200, 900));
    await tester.pumpWidget(const KanbanExample());

    // A finger holds the card a moment first.
    await longPressDrag(
      tester,
      tester.getCenter(find.text(_title)),
      tester.getCenter(find.byType(DoneTaskCard).first),
    );

    final done = find.descendant(
      of: find.byType(DoneTaskCard),
      matching: find.text(_title),
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
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(const KanbanExample());
    final from = tester.getCenter(find.text(_title));
    final finger = await hold(tester, from);

    // Done is out of sight until the board scrolls it in.
    double done() => tester.getCenter(find.byType(DoneTaskCard).first).dx;
    expect(done(), greaterThan(390));
    final edge = Offset(386, from.dy);
    await slide(tester, finger, from, edge);
    for (var i = 0; i < 300 && done() > 390 - 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(done(), lessThan(390 - 80));
    await slide(
      tester,
      finger,
      edge,
      tester.getCenter(find.byType(DoneTaskCard).first),
    );
    await finger.up();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(DoneTaskCard),
        matching: find.text(_title),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
