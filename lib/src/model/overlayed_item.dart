part of 'model.dart';

typedef OverlayedItemDragStartCallback = void Function(
  DragStartDetails details,
  OverlayedItem item,
);
typedef OverlayedItemDragUpdateCallback = void Function(
  DragUpdateDetails details,
  OverlayedItem item,
);
typedef OverlayedItemDragEndCallback = void Function(
  DragEndDetails details,
  OverlayedItem item,
);

/// A layer above the lists of a group, which shows the items held in any
/// of them, so that they can go from one list to another.
abstract interface class SharedOverlaySpace implements OverlaySpace {
  /// Stops showing [item], which its list shows from now on.
  void unhost(OverlayedItem item);
}

/// An item while the overlay shows it, above the list. It notifies when
/// the overlay has to build it again, and [positionChanges] notifies when
/// it moves.
class OverlayedItem extends widgets.ChangeNotifier {
  OverlayedItem({
    required this.item,
    required this._position,
    required this._constraints,
    required this._size,
    required this._index,
    this._interactive = true,
    this.zIndex = defaultZIndex,
    this.recognizerFactory,
  });

  /// The item the overlay shows. It builds the item's subtree, which keeps
  /// its state as it moves between the list and the overlay.
  final Item item;
  int _index;
  OverlayOffset _position;
  final _positionChanges = ChangeSignal();
  widgets.BoxConstraints _constraints;

  widgets.Size _size;

  /// The size the item's position holds the pointer's point of it for,
  /// which runs ahead of [size] as the item lays out at a new size.
  widgets.Size? _anchoredSize;

  /// How far the pointer was from the item's position, in the item's
  /// space, the last time the item was held under it. It holds while the
  /// two move together.
  widgets.Offset? _pointerOffset;
  bool _interactive;

  int zIndex;

  /// The layer that shows the item instead of its list's overlay: its
  /// group's, while the item is held in a list of a group. The item's
  /// position is in that layer's space then.
  SharedOverlaySpace? sharedSpace;

  /// When the item came into the overlay or was raised last, which puts it
  /// above the items with the same [zIndex] that came or were raised
  /// before it.
  int _raisedAt = 0;
  MultiDragGestureRecognizerFactory? recognizerFactory;
  gestures.MultiDragGestureRecognizer? _recognizer;
  _OverlayedItemSwipe? _swipe;
  GlobalOffset? _globalPointerPosition;
  ItemMotion? _motion;
  AnimatedItemDecoratorAdapter? _decorator;
  ItemFlight? _flight;

  /// Keys the boundary the item's look paints into while a group's layer
  /// shows it, so the look can be taken as an image when the item flies.
  final lookKey = widgets.GlobalKey();

  /// The item's flight from the look of the list it left to its new
  /// list's look, while it flies.
  ItemFlight? get flight => _flight;

  /// Flies the item from [from], the look of [fromSize] it leaves, to the
  /// look its builder builds now, holding the point [grip] of it. A flight
  /// under way gives way to it.
  void fly({
    required ui.Image from,
    required widgets.Size fromSize,
    required widgets.Offset grip,
    required TickerProvider vsync,
    required Duration duration,
    required Curve curve,
  }) {
    _flight?.dispose();
    final flight = _flight = ItemFlight(
      from: from,
      fromSize: fromSize,
      grip: grip,
      vsync: vsync,
      duration: duration,
      curve: curve,
    );
    flight.done.then((_) {
      if (_flight != flight) return;
      _flight = null;
      flight.dispose();
      notifyListeners();
    });
    notifyListeners();
  }

  Key get key => item.key;

  /// The item's index, which the overlay builds it at.
  int get index => _index;

  set index(int value) {
    if (_index == value) return;
    _index = value;
    notifyListeners();
  }

  /// The size of the item itself, without its decoration, as the overlay
  /// lays it out. The list's placeholder takes this size.
  widgets.Size get size => _size;

  /// The size the item's position holds the pointer's point of it for, as
  /// the item lays out: [size], or its new size in the frame that lays it
  /// out at one.
  widgets.Size get anchoredSize => _anchoredSize ?? _size;

  /// Takes [size] as the size the item's position holds the pointer's
  /// point of it for, with the pointer [pointerOffset] from its position.
  void anchorTo(widgets.Size size, {widgets.Offset? pointerOffset}) {
    _anchoredSize = size;
    if (pointerOffset != null) _pointerOffset = pointerOffset;
  }

  /// Moves the item so that the pointer holds the same point of it,
  /// relative to its size, as it lays out at [size], in the frame that lays
  /// it out. Layout can't map the pointer to the item's space, so the item
  /// goes by how far the pointer was from it the last time it was held
  /// under it.
  void keepPointerAsLaidOut(widgets.Size size) {
    final anchored = anchoredSize;
    final offset = _pointerOffset;
    _anchoredSize = size;
    if (offset == null || anchored.isEmpty || size == anchored) return;
    final scaled = widgets.Offset(
      offset.dx * size.width / anchored.width,
      offset.dy * size.height / anchored.height,
    );
    _pointerOffset = scaled;
    setPosition(OverlayOffset(position + offset - scaled));
  }

  OverlayOffset get position => _position;

  /// Notifies when the item moves. The overlay lays the item out again
  /// rather than building it, so a moving item builds only when it changes
  /// otherwise.
  widgets.Listenable get positionChanges => _positionChanges;

  /// Where the item moves to, or where it is if it does not move.
  OverlayOffset get anchorPosition => _motion?.target ?? position;
  widgets.AnimationStatus? get motionAnimationStatus => _motion?.status;

  /// Whether the item is still on its way: moving, flying from one look to
  /// another, or with its decoration coming or going.
  bool get isAnimating =>
      (_motion?.isMoving ?? false) ||
      _flight != null ||
      (_decorator?.controller.isAnimating ?? false);

  void setPosition(OverlayOffset value) {
    if (_position == value) return;
    _position = value;
    _positionChanges.notify();
  }

  widgets.BoxConstraints get constraints => _constraints;

  void setConstraints(widgets.BoxConstraints value) {
    if (_constraints == value) return;
    _constraints = value;
    notifyListeners();
  }

  bool get interactive => _interactive;

  void setInteractive(bool value) {
    if (interactive == value) return;
    _interactive = value;
    notifyListeners();
  }

  /// Whether a group's layer clips the item to its list, as the list's own
  /// overlay clips its items: once the list scrolls it while it lands
  /// there, it is the list's content, which goes out of sight at the
  /// list's edges.
  bool get clippedToList => _clippedToList;
  var _clippedToList = false;

  void setClippedToList(bool value) {
    if (_clippedToList == value) return;
    _clippedToList = value;
    notifyListeners();
  }

  GlobalOffset? get globalPointerPosition => _globalPointerPosition;

  /// The point of the item the pointer holds, as a part of its size, while
  /// a group's layer shows it.
  Offset? get grip {
    final pointer = _globalPointerPosition;
    final space = sharedSpace;
    if (pointer == null || space == null || size.isEmpty) return null;
    final topLeft = space.localToGlobal(position);
    return Offset(
      (pointer.dx - topLeft.dx) / size.width,
      (pointer.dy - topLeft.dy) / size.height,
    );
  }

  bool get swiped => _swipe != null;

  SwipeDirection? get swipeToRemoveDirection => _swipe?.swipeDirection;

  Offset get swipeOffset => _swipe?.swipeOffset ?? Offset.zero;

  double get swipeExtent => _swipe?.swipeExtent ?? 0.0;

  /// Builds the item, which [measure] measures, inside its decoration.
  /// [enter] puts its look in the transition it enters with. While the item
  /// flies, [shuttle] shows its look with the one it leaves, inside the
  /// decoration that it's given, as the shuttle grows or shrinks, and while
  /// a group's layer shows it, [boundary] paints its look into a layer of
  /// its own, which a flight can take as an image.
  widgets.Widget? build(
    widgets.BuildContext context, {
    widgets.Widget Function(widgets.Widget look)? enter,
    widgets.Widget Function(widgets.Widget item)? measure,
    widgets.Widget Function(
      ItemFlight flight,
      widgets.Widget look,
      widgets.Widget Function(widgets.Widget shuttle) decorate,
    )?
    shuttle,
    widgets.Widget Function(widgets.Widget look)? boundary,
  }) {
    final child = _builtChild = item.builder.build(context, index);
    if (child == null) return null;
    final keyed = widgets.KeyedSubtree(
      key: item.childKey,
      child: InkSurface(child: child),
    );
    final look = enter?.call(keyed) ?? keyed;
    widgets.Widget decorate(widgets.Widget shown) =>
        _decorator?.decorate(shown, index) ?? shown;
    widgets.Widget measured(widgets.Widget shown) =>
        measure?.call(shown) ?? shown;
    return switch (_flight) {
      final flight? when shuttle != null => measured(
        shuttle(flight, look, decorate),
      ),
      _ when sharedSpace != null => decorate(
        boundary?.call(measured(look)) ?? measured(look),
      ),
      _ => decorate(measured(look)),
    };
  }

  void shift(Offset delta) {
    _motion?.shift(delta);
    setPosition(position + delta);
  }

  void recognizeDrag(
    widgets.PointerDownEvent event, {
    required widgets.BuildContext context,
    OverlayedItemDragStartCallback? onDragStart,
    OverlayedItemDragUpdateCallback? onDragUpdate,
    OverlayedItemDragEndCallback? onDragEnd,
  }) {
    // The item is no longer swiped once a drag may start, while a swipe
    // replaces the previous one only when it starts.
    _swipe = null;
    _recognize(
      event,
      context: context,
      onStart: onDragStart,
      createDrag: () => _OverlayedItemDrag(
        item: this,
        onDragUpdate: onDragUpdate,
        onDragEnd: onDragEnd,
      ),
    );
  }

  void recognizeSwipe(
    widgets.PointerDownEvent event, {
    required widgets.BuildContext context,
    required SwipeDirection swipeDirection,
    OverlayedItemDragStartCallback? onSwipeStart,
    OverlayedItemDragUpdateCallback? onSwipeUpdate,
    OverlayedItemDragEndCallback? onSwipeEnd,
  }) => _recognize(
    event,
    context: context,
    onStart: onSwipeStart,
    createDrag: () => _swipe = _OverlayedItemSwipe(
      item: this,
      swipeDirection: swipeDirection,
      onSwipeUpdate: onSwipeUpdate,
      onSwipeEnd: onSwipeEnd,
    ),
  );

  /// Lets the recognizer from [recognizerFactory] decide whether [event]
  /// starts a drag of this item, and then the drag from [createDrag]
  /// follows the pointer.
  void _recognize(
    widgets.PointerDownEvent event, {
    required widgets.BuildContext context,
    required OverlayedItemDragStartCallback? onStart,
    required gestures.Drag Function() createDrag,
  }) {
    _recognizer?.dispose();

    if (!interactive) return;
    if (recognizerFactory == null) return;

    _recognizer = recognizerFactory!.call(context)
      ..onStart = (globalPosition) {
        _globalPointerPosition = GlobalOffset(globalPosition);
        onStart?.call(
          DragStartDetails(
            sourceTimeStamp: event.timeStamp,
            globalPosition: globalPosition,
            localPosition: event.localPosition,
            kind: event.kind,
          ),
          this,
        );

        return createDrag();
      }
      ..addPointer(event);
  }

  Future animateTo(
    OverlayOffset position, {
    required TickerProvider vsync,
    required Duration duration,
    required Curve curve,
  }) {
    if (position == this.position) return Future.value();

    return _motionWith(vsync).animate(
      from: this.position,
      to: position,
      curve: curve,
      duration: duration,
    );
  }

  Future animateFlingTo(
    OverlayOffset position, {
    required widgets.Velocity velocity,
    SpringDescription springDescription = defaultFlingSpringDescription,
    required TickerProvider vsync,
  }) {
    if (position == this.position) return Future.value();

    return _motionWith(vsync).fling(
      from: this.position,
      to: position,
      velocity: velocity,
      springDescription: springDescription,
    );
  }

  /// Throws the item out to [position], out of sight, as it is swiped away.
  void animateThrowOut(
    OverlayOffset position, {
    required widgets.Velocity velocity,
    required Duration duration,
    required TickerProvider vsync,
  }) {
    if (position == this.position) return _didThrow();
    _motionWith(vsync)
        .throwOut(
          from: this.position,
          to: position,
          velocity: velocity,
          duration: duration,
        )
        .whenCompleteOrCancel(_didThrow);
  }

  /// Swipes the item away: it keeps its decoration as far as it has come,
  /// and once the list removes it, it leaves as it is, thrown out of sight.
  void swipeAway() {
    _swipedAway = true;
    _decorator?.controller.stop();
  }

  /// Whether the item is swiped away.
  bool get swipedAway => _swipedAway;
  var _swipedAway = false;

  /// What the item's builder built for the overlay last, which the item
  /// keeps showing as it leaves as it is.
  widgets.Widget? get builtChild => _builtChild;
  widgets.Widget? _builtChild;

  /// Completes once the item is thrown out of sight, or its throw stops.
  Future get thrown => _thrown.future;
  final _thrown = Completer<void>();

  void _didThrow() {
    if (!_thrown.isCompleted) _thrown.complete();
  }

  ItemMotion _motionWith(TickerProvider vsync) =>
      _motion ??= ItemMotion(vsync: vsync, onMove: setPosition);

  void stopMotion() => _motion?.stop();

  Future animateDecoration({
    AnimatedItemDecorator? decorator,
    required Duration duration,
    required TickerProvider vsync,
  }) {
    if (decorator == null) return Future.value();

    if (_decorator != null) {
      _decorator!.decorator = decorator;
    } else {
      _decorator = AnimatedItemDecoratorAdapter(
        decorator,
        controller: AnimationController(duration: duration, vsync: vsync),
      );
    }
    notifyListeners();

    return _decorator!.forwardAnimation();
  }

  /// Takes the item's decoration away, as long as it took to come. A flung
  /// item that lands in its place sooner loses it as it lands, though in no
  /// less than [shortestUndecorationDuration], so it doesn't shrink and
  /// brighten in its place after it gets there.
  Future animateUndecoration() {
    final decorator = _decorator;
    if (decorator == null) return Future.value();
    final controller = decorator.controller;
    // From as far as it has come.
    final whole =
        (controller.reverseDuration ?? controller.duration!) * controller.value;
    final landing = _motion?.flingLandingWithin(whole) ?? whole;
    final duration = landing < shortestUndecorationDuration
        ? shortestUndecorationDuration
        : landing;
    if (duration >= whole) return decorator.reverseAnimation();
    return controller.animateBack(0, duration: duration);
  }

  @override
  void dispose() {
    _recognizer?.dispose();
    _recognizer = null;
    _swipe = null;
    _motion?.dispose();
    _motion = null;
    _decorator?.dispose();
    _decorator = null;
    _flight?.dispose();
    _flight = null;
    _positionChanges.dispose();
    super.dispose();
  }

  @override
  String toString() => 'OverlayedItem(id: $key, index: $index)';
}

class _OverlayedItemDrag implements gestures.Drag {
  _OverlayedItemDrag({required this.item, this.onDragUpdate, this.onDragEnd});

  final OverlayedItem item;
  OverlayedItemDragUpdateCallback? onDragUpdate;
  OverlayedItemDragEndCallback? onDragEnd;

  @override
  void update(widgets.DragUpdateDetails details) {
    item._globalPointerPosition = GlobalOffset(details.globalPosition);
    onDragUpdate?.call(details, item);
  }

  @override
  void end(widgets.DragEndDetails details) {
    item._globalPointerPosition = null;
    onDragEnd?.call(details, item);
  }

  @override
  void cancel() {}
}

class _OverlayedItemSwipe implements gestures.Drag {
  _OverlayedItemSwipe({
    required this.item,
    required this.swipeDirection,
    this.onSwipeUpdate,
    this.onSwipeEnd,
  });

  final OverlayedItem item;
  final SwipeDirection swipeDirection;
  OverlayedItemDragUpdateCallback? onSwipeUpdate;
  OverlayedItemDragEndCallback? onSwipeEnd;
  widgets.Offset _swipeOffset = widgets.Offset.zero;

  widgets.Offset get swipeOffset => _swipeOffset;

  double get swipeExtent =>
      swipeDirection.along(_swipeOffset) / swipeDirection.extentOf(item.size);

  @override
  void update(widgets.DragUpdateDetails details) {
    final delta = swipeDirection.restrict(details.delta, swiped: _swipeOffset);
    _swipeOffset += delta;
    item._globalPointerPosition = GlobalOffset(details.globalPosition);
    onSwipeUpdate?.call(
      widgets.DragUpdateDetails(
        sourceTimeStamp: details.sourceTimeStamp,
        delta: delta,
        primaryDelta: swipeDirection.along(delta),
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
      ),
      item,
    );
  }

  @override
  void end(widgets.DragEndDetails details) {
    item._globalPointerPosition = null;
    onSwipeEnd?.call(details, item);
  }

  @override
  void cancel() {
    // noop
  }
}
