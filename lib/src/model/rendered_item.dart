part of 'model.dart';

/// An item that the list or grid has built, as the controller sees it.
abstract interface class RenderedItem {
  Key get key;
  int get index;
  BuildContext get context;
  bool get reorderable;
  SwipeDirection? get swipeToRemoveDirection;

  /// Where the item is on the screen, or null once it is unmounted.
  Offset? get globalPosition;
  Size? get size;

  /// The constraints the list lays the item out with.
  BoxConstraints? get constraints;

  /// Whether the item covers [point], a point on the screen.
  bool contains(Offset point);

  /// Builds the item again, as its placeholder or as itself.
  void rebuild();
}
