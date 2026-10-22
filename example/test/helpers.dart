// What the examples' tests do with the screen and a finger, in one place.

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gives the test a screen of [size], in logical pixels, at [pixelRatio],
/// until it ends.
void setScreen(WidgetTester tester, Size size, {double pixelRatio = 1}) {
  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);
}

/// Puts a finger on [at] and holds it there until a long press starts a
/// drag.
Future<TestGesture> hold(WidgetTester tester, Offset at) async {
  final finger = await tester.startGesture(at);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  return finger;
}

/// Slides a held [finger] from [from] to [to], over 20 frames.
Future<void> slide(
  WidgetTester tester,
  TestGesture finger,
  Offset from,
  Offset to,
) async {
  for (var i = 1; i <= 20; i++) {
    await finger.moveTo(Offset.lerp(from, to, i / 20)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Long-presses what's at [from], drags it to [to] and drops it there, then
/// lets it settle.
Future<void> longPressDrag(WidgetTester tester, Offset from, Offset to) async {
  final finger = await hold(tester, from);
  await slide(tester, finger, from, to);
  await finger.up();
  await tester.pumpAndSettle();
}
