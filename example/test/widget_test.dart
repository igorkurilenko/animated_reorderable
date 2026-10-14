import 'package:example/animated_reorderable_list/animated_reorderable_list.0.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('inserts, reorders and removes items', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AnimatedReorderableListSample());
    expect(find.text('Item 3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.pumpAndSettle();
    expect(find.text('Item 4'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.swap_calls));
    await tester.pumpAndSettle();
    expect(find.textContaining('Item '), findsNWidgets(5));

    await tester.tap(find.byIcon(Icons.remove_circle));
    await tester.pumpAndSettle();
    expect(find.textContaining('Item '), findsNWidgets(4));
  });
}
