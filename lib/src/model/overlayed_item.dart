part of model;

typedef OverlayedItemCallback = void Function(OverlayedItem item);
typedef RecognizerFactory = gestures.MultiDragGestureRecognizer Function(
  widgets.BuildContext context,
);

class OverlayedItem extends Item {
  OverlayedItem({
    required super.id,
    required super.builder,
    required super.position,
    required super.size,
    required this.index,
    required bool draggable,
    int zIndex = minZIndex,
    this.recognizerFactory,
  })  : _draggable = draggable,
        _zIndex = zIndex;

  int index;
  bool _draggable;
  int _zIndex = 0;
  RecognizerFactory? recognizerFactory;
  gestures.MultiDragGestureRecognizer? _recognizer;
  _OverlayedItemSwipe? _swipe;
  widgets.Offset? _pointerPosition;
  OffsetAnimation? _motionAnimation;

  bool get draggable => _draggable;
  void setDraggable(bool value, {bool notify = true}) {
    if (draggable == value) return;
    _draggable = value;
    if (notify) notifyListeners();
  }

  bool get swiped => _swipe != null;
  widgets.AxisDirection? get swipeDirection => _swipe?.swipeDirection;
  Offset? get pointerPosition => _pointerPosition;

  widgets.Widget? build(widgets.BuildContext context) =>
      builder.build(context, index);

  @override
  void shift(Offset delta, {bool notify = true}) {
    _motionAnimation?.shift(delta);
    super.shift(delta, notify: notify);
  }

  @override
  void scale(double scaleFactor, {bool notify = true}) {
    _motionAnimation?.scale(scaleFactor);
    super.scale(scaleFactor, notify: notify);
  }

  int get zIndex => _zIndex;
  void setZIndex(int value, {bool notify = true}) {
    if (_zIndex == value) return;
    _zIndex = value;
    if (notify) notifyListeners();
  }

  void recognizeDrag(
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

  void recognizeSwipe(
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

  void setMotionAnimation(OffsetAnimation animation) {
    _motionAnimation?.controller.stop();
    _motionAnimation = animation;
  }

  Future forwardMotionAnimation({
    Offset? begin,
    required Offset end,
    double? from,
    required TickerProvider vsync,
    required Duration duration,
    required Curve curve,
  }) {
    _motionAnimation ??= OffsetAnimation(
      controller: AnimationController(
        vsync: vsync,
        duration: duration,
      )..addListener(() => setPosition(_motionAnimation!.value)),
    );
    _motionAnimation!.begin = begin ?? position;
    _motionAnimation!.end = end;
    _motionAnimation!.curve = curve;

    return _motionAnimation!.controller.forward(from: from);
  }

  void stopMotionAnimation() => _motionAnimation?.controller.stop();

  @override
  void dispose() {
    _recognizer?.dispose();
    _recognizer = null;
    _swipe = null;
    _motionAnimation?.dispose();
    _motionAnimation = null;
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
