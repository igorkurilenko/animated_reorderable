part of model;

abstract class Item extends widgets.ChangeNotifier {
  final int id;
  widgets.Offset _location;
  widgets.Size _size;
  ItemBuilder _builder;

  Item({
    required this.id,
    required ItemBuilder builder,
    widgets.Offset? location,
    widgets.Size? size,
  })  : _location = location ?? widgets.Offset.zero,
        _size = size ?? widgets.Size.zero,
        _builder = builder;

  widgets.Offset get location => _location;
  void setLocation(widgets.Offset value, {bool notify = true}) {
    if (_location == value) return;
    _location = value;
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

  widgets.Rect get geometry => location & size;
  void setGeometry(widgets.Rect value, {bool notify = true}) {
    if (geometry == value) return;
    _location = value.topLeft;
    _size = value.size;
    if (notify) notifyListeners();
  }

  double get width => size.width;
  double get height => size.height;

  void shiftSilent(widgets.Offset delta) => shift(delta, notify: false);

  void shift(widgets.Offset delta, {bool notify = true}) =>
      setLocation(location + delta, notify: notify);

  @override
  void dispose() {
    builder.dispose();
    super.dispose();
  }
}

extension ItemExtension on Item {
  AnimatedDecoratedItemBuilder? decorateBuilder(
    AnimatedItemDecorator? decorator, {
    required String decoratorId,
    required TickerProvider vsync,
    required Duration duration,
    bool notify = true,
  }) =>
      decorator != null
          ? decoratedBuilder(decoratorId: decoratorId) ??
              setBuilder(
                AnimatedDecoratedItemBuilder(
                  builder,
                  decoratorId: decoratorId,
                  decorator: decorator,
                  controller: AnimationController(
                    vsync: vsync,
                    duration: duration,
                  ),
                ),
                notify: notify,
              )
          : null;

  AnimatedDecoratedItemBuilder? decoratedBuilder({
    required String decoratorId,
  }) =>
      switch (builder) {
        final AnimatedDecoratedItemBuilder b
            when b.decoratorId == decoratorId =>
          b,
        _ => null,
      };
}
