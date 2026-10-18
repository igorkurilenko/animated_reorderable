part of 'model.dart';

/// Moves an overlayed item: to a position along a curve, or with a spring
/// after a fling. It tells [onMove] where the item is on each tick.
///
/// A move along a curve that starts while the item moves along one adds
/// to the moves under way rather than starting over from rest, so the item
/// keeps its speed as it heads for the new position. The motion goes on
/// until the last of them ends.
class ItemMotion {
  ItemMotion({required TickerProvider vsync, required this.onMove}) {
    // Along a curve, its value is the time in seconds since the first of
    // the moves under way started; in a fling, how far the item is on its
    // way.
    _controller = AnimationController.unbounded(vsync: vsync)
      ..addListener(() => onMove(position));
  }

  late final AnimationController _controller;
  final ValueChanged<OverlayOffset> onMove;
  var _end = const OverlayOffset(Offset.zero);

  /// The moves along a curve under way, from the earliest one. Each takes
  /// the item from the target of the one before, or from where it started,
  /// to its own target; the last one's is [_end].
  final _legs = <_Leg>[];

  /// Where a fling started.
  var _flingBegin = const OverlayOffset(Offset.zero);

  /// The clock of the moves along a curve, and the run the item is on.
  var _clock = _Clock(0);
  TickerFuture? _run;

  /// Where the item is on its way.
  OverlayOffset get position {
    final value = _controller.value;
    if (_legs.isEmpty) {
      return OverlayOffset(
        Offset.lerp(_flingBegin, _end, clampDouble(value, 0.0, 1.0))!,
      );
    }
    var position = _end as Offset;
    for (final leg in _legs) {
      position += leg.remainingAt(value);
    }
    return OverlayOffset(position);
  }

  /// Where the item moves to, or moved to last.
  OverlayOffset get target => _end;

  AnimationStatus get status => _controller.status;

  bool get _movesAlongCurve => _controller.isAnimating && _legs.isNotEmpty;

  /// Moves the item from [from] to [to] along [curve] in [duration]. While
  /// the item moves along a curve, it heads for [to] from where it is going
  /// instead, at its speed, and the run it is on goes on until it gets
  /// there.
  TickerFuture animate({
    required OverlayOffset from,
    required OverlayOffset to,
    required Curve curve,
    required Duration duration,
  }) {
    // With animations off, a move takes 5% of its duration, as the runs of
    // an animation controller with AnimationBehavior.normal do.
    final scale = SemanticsBinding.instance.disableAnimations ? 0.05 : 1.0;
    final seconds =
        scale * duration.inMicroseconds / Duration.microsecondsPerSecond;
    if (_movesAlongCurve) {
      if (to == _end) return _run!;
      // The run goes on rather than starts over, which would show the item
      // where it is for one more frame.
      final now = _controller.value;
      _legs
        ..removeWhere((leg) => leg.isDoneAt(now))
        ..add(_Leg(_end - to, start: now, seconds: seconds, curve: curve));
      _end = to;
      _clock.end = math.max(_clock.end, now + seconds);
      return _run!;
    }
    _legs
      ..clear()
      ..add(_Leg(from - to, start: 0, seconds: seconds, curve: curve));
    _end = to;
    _clock = _Clock(seconds);
    return _run = _controller.animateWith(_clock);
  }

  /// Moves the item from [from] to [to] with [springDescription], starting
  /// at the part of [velocity] that heads for [to], relative to
  /// [screenSize].
  TickerFuture fling({
    required OverlayOffset from,
    required OverlayOffset to,
    required Velocity velocity,
    required Size screenSize,
    required SpringDescription springDescription,
  }) {
    _legs.clear();
    _flingBegin = from;
    _end = to;
    final pixelsPerSecond = velocity.pixelsPerSecond;
    final unitsPerSecondX = pixelsPerSecond.dx / screenSize.width;
    final unitsPerSecondY = pixelsPerSecond.dy / screenSize.height;
    final unitsPerSecond = Offset(unitsPerSecondX, unitsPerSecondY);
    // Positive toward [to], and negative away from it.
    final way = to - from;
    final heading = way == Offset.zero ? Offset.zero : way / way.distance;
    final unitVelocity =
        unitsPerSecond.dx * heading.dx + unitsPerSecond.dy * heading.dy;
    final simulation = SpringSimulation(springDescription, 0, 1, unitVelocity);
    return _run = _controller.animateWith(simulation);
  }

  /// Moves the whole way by [delta], as the view scrolls.
  void shift(Offset delta) {
    _flingBegin += delta;
    _end += delta;
  }

  void stop() => _controller.stop();

  void dispose() => _controller.dispose();
}

/// One move along a curve: the item covers [distance] in [seconds] from
/// [start].
class _Leg {
  _Leg(
    this.distance, {
    required this.start,
    required this.seconds,
    required this.curve,
  });

  final Offset distance;
  final double start;
  final double seconds;
  final Curve curve;

  bool isDoneAt(double time) => time >= start + seconds;

  /// What is left of [distance] at [time].
  Offset remainingAt(double time) {
    final t = seconds == 0
        ? 1.0
        : clampDouble((time - start) / seconds, 0.0, 1.0);
    return distance * (1 - curve.transform(t));
  }
}

/// Counts the seconds until [end], which a move that starts on the way
/// can put off.
class _Clock extends Simulation {
  _Clock(this.end);

  double end;

  @override
  double x(double time) => time;

  @override
  double dx(double time) => 1.0;

  // Past the end, as an animation controller's own runs are, so the item
  // shows at its target for a frame.
  @override
  bool isDone(double time) => time > end;
}
