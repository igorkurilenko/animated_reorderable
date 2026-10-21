import 'dart:io';

import 'package:example/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a long press drags a card to a new place', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReorderableListExample()));
    final from = tester.getCenter(find.text('Card 0'));
    final below = tester.getCenter(find.text('Card 2'));

    final gesture = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    for (var i = 1; i <= 20; i++) {
      // To where card 2 is: past its middle, but not past card 3's.
      await gesture.moveTo(Offset.lerp(from, below, i / 20)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    double y(String text) => tester.getCenter(find.text(text)).dy;
    expect(y('Card 1'), lessThan(y('Card 2')));
    expect(y('Card 2'), lessThan(y('Card 0')));
    expect(y('Card 0'), lessThan(y('Card 3')));
  });

  testWidgets('a swipe deletes a card, and the others close the gap', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ReorderableListExample()));
    final gap = tester.getCenter(find.text('Card 1')).dy;

    await tester.timedDrag(
      find.text('Card 1'),
      const Offset(-500, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    expect(find.text('Card 1'), findsNothing);
    expect(tester.getCenter(find.text('Card 2')).dy, moreOrLessEquals(gap));
  });

  testWidgets('+ inserts a card at the top', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReorderableListExample()));
    final top = tester.getCenter(find.text('Card 0')).dy;

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(tester.getCenter(find.text('Card 50')).dy, moreOrLessEquals(top));
    expect(tester.getCenter(find.text('Card 0')).dy, greaterThan(top));
  });

  test('shows the code of lib/main.dart on its pub.dev page', () {
    // pub.dev shows example.md on the package's Example tab.
    final page = File('example.md').readAsStringSync();
    final code = RegExp(
      r'```dart\n(.*?)```',
      dotAll: true,
    ).firstMatch(page)?.group(1);
    final main = File('lib/main.dart').readAsStringSync();

    expect(code, main.substring(main.indexOf('import ')));
  });
}
