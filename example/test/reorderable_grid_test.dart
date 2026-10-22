import 'package:example/reorderable_grid/main.dart';
import 'package:example/style/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  // On a phone's screen, an iPhone 15's, as the example is recorded.
  Future<void> pumpExample(WidgetTester tester) {
    setScreen(tester, const Size(393, 852), pixelRatio: 3);
    return tester.pumpWidget(
      MaterialApp(theme: exampleTheme, home: const ReorderableGridExample()),
    );
  }

  Offset at(WidgetTester tester, String name) =>
      tester.getCenter(find.text(name));

  testWidgets('a long press drags a shortcut to another row', (tester) async {
    await pumpExample(tester);
    final home = at(tester, 'Home');
    final clock = at(tester, 'Clock');

    await longPressDrag(tester, home, clock);

    // Home took Clock's cell, two rows down, and the shortcuts before it
    // moved back a cell, across the rows.
    expect(at(tester, 'Home'), offsetMoreOrLessEquals(clock));
    expect(at(tester, 'Search'), offsetMoreOrLessEquals(home));
  });

  testWidgets('Add shortcut inserts one at the start, once', (tester) async {
    await pumpExample(tester);
    final home = at(tester, 'Home');
    final search = at(tester, 'Search');

    await tester.tap(find.text('Add shortcut'));
    await tester.pumpAndSettle();

    expect(at(tester, 'Files'), offsetMoreOrLessEquals(home));
    expect(at(tester, 'Home'), offsetMoreOrLessEquals(search));

    await tester.tap(find.text('Add shortcut'));
    await tester.pumpAndSettle();
    expect(find.text('Files'), findsOneWidget);
  });

  testWidgets('a swipe removes a shortcut, and the others close the gap', (
    tester,
  ) async {
    await pumpExample(tester);
    final home = at(tester, 'Home');

    await tester.timedDrag(
      find.text('Home'),
      const Offset(-300, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsNothing);
    expect(at(tester, 'Search'), offsetMoreOrLessEquals(home));
  });
}
