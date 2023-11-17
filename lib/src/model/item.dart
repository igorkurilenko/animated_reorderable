import 'package:flutter/widgets.dart';

import 'item_builder.dart';

abstract class Item extends ChangeNotifier {
  final int id;
  Offset _location;
  Size _size;
  ItemBuilder _builder;

  Item({
    required this.id,
    required ItemBuilder builder,
    Offset? location,
    Size? size,
  })  : _location = location ?? Offset.zero,
        _size = size ?? Size.zero,
        _builder = builder;

  Offset get location => _location;
  void setLocation(Offset value, {bool notify = true}) {
    if (_location == value) return;
    _location = value;
    if (notify) notifyListeners();
  }

  Size get size => _size;
  void setSize(Size value, {bool notify = true}) {
    if (_size == value) return;
    _size = value;
    if (notify) notifyListeners();
  }

  ItemBuilder get builder => _builder;
  void setBuilder(ItemBuilder value, {bool notify = true}) {
    if (_builder == value) return;
    _builder = value;
    if (notify) notifyListeners();
  }

  Rect get geometry => location & size;
  void setGeometry(Rect value, {bool notify = true}) {
    if (geometry == value) return;
    _location = value.topLeft;
    _size = value.size;
    if (notify) notifyListeners();
  }

  double get width => size.width;
  double get height => size.height;

  void shiftSilent(Offset delta) => shift(delta, notify: false);

  void shift(Offset delta, {bool notify = true}) =>
      setLocation(location + delta, notify: notify);

  @override
  void dispose() {
    builder.dispose();
    super.dispose();
  }
}
