part of model;

typedef ActiveItemCallback = void Function(ActiveItem item);
typedef RecognizerFactory = gestures.MultiDragGestureRecognizer Function(
  widgets.BuildContext context,
);

class ActiveItem extends Item {
  ActiveItem({
    required super.id,
    required super.builder,
    required super.position,
    required super.size,
    required this.index,
    bool interactive = true,
    bool outgoing = false,
    int zIndex = defaultZIndex,
    this.recognizerFactory,
  })  : _interactive = interactive,
        _outgoing = outgoing,
        _zIndex = zIndex;

  int index;
  bool _interactive;
  bool _outgoing;
  int _zIndex = 0;
  RecognizerFactory? recognizerFactory;
  gestures.MultiDragGestureRecognizer? _recognizer;
  _ActiveItemSwipe? _swipe;
  widgets.Offset? _pointerPosition;
  OffsetAnimation? _motionAnimation;
  widgets.Widget? _widget;
  AnimatedItemDecoratorAdapter? _decorator;

  bool get interactive => _interactive;

  void setInteractive(bool value, {bool notify = true}) {
    if (interactive == value) return;
    _interactive = value;
    if (notify) notifyListeners();
  }

  bool get outgoing => _outgoing;

  void setOutgoing(bool value, {bool notify = true}) {
    if (outgoing == value) return;
    _outgoing = value;
    if (notify) notifyListeners();
  }

  bool get swiped => _swipe != null;

  widgets.AxisDirection? get swipeDirection => _swipe?.swipeDirection;

  Offset get swipeOffset => _swipe?.swipeOffset ?? Offset.zero;

  double get swipeExtent => _swipe?.swipeExtent ?? 0.0;

  widgets.Velocity get swipeVelocity =>
      _swipe?.velocity ?? widgets.Velocity.zero;

  Offset? get pointerPosition => _pointerPosition;

  widgets.Widget? get widget => _widget;

  bool swipedToRemove({
    required double extentToRemove,
    required double velocityToRemove,
  }) =>
      swiped &&
      switch (swipeDirection) {
        AxisDirection.left => swipeExtent < -extentToRemove ||
            swipeVelocity.pixelsPerSecond.dx < -velocityToRemove,
        AxisDirection.right => swipeExtent > extentToRemove ||
            swipeVelocity.pixelsPerSecond.dx > velocityToRemove,
        AxisDirection.up => swipeExtent < -extentToRemove ||
            swipeVelocity.pixelsPerSecond.dy < -velocityToRemove,
        AxisDirection.down => swipeExtent > extentToRemove ||
            swipeVelocity.pixelsPerSecond.dy > velocityToRemove,
        _ => false,
      };

  widgets.Widget? build(widgets.BuildContext context) {
    _widget = builder.build(context, index);
    return _decorator?.decorate(_widget, index) ?? _widget;
  }

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
    ActiveItemCallback? onDragStart,
    ActiveItemCallback? onDragUpdate,
    ActiveItemCallback? onDragEnd,
  }) {
    _recognizer?.dispose();
    _swipe = null;

    if (!interactive) return;
    if (recognizerFactory == null) return;

    _recognizer = recognizerFactory!.call(context)
      ..onStart = (pointerPosition) {
        _pointerPosition = pointerPosition;
        onDragStart?.call(this);

        return _ActiveItemDrag(
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
    ActiveItemCallback? onSwipeStart,
    ActiveItemCallback? onSwipeUpdate,
    ActiveItemCallback? onSwipeEnd,
  }) {
    _recognizer?.dispose();

    if (!interactive) return;
    if (recognizerFactory == null) return;

    _recognizer = recognizerFactory!.call(context)
      ..onStart = (pointerPosition) {
        _pointerPosition = pointerPosition;
        onSwipeStart?.call(this);

        return _swipe = _ActiveItemSwipe(
          item: this,
          swipeDirection: swipeDirection,
          onSwipeUpdate: onSwipeUpdate,
          onSwipeEnd: onSwipeEnd,
        );
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

    _motionAnimation ??= OffsetAnimation(
      controller: AnimationController(
        vsync: vsync,
        duration: duration,
      )..addListener(
          () => setPosition(_motionAnimation!.value),
        ),
    );
    _motionAnimation!.controller.duration = duration;
    _motionAnimation!.begin = this.position;
    _motionAnimation!.end = position;
    _motionAnimation!.curve = curve;

    return _motionAnimation!.controller.forward(from: 0.0);
  }

  Future animateFlingTo(
    Offset position, {
    required widgets.Velocity velocity,
    required Size screenSize,
    SpringDescription springDescription = defaultFlingSpringDescription,
    required TickerProvider vsync,
  }) {
    if (position == this.position) return Future.value();

    _motionAnimation ??= OffsetAnimation(
      controller: AnimationController(vsync: vsync)
        ..addListener(
          () => setPosition(_motionAnimation!.value),
        ),
    );
    _motionAnimation!.begin = this.position;
    _motionAnimation!.end = position;
    _motionAnimation!.curve = Curves.linear;

    final pixelsPerSecond = velocity.pixelsPerSecond;
    final unitsPerSecondX = pixelsPerSecond.dx / screenSize.width;
    final unitsPerSecondY = pixelsPerSecond.dy / screenSize.height;
    final unitsPerSecond = Offset(unitsPerSecondX, unitsPerSecondY);
    final unitVelocity = unitsPerSecond.distance;
    final simulation = SpringSimulation(springDescription, 0, 1, -unitVelocity);

    return _motionAnimation!.controller.animateWith(simulation);
  }

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
        controller: AnimationController(
          duration: duration,
          vsync: vsync,
        ),
      );
    }

    return _decorator!.forwardAnimation();
  }

  Future animateUndecoration() => switch (_decorator) {
        (AnimatedItemDecoratorAdapter d) => d.reverseAnimation(),
        _ => Future.value(),
      };

  double stopDecorationAnimation() => switch (_decorator) {
        (AnimatedItemDecoratorAdapter d) => d.stopDecoration(),
        _ => 0.0,
      };

  Future animateOutgoing({
    required widgets.AnimatedRemovedItemBuilder builder,
    int? zIndex,
    required Duration duration,
    required TickerProvider vsync,
  }) {
    setInteractive(
      false,
      notify: false,
    );
    setOutgoing(
      true,
      notify: false,
    );
    setZIndex(
      zIndex ?? outgoingItemZIndex,
      notify: false,
    );

    return animateRemovedItemBuilder(
      builder: builder,
      duration: duration,
      vsync: vsync,
    );
  }

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
  String toString() => 'ActiveItem(id: $id, index: $index)';
}

class _ActiveItemDrag implements gestures.Drag {
  _ActiveItemDrag({
    required this.item,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final ActiveItem item;
  ActiveItemCallback? onDragUpdate;
  ActiveItemCallback? onDragEnd;

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

class _ActiveItemSwipe implements gestures.Drag {
  _ActiveItemSwipe({
    required this.item,
    required this.swipeDirection,
    this.onSwipeUpdate,
    this.onSwipeEnd,
  });

  final ActiveItem item;
  final widgets.AxisDirection swipeDirection;
  ActiveItemCallback? onSwipeUpdate;
  ActiveItemCallback? onSwipeEnd;
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
