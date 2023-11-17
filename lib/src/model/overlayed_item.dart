import 'item.dart';

class OverlayedItem extends Item {
  OverlayedItem({
    required super.id,
    required super.builder,
    required super.location,
    required super.size,
    required this.index,
    required bool draggable,
    required this.reorderable,
  }) : _draggable = draggable;

  bool _draggable;
  final bool reorderable;
  int index;

  bool get draggable => _draggable;
  void setDraggable(bool value, {bool notify = true}) {
    if (draggable == value) return;
    _draggable = value;
    if (notify) notifyListeners();
  }
}
