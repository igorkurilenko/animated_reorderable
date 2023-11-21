part of model;

typedef OverlayedItemCallback = void Function(OverlayedItem item);
typedef RecognizerFactory = gestures.MultiDragGestureRecognizer Function(
  widgets.BuildContext context,
);

class OverlayedItem extends Item {
  OverlayedItem({
    required super.id,
    required super.builder,
    required super.location,
    required super.size,
    required this.index,
    required bool draggable,
    required this.reorderable,
    this.recognizerFactory,
  }) : _draggable = draggable;

  bool _draggable;
  final bool reorderable;
  int index;

  RecognizerFactory? recognizerFactory;
  gestures.MultiDragGestureRecognizer? _recognizer;
  _OverlayedItemSwipe? _swipe;
  widgets.Offset? _pointerPosition;
  OffsetAnimation? _locationAnimation;

  bool get draggable => _draggable;
  void setDraggable(bool value, {bool notify = true}) {
    if (draggable == value) return;
    _draggable = value;
    if (notify) notifyListeners();
  }

  bool get swiped => _swipe != null;
  widgets.AxisDirection? get swipeDirection => _swipe?.swipeDirection;

  widgets.Widget? build(widgets.BuildContext context) =>
      builder.build(context, index);

  @override
  void shift(Offset delta, {bool notify = true}) {
    _locationAnimation?.shift(delta);
    super.shift(delta, notify: notify);
  }

  @override
  void shiftSilent(Offset delta) => shift(delta, notify: false);

  void startDrag(
    widgets.PointerDownEvent event, {
    required widgets.BuildContext context,
    OverlayedItemCallback? onDragStart,
    OverlayedItemCallback? onDragUpdate,
    OverlayedItemCallback? onDragEnd,
  }) {
    _recognizer?.dispose();
    _swipe = null;

    if (!draggable) return;
    if (recognizerFactory == null) return;

    _recognizer = recognizerFactory!.call(context)
      ..onStart = (pointerPosition) {
        _pointerPosition = pointerPosition;
        onDragStart?.call(this);

        return _OverlayedItemDrag(
          item: this,
          onDragUpdate: onDragUpdate,
          onDragEnd: onDragEnd,
        );
      }
      ..addPointer(event);
  }

  void startSwipe(
    widgets.PointerDownEvent event, {
    required widgets.BuildContext context,
    required widgets.AxisDirection swipeDirection,
    OverlayedItemCallback? onSwipeStart,
    OverlayedItemCallback? onSwipeUpdate,
    OverlayedItemCallback? onSwipeEnd,
  }) {
    _recognizer?.dispose();

    if (!draggable) return;
    if (recognizerFactory == null) return;

    _recognizer = recognizerFactory!.call(context)
      ..onStart = (pointerPosition) {
        _pointerPosition = pointerPosition;
        onSwipeStart?.call(this);

        return _swipe = _OverlayedItemSwipe(
          item: this,
          swipeDirection: swipeDirection,
          onSwipeUpdate: onSwipeUpdate,
          onSwipeEnd: onSwipeEnd,
        );
      }
      ..addPointer(event);
  }

  TickerFuture forwardLocationAnimation({
    Offset? begin,
    required Offset end,
    double from = 0.0,
    required TickerProvider vsync,
    required Duration duration,
    required Curve curve,
  }) {
    _locationAnimation?.controller.stop();

    begin ??= location;

    _locationAnimation ??= OffsetAnimation(
      controller: AnimationController(
        vsync: vsync,
        duration: duration,
      )..addListener(() => setLocation(_locationAnimation!.value)),
    );
    _locationAnimation!.begin = begin;
    _locationAnimation!.end = end;
    _locationAnimation!.curve = curve;

    return _locationAnimation!.controller.forward(from: from);
  }

  @override
  void dispose() {
    _recognizer?.dispose();
    _recognizer = null;
    _locationAnimation?.dispose();
    _locationAnimation = null;
    super.dispose();
  }

  @override
  String toString() => 'OverlayedItem(id: $id, index: $index)';
}

class _OverlayedItemDrag implements gestures.Drag {
  _OverlayedItemDrag({
    required this.item,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final OverlayedItem item;
  OverlayedItemCallback? onDragUpdate;
  OverlayedItemCallback? onDragEnd;

  @override
  void update(widgets.DragUpdateDetails details) {
    item.shift(details.delta);
    item._pointerPosition = details.globalPosition;
    onDragUpdate?.call(item);
  }

  @override
  void end(widgets.DragEndDetails details) {
    item._pointerPosition = null;
    onDragEnd?.call(item);
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
  final widgets.AxisDirection swipeDirection;
  OverlayedItemCallback? onSwipeUpdate;
  OverlayedItemCallback? onSwipeEnd;
  widgets.Offset _swipeOffset = widgets.Offset.zero;
  widgets.Velocity _velocity = widgets.Velocity.zero;

  widgets.Velocity get velocity => _velocity;
  widgets.Offset get swipeOffset => _swipeOffset;
  double get swipeExtent => _swipeOffset.dx.abs() > 0
      ? _swipeOffset.dx / item.geometry.width
      : _swipeOffset.dy.abs() > 0
          ? _swipeOffset.dy / item.geometry.height
          : 0.0;

  @override
  void update(widgets.DragUpdateDetails details) {
    final delta = _restrictDirection(_restrictAxis(details.delta));
    _swipeOffset += delta;
    item.shift(delta);
    item._pointerPosition = details.globalPosition;
    onSwipeUpdate?.call(item);
  }

  widgets.Offset _restrictAxis(widgets.Offset delta) =>
      switch (swipeDirection) {
        widgets.AxisDirection.left ||
        widgets.AxisDirection.right =>
          widgets.Offset(delta.dx, 0),
        widgets.AxisDirection.down ||
        widgets.AxisDirection.up =>
          widgets.Offset(0, delta.dy),
      };

  widgets.Offset _restrictDirection(widgets.Offset delta) =>
      switch (swipeDirection) {
        widgets.AxisDirection.left when delta.dx > 0 && _swipeOffset.dx > 0 =>
          widgets.Offset(delta.dx / 3, 0),
        widgets.AxisDirection.right when delta.dx < 0 && _swipeOffset.dx < 0 =>
          widgets.Offset(delta.dx / 3, 0),
        widgets.AxisDirection.down when delta.dy < 0 && _swipeOffset.dy < 0 =>
          widgets.Offset(0, delta.dy / 3),
        widgets.AxisDirection.up when delta.dy > 0 && _swipeOffset.dy > 0 =>
          widgets.Offset(0, delta.dy / 3),
        _ => delta,
      };

  @override
  void end(widgets.DragEndDetails details) {
    _velocity = details.velocity;
    item._pointerPosition = null;
    onSwipeEnd?.call(item);
  }

  @override
  void cancel() {
    // noop
  }
}
