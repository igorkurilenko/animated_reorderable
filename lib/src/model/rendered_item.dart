part of 'model.dart';

/// An item that the list or grid has built, as the controller sees it.
abstract interface class RenderedItem {
  Key get key;
  int get index;
  BuildContext get context;
  bool get reorderable;
  SwipeDirection? get swipeToRemoveDirection;

  /// Where the list laid the item out on the screen, its slot, or null once
  /// it is unmounted.
  GlobalOffset? get globalPosition;

  /// Where the item shows on the screen: its slot, unless it is on its way
  /// there in place.
  GlobalOffset? get shownPosition;
  Size? get size;

  /// The constraints the list lays the item out with.
  BoxConstraints? get constraints;

  /// Whether the item's slot covers [point], a point on the screen.
  bool contains(GlobalOffset point);

  /// Moves the item in place, in the list, from where it shows now to the
  /// slot the list lays it out in next.
  void willMove();
}
