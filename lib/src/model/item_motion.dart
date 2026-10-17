part of 'model.dart';

/// Moves an overlayed item: to a position along a curve, or with a spring
/// after a fling. It tells [onMove] where the item is on each tick.
class ItemMotion {
  ItemMotion({required TickerProvider vsync, required this.onMove}) {
    _controller = AnimationController(vsync: vsync)
      ..addListener(() => onMove(position));
  }

  late final AnimationController _controller;
  final ValueChanged<OverlayOffset> onMove;
  var _begin = const OverlayOffset(Offset.zero);
  var _end = const OverlayOffset(Offset.zero);
  Curve _curve = Curves.linear;

  /// Where the item is on its way.
  OverlayOffset get position => OverlayOffset(
    Offset.lerp(_begin, _end, _curve.transform(_controller.value))!,
  );

  /// Where the item moves to, or moved to last.
  OverlayOffset get target => _end;

  AnimationStatus get status => _controller.status;

  /// Moves the item from [from] to [to] along [curve] in [duration].
  TickerFuture animate({
    required OverlayOffset from,
    required OverlayOffset to,
    required Curve curve,
    required Duration duration,
  }) {
    _moveBetween(from, to, curve: curve);
    _controller.duration = duration;
    return _controller.forward(from: 0.0);
  }

  /// Moves the item from [from] to [to] with [springDescription], starting
  /// at [velocity], relative to [screenSize].
  TickerFuture fling({
    required OverlayOffset from,
    required OverlayOffset to,
    required Velocity velocity,
    required Size screenSize,
    required SpringDescription springDescription,
  }) {
    _moveBetween(from, to, curve: Curves.linear);
    final pixelsPerSecond = velocity.pixelsPerSecond;
    final unitsPerSecondX = pixelsPerSecond.dx / screenSize.width;
    final unitsPerSecondY = pixelsPerSecond.dy / screenSize.height;
    final unitsPerSecond = Offset(unitsPerSecondX, unitsPerSecondY);
    final unitVelocity = unitsPerSecond.distance;
    final simulation = SpringSimulation(springDescription, 0, 1, -unitVelocity);
    return _controller.animateWith(simulation);
  }

  void _moveBetween(
    OverlayOffset from,
    OverlayOffset to, {
    required Curve curve,
  }) {
    _begin = from;
    _end = to;
    _curve = curve;
  }

  /// Moves the whole way by [delta], as the view scrolls.
  void shift(Offset delta) {
    _begin += delta;
    _end += delta;
  }

  void stop() => _controller.stop();

  void dispose() => _controller.dispose();
}
