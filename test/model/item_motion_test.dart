import 'package:animated_reorderable/src/model/model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('drops the moves that are over as new ones start, where it is', (
    tester,
  ) async {
    final motion = ItemMotion(vsync: const TestVSync(), onMove: (_) {});
    addTearDown(motion.dispose);
    const duration = Duration(milliseconds: 500);
    OverlayOffset place(int i) => OverlayOffset(Offset(0, 100.0 * i));

    motion.animate(
      from: place(0),
      to: place(1),
      curve: Curves.linear,
      duration: duration,
    );
    // A new move every 100 ms, as a place that keeps moving makes.
    for (var i = 2; i <= 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final position = motion.position;
      motion.animate(
        from: position,
        to: place(i),
        curve: Curves.linear,
        duration: duration,
      );
      // It goes on from where it is.
      expect((motion.position - position).distance, lessThan(1e-9));
    }

    // The ones started in the last 500 ms.
    expect(motion.legCount, lessThanOrEqualTo(6));
    await tester.pump(duration);
    await tester.pump(const Duration(milliseconds: 16));
    expect(motion.position, place(20));
  });
}
