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

/// An item while the overlay shows it, above the list.
class OverlayedItem extends widgets.ChangeNotifier {
  OverlayedItem({
    required this.item,
    required this._position,
    required this._constraints,
    required this.size,
    required this.index,
    this._interactive = true,
    this.outgoing = false,
    this.zIndex = defaultZIndex,
    this.recognizerFactory,
  });

  /// The item the overlay shows. It builds the item's subtree, which keeps
  /// its state as it moves between the list and the overlay.
  final Item item;
  int index;
  widgets.Offset _position;
  widgets.BoxConstraints _constraints;

  /// The size of the item itself, without its decoration, as the overlay
  /// lays it out. The list's placeholder takes this size.
  widgets.Size size;
  bool _interactive;

  /// Whether the item was removed from the list. The list no longer owns
  /// an outgoing item, so the overlay disposes it.
  bool outgoing;
  int zIndex;
  MultiDragGestureRecognizerFactory? recognizerFactory;
  gestures.MultiDragGestureRecognizer? _recognizer;
  _OverlayedItemSwipe? _swipe;
  widgets.Offset? _globalPointerPosition;
  OffsetAnimation? _motionAnimation;
  AnimatedItemDecoratorAdapter? _decorator;

  Key get key => item.key;

  widgets.Offset get position => _position;
  widgets.Offset get anchorPosition =>
      _motionAnimation != null ? _motionAnimation!.end : position;
  widgets.AnimationStatus? get motionAnimationStatus =>
      _motionAnimation?.controller.status;

  void setPosition(widgets.Offset value, {bool notify = true}) {
    if (_position == value) return;
    _position = value;
    if (notify) notifyListeners();
  }

  widgets.BoxConstraints get constraints => _constraints;

  void setConstraints(widgets.BoxConstraints value, {bool notify = true}) {
    if (_constraints == value) return;
    _constraints = value;
    if (notify) notifyListeners();
  }

  bool get interactive => _interactive;

  void setInteractive(bool value, {bool notify = true}) {
    if (interactive == value) return;
    _interactive = value;
    if (notify) notifyListeners();
  }

  Offset? get globalPointerPosition => _globalPointerPosition;

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

  void shift(Offset delta, {bool notify = true}) {
    _motionAnimation?.shift(delta);
    setPosition(position + delta, notify: notify);
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
        _globalPointerPosition = globalPosition;
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
    Offset position, {
    required TickerProvider vsync,
    required Duration duration,
    required Curve curve,
  }) {
    if (position == this.position) return Future.value();

    final controller = _motionTo(
      position,
      curve: curve,
      vsync: vsync,
    ).controller;
    controller.duration = duration;
    return controller.forward(from: 0.0);
  }

  Future animateFlingTo(
    Offset position, {
    required widgets.Velocity velocity,
    required Size screenSize,
    SpringDescription springDescription = defaultFlingSpringDescription,
    required TickerProvider vsync,
  }) {
    if (position == this.position) return Future.value();

    final controller = _motionTo(
      position,
      curve: Curves.linear,
      vsync: vsync,
    ).controller;

    final pixelsPerSecond = velocity.pixelsPerSecond;
    final unitsPerSecondX = pixelsPerSecond.dx / screenSize.width;
    final unitsPerSecondY = pixelsPerSecond.dy / screenSize.height;
    final unitsPerSecond = Offset(unitsPerSecondX, unitsPerSecondY);
    final unitVelocity = unitsPerSecond.distance;
    final simulation = SpringSimulation(springDescription, 0, 1, -unitVelocity);

    return controller.animateWith(simulation);
  }

  /// The motion animation, set to move this item from where it is to
  /// [position] along [curve].
  OffsetAnimation _motionTo(
    Offset position, {
    required Curve curve,
    required TickerProvider vsync,
  }) =>
      (_motionAnimation ??= OffsetAnimation(
          controller: AnimationController(vsync: vsync)
            ..addListener(() => setPosition(_motionAnimation!.value)),
        ))
        ..begin = this.position
        ..end = position
        ..curve = curve;

  void stopMotion() => _motionAnimation?.controller.stop();

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
    _motionAnimation?.dispose();
    _motionAnimation = null;
    _decorator?.dispose();
    _decorator = null;
    if (outgoing) item.dispose();
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
    item._globalPointerPosition = details.globalPosition;
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
    item._globalPointerPosition = details.globalPosition;
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
