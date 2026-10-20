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

  /// How many moves along a curve the item is on. A move drops out once
  /// it is over and another starts.
  @visibleForTesting
  int get legCount => _legs.length;

  /// Where a fling started.
  var _flingBegin = const OverlayOffset(Offset.zero);

  /// The fling the item is on, from 0 at [_flingBegin] to 1 at [_end], by
  /// the time since its run started.
  Simulation? _fling;

  /// The clock of the moves along a curve, and the run the item is on.
  var _clock = _Clock(0);
  TickerFuture? _run;

  /// Where the item is on its way.
  OverlayOffset get position {
    final value = _controller.value;
    if (_legs.isEmpty) {
      return OverlayOffset(Offset.lerp(_flingBegin, _end, value)!);
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

  /// Whether the item is on its way.
  bool get isMoving => _controller.isAnimating;

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
    _fling = null;
    _clock = _Clock(seconds);
    return _run = _controller.animateWith(_clock);
  }

  /// Moves the item from [from] to [to] with [springDescription], starting
  /// at the part of [velocity] that heads for [to]. A bouncy spring takes
  /// the item past [to] if it is let go fast enough, as it would; one that
  /// doesn't bounce stops it there. Let go moving away, the item goes on
  /// back past [from] before it heads for [to].
  TickerFuture fling({
    required OverlayOffset from,
    required OverlayOffset to,
    required Velocity velocity,
    required SpringDescription springDescription,
  }) {
    _legs.clear();
    _flingBegin = from;
    _end = to;
    // The spring runs from 0 at [from] to 1 at [to], so it starts at the
    // speed along the way.
    final speed = _speedAlongTheWay(velocity, from: from, to: to);
    final simulation = SpringSimulation(
      _stoppingAtTheEnd(springDescription, speed: speed),
      0,
      1,
      speed,
    );
    return _run = _controller.animateWith(_fling = _FrameAhead(simulation));
  }

  /// How long the fling under way takes the item to land, from the first
  /// frame of its run on: until it comes within [landingTolerance] of
  /// [target] for good. [limit] if it lands later, if the item isn't
  /// flung, or if it is let go in its place, as it has nowhere to land.
  Duration flingLandingWithin(Duration limit) {
    final fling = _fling;
    final way = (_end - _flingBegin).distance;
    if (fling == null || !isMoving || way <= landingTolerance) return limit;
    const step = Duration(milliseconds: 1);
    // The last moment it is further away than that, a step at a time back
    // from [limit].
    for (var time = limit; time > Duration.zero; time -= step) {
      final seconds = time.inMicroseconds / Duration.microsecondsPerSecond;
      if ((1 - fling.x(seconds)).abs() * way > landingTolerance) {
        return time + step < limit ? time + step : limit;
      }
    }
    return Duration.zero;
  }

  /// [spring], made just stiff enough, if it doesn't bounce, to stop an
  /// item that starts at [speed] at the end of its way. A spring that
  /// doesn't bounce takes an item past the end only if the item starts
  /// toward it faster than the spring's faster rate of decay, in parts of
  /// the way per second. An item that starts at that rate slows down in
  /// step with the way left, and stops at the end.
  static SpringDescription _stoppingAtTheEnd(
    SpringDescription spring, {
    required double speed,
  }) {
    final SpringDescription(:mass, :stiffness, :damping) = spring;
    final ratio = damping / (2 * math.sqrt(mass * stiffness));
    // A bouncy spring takes the item past the end however fast it starts.
    // The margin is for rounding, in a spring made with a ratio of 1.
    if (ratio < 1 - 1e-9) return spring;
    final fasterDecay =
        math.sqrt(stiffness / mass) *
        (ratio + math.sqrt(math.max(0.0, ratio * ratio - 1)));
    if (speed <= fasterDecay) return spring;
    // Stiffer by the square of how much faster the item starts, and more
    // damped by as much, so the spring keeps its damping ratio.
    final scale = speed / fasterDecay;
    return SpringDescription(
      mass: mass,
      stiffness: stiffness * scale * scale,
      damping: damping * scale,
    );
  }

  /// Throws the item from [from] out to [to], out of sight, at the part of
  /// [velocity] that heads for [to], speeding it up evenly only as much as
  /// it takes to get there in [duration]. Let go fast enough, it keeps its
  /// speed. A spring would pull it hardest as it is let go, so its speed
  /// would leap, and would slow it down on its way out.
  TickerFuture throwOut({
    required OverlayOffset from,
    required OverlayOffset to,
    required Velocity velocity,
    required Duration duration,
  }) {
    _legs.clear();
    _flingBegin = from;
    _end = to;
    _fling = null;
    final scale = SemanticsBinding.instance.disableAnimations ? 0.05 : 1.0;
    final seconds =
        scale * duration.inMicroseconds / Duration.microsecondsPerSecond;
    // Let go moving back, it goes out from rest.
    final speed = math.max(
      0.0,
      _speedAlongTheWay(velocity, from: from, to: to),
    );
    // Even, to get the rest of the way in the time; none if the speed gets
    // it there sooner.
    final acceleration = math.max(
      0.0,
      2 * (1 - speed * seconds) / (seconds * seconds),
    );
    return _run = _controller.animateWith(
      _FrameAhead(_Throw(speed: speed, acceleration: acceleration)),
    );
  }

  /// The part of [velocity] along the way from [from] to [to], as a part
  /// of the way per second: positive toward [to], and negative away from
  /// it. An item let go in its place has no way to go.
  static double _speedAlongTheWay(
    Velocity velocity, {
    required OverlayOffset from,
    required OverlayOffset to,
  }) {
    final pixelsPerSecond = velocity.pixelsPerSecond;
    final way = to - from;
    return way == Offset.zero
        ? 0.0
        : (pixelsPerSecond.dx * way.dx + pixelsPerSecond.dy * way.dy) /
              (way.distance * way.distance);
  }

  /// How long a frame shows on the display.
  static double get _frameSeconds {
    final display =
        WidgetsBinding.instance.platformDispatcher.implicitView?.display;
    final rate = display?.refreshRate ?? 0;
    return 1 / (rate >= 1 ? rate : 60);
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

/// [simulation] a frame of the display ahead of its clock. A run's clock
/// starts at the first frame after the item is let go, which would show the
/// item where the frame before did, as if it stopped for a frame.
class _FrameAhead extends Simulation {
  _FrameAhead(this.simulation) : _lead = ItemMotion._frameSeconds;

  final Simulation simulation;
  final double _lead;

  @override
  double x(double time) => simulation.x(time + _lead);

  @override
  double dx(double time) => simulation.dx(time + _lead);

  @override
  bool isDone(double time) => simulation.isDone(time + _lead);
}

/// A throw along the way, from 0 to 1: it starts at [speed] and speeds up
/// by [acceleration], as parts of the way per second.
class _Throw extends Simulation {
  _Throw({required this.speed, required this.acceleration});

  final double speed;
  final double acceleration;

  // It stops at the end of the way, out of sight, as a spring would come
  // to rest there.
  @override
  double x(double time) =>
      math.min(1, speed * time + acceleration * time * time / 2);

  @override
  double dx(double time) => speed + acceleration * time;

  @override
  bool isDone(double time) => x(time) >= 1;
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
