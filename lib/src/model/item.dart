part of model;

class Item extends widgets.ChangeNotifier {
  Item({
    required this.id,
    required ItemBuilder builder,
    widgets.Offset position = widgets.Offset.zero,
    widgets.Size size = widgets.Size.zero,
    this.measured = false,
  })  : _position = position,
        _size = size,
        _builder = builder;

  final int id;
  widgets.Offset _position;
  widgets.Size _size;
  ItemBuilder _builder;
  bool measured;

  widgets.Offset get position => _position;

  void setPosition(widgets.Offset value, {bool notify = true}) {
    if (_position == value) return;
    _position = value;
    if (notify) notifyListeners();
  }

  widgets.Size get size => _size;

  void setSize(widgets.Size value, {bool notify = true}) {
    if (_size == value) return;
    _size = value;
    if (notify) notifyListeners();
  }

  ItemBuilder get builder => _builder;

  T setBuilder<T extends ItemBuilder>(T value, {bool notify = true}) {
    if (_builder == value) return value;
    _builder = value;
    if (notify) notifyListeners();
    return value;
  }

  widgets.Rect get geometry => position & size;

  void setGeometry(widgets.Rect value, {bool notify = true}) {
    if (geometry == value) return;
    _position = value.topLeft;
    _size = value.size;
    if (notify) notifyListeners();
  }

  double get width => size.width;
  double get height => size.height;

  void shift(widgets.Offset delta, {bool notify = true}) =>
      setPosition(position + delta, notify: notify);

  void scale(double scaleFactor, {bool notify = true}) {
    if (scaleFactor == 1) return;
    setPosition(position * scaleFactor, notify: false);
    setSize(size * scaleFactor, notify: notify);
  }

  @override
  void dispose() {
    builder.dispose();
    super.dispose();
  }

  @override
  String toString() => 'Item(id: $id)';
}

extension ItemAnimations on Item {
  Future animateItemBuilder({
    required widgets.AnimatedItemBuilder builder,
    required TickerProvider vsync,
    required Duration duration,
    double? from = 0,
  }) {
    final originalBuilder = this.builder;
    final controller = AnimationController(
      vsync: vsync,
      duration: duration,
    );

    setBuilder(
      ItemBuilder.adaptAnimatedItemBuilder(
        builder,
        controller: controller,
      ),
      notify: false,
    );

    return controller.forward(from: from).whenComplete(() {
      setBuilder(originalBuilder);
      controller.dispose();
    });
  }

  Future animateRemovedItemBuilder({
    required widgets.AnimatedRemovedItemBuilder builder,
    required TickerProvider vsync,
    required Duration duration,
  }) {
    final from = this.builder.asAnimated?.stopAnimation() ?? 1.0;
    final controller = AnimationController(vsync: vsync, duration: duration);

    setBuilder(
      ItemBuilder.adaptAnimatedRemovedItemBuilder(
        builder,
        controller: controller,
      ),
      notify: false,
    );

    return controller.reverse(from: from);
  }
}
