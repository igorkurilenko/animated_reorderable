import 'dart:math' as math;

import 'package:animated_reorderable/src/model/model.dart';
import 'package:flutter/physics.dart';
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

  testWidgets('flings an item let go in its place nowhere', (tester) async {
    final motion = ItemMotion(vsync: const TestVSync(), onMove: (_) {});
    addTearDown(motion.dispose);
    const place = OverlayOffset(Offset(0, 100));

    motion.fling(
      from: place,
      to: place,
      velocity: const Velocity(pixelsPerSecond: Offset(0, 2000)),
      springDescription: const SpringDescription(
        mass: 1,
        stiffness: 500,
        damping: 75,
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(motion.position, place);
    }
    await tester.pumpAndSettle();
  });

  testWidgets('stops a fling with a spring that does not bounce at its end, '
      'however fast it starts', (tester) async {
    const from = OverlayOffset(Offset.zero);
    const to = OverlayOffset(Offset(0, 100));
    for (final spring in [
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 250),
      ),
      const SpringDescription(mass: 1, stiffness: 2000, damping: 150),
      // Critically damped as written by hand, rounded down a little.
      const SpringDescription(mass: 1, stiffness: 500, damping: 44.7213595499),
    ]) {
      for (final speed in [4000.0, 30000.0]) {
        final motion = ItemMotion(vsync: const TestVSync(), onMove: (_) {});
        addTearDown(motion.dispose);
        motion.fling(
          from: from,
          to: to,
          velocity: Velocity(pixelsPerSecond: Offset(0, speed)),
          springDescription: spring,
        );
        final ys = <double>[];
        for (var i = 0; i < 60 && motion.isMoving; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          ys.add(motion.position.dy);
        }

        final reason = '$spring at $speed px/s';
        expect(motion.isMoving, isFalse, reason: reason);
        expect(
          ys.reduce(math.max),
          lessThanOrEqualTo(100 + 1e-6),
          reason: reason,
        );
        expect(ys.last, closeTo(100, 0.5), reason: reason);
      }
    }
  });

  testWidgets('flings with its spring as it is if the spring stops the item '
      'of itself, or bounces', (tester) async {
    // A fling runs a frame of the display ahead of its clock, which starts
    // at the first frame.
    final lead = 1 / tester.view.display.refreshRate;
    for (final (spring, speed) in [
      (
        SpringDescription.withDurationAndBounce(
          duration: const Duration(milliseconds: 250),
        ),
        2000.0,
      ),
      (const SpringDescription(mass: 1, stiffness: 2000, damping: 150), 4000.0),
      // Fast enough that a spring that doesn't bounce would be stopped.
      (
        SpringDescription.withDampingRatio(mass: 1, stiffness: 500, ratio: 0.5),
        3000.0,
      ),
    ]) {
      final motion = ItemMotion(vsync: const TestVSync(), onMove: (_) {});
      addTearDown(motion.dispose);
      motion.fling(
        from: const OverlayOffset(Offset.zero),
        to: const OverlayOffset(Offset(0, 100)),
        velocity: Velocity(pixelsPerSecond: Offset(0, speed)),
        springDescription: spring,
      );
      final simulation = SpringSimulation(spring, 0, 100, speed);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          motion.position.dy,
          closeTo(simulation.x(i * 0.016 + lead), 1e-6),
          reason: '$spring at $speed px/s, frame $i',
        );
      }
      await tester.pumpAndSettle();
    }
  });
}
