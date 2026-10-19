part of 'model.dart';

/// A held item's flight from the look of the list it left to the look of
/// the list it went to, as a hero_here flight flies a hero: its shuttle
/// shows the two looks, and grows or shrinks from the old look's size to
/// the new one's around the point the pointer holds.
class ItemFlight {
  ItemFlight({
    required this.from,
    required this.fromSize,
    required this.grip,
    required TickerProvider vsync,
    required Duration duration,
    required Curve curve,
  }) : _controller = AnimationController(vsync: vsync, duration: duration) {
    animation = CurvedAnimation(parent: _controller, curve: curve);
    _controller.forward().whenCompleteOrCancel(_done.complete);
  }

  /// The look the item leaves, as it last showed, as hero_here shows a hero
  /// that went away. Building it again would make it anew, with new state,
  /// and the old list's builder builds another item at its index by now.
  final ui.Image from;

  /// The size of that look.
  final widgets.Size fromSize;

  /// The point of the item the pointer holds, as a part of its size.
  final widgets.Offset grip;

  /// The size of the look the item flies to, once it has laid out.
  widgets.Size? toSize;

  final AnimationController _controller;

  /// Runs from 0 at the look the item leaves to 1 at its new look.
  late final Animation<double> animation;
  final _done = Completer<void>();

  /// Completes when the flight lands, or is called off.
  Future<void> get done => _done.future;

  /// The size the shuttle shows at on this frame.
  widgets.Size get shownSize =>
      widgets.Size.lerp(fromSize, toSize ?? fromSize, animation.value)!;

  void dispose() {
    _controller.dispose();
    from.dispose();
  }
}
