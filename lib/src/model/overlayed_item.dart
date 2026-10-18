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
  bool _interactive;

  int zIndex;

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

  OverlayOffset get position => _position;

  /// Notifies when the item moves. The overlay lays the item out again
  /// rather than building it, so a moving item builds only when it changes
  /// otherwise.
  widgets.Listenable get positionChanges => _positionChanges;

  /// Where the item moves to, or where it is if it does not move.
  OverlayOffset get anchorPosition => _motion?.target ?? position;
  widgets.AnimationStatus? get motionAnimationStatus => _motion?.status;

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

  GlobalOffset? get globalPointerPosition => _globalPointerPosition;

  bool get swiped => _swipe != null;

  SwipeDirection? get swipeToRemoveDirection => _swipe?.swipeDirection;

  Offset get swipeOffset => _swipe?.swipeOffset ?? Offset.zero;

  double get swipeExtent => _swipe?.swipeExtent ?? 0.0;

  /// Builds the item inside its decoration. [wrap] goes between the two.
  widgets.Widget? build(
    widgets.BuildContext context, {
    widgets.Widget Function(widgets.Widget item)? wrap,
  }) {
    final child = item.builder.build(context, index);
    if (child == null) return null;
    final keyed = widgets.KeyedSubtree(key: item.childKey, child: child);
    final wrapped = wrap?.call(keyed) ?? keyed;
    return _decorator?.decorate(wrapped, index) ?? wrapped;
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
    required Size screenSize,
    SpringDescription springDescription = defaultFlingSpringDescription,
    required TickerProvider vsync,
  }) {
    if (position == this.position) return Future.value();

    return _motionWith(vsync).fling(
      from: this.position,
      to: position,
      velocity: velocity,
      screenSize: screenSize,
      springDescription: springDescription,
    );
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

  Future animateUndecoration() => switch (_decorator) {
    (AnimatedItemDecoratorAdapter d) => d.reverseAnimation(),
    _ => Future.value(),
  };

  @override
  void dispose() {
    _recognizer?.dispose();
    _recognizer = null;
    _swipe = null;
    _motion?.dispose();
    _motion = null;
    _decorator?.dispose();
    _decorator = null;
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
