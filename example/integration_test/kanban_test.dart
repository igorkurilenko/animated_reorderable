// Drags a task of the board sample into Done on a device, where the engine
// draws the frames: the flight from the card to the done card takes the
// card as an image as it last showed. On a narrow screen, the board
// scrolls Done into sight while the card is held at its edge.
//
//   flutter test integration_test/kanban_test.dart -d <device id>

import 'package:example/kanban/board.dart';
import 'package:example/kanban/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('flies a task from its card to a done card as it goes into '
      'Done', (tester) async {
    await tester.pumpWidget(const KanbanExample());
    await tester.pumpAndSettle();

    const title = 'Show typing indicators in group chats';
    var pointer = tester.getCenter(find.text(title));
    final drag = await tester.startGesture(pointer);
    // A finger holds the card a moment first.
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 200));

    var flew = false;
    Future<void> moveTo(Offset target) async {
      final start = pointer;
      for (var i = 1; i <= 30; i++) {
        pointer = Offset.lerp(start, target, i / 30)!;
        await drag.moveTo(pointer);
        await tester.pump(const Duration(milliseconds: 16));
        flew |= find.byType(RawImage).evaluate().isNotEmpty;
      }
    }

    final board = tester.getSize(find.byType(KanbanBoard));
    double done() => tester.getCenter(find.byType(DoneTaskCard).first).dx;
    if (done() > board.width - 80) {
      await moveTo(Offset(board.width - 4, pointer.dy));
      for (var i = 0; i < 300 && done() > board.width - 80; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    await moveTo(tester.getCenter(find.byType(DoneTaskCard).first));
    await tester.pump(const Duration(milliseconds: 500));
    await drag.up();
    await tester.pumpAndSettle();

    expect(flew, isTrue);
    expect(find.byType(RawImage), findsNothing);
    // The task is a done card now, its title struck through.
    final doneCard = find.descendant(
      of: find.byType(DoneTaskCard),
      matching: find.text(title),
    );
    expect(doneCard, findsOneWidget);
    expect(
      tester.widget<Text>(doneCard).style?.decoration,
      TextDecoration.lineThrough,
    );
    expect(
      find.descendant(of: find.byType(TaskCard), matching: find.text(title)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
