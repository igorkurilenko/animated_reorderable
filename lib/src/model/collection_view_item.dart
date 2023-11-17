import 'package:flutter/widgets.dart';

import 'item.dart';

class CollectionViewItem extends Item {
  CollectionViewItem({
    required super.id,
    required super.builder,
    super.location,
    super.size,
    bool draggable = true,
    bool reorderable = true,
    AxisDirection? swipeAwayDirection,
    bool overlayed = false,
  })  : _draggable = draggable,
        _reorderable = reorderable,
        _swipeAwayDirection = swipeAwayDirection,
        _overlayed = overlayed;

  bool _draggable;
  bool _reorderable;
  AxisDirection? _swipeAwayDirection;
  bool _overlayed;

  bool get draggable => _draggable;
  void setDraggable(bool value, {bool notify = true}) {
    if (_draggable == value) return;
    _draggable = value;
    if (notify) notifyListeners();
  }

  bool get reorderable => _reorderable;
  void setReorderable(bool value, {bool notify = true}) {
    if (_reorderable == value) return;
    _reorderable = value;
    if (notify) notifyListeners();
  }

  bool get swipeable => _swipeAwayDirection != null;
  AxisDirection? get swipeDirection => _swipeAwayDirection;
  void setSwipeDirection(AxisDirection? value, {bool notify = true}) {
    if (_swipeAwayDirection == value) return;
    _swipeAwayDirection = value;
    if (notify) notifyListeners();
  }

  bool get overlayed => _overlayed;
  void setOverlayed(bool value, {bool notify = true}) {
    if (_overlayed == value) return;
    _overlayed = value;
    if (notify) notifyListeners();
  }

  @override
  String toString() => 'CollectionViewItem(id: $id)';
}
