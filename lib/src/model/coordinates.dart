import 'package:flutter/widgets.dart';

/// A point on the screen, in the global coordinates of the render tree.
extension type const GlobalOffset(Offset offset) implements Offset {}

/// A point in the overlay, the space the overlayed items are positioned
/// in. Only the overlay converts between it and [GlobalOffset].
extension type const OverlayOffset(Offset offset) implements Offset {
  /// This point moved by [delta].
  OverlayOffset operator +(Offset delta) => OverlayOffset(offset + delta);
}

/// The space overlayed items are positioned in. It covers the list.
abstract interface class OverlaySpace {
  OverlayOffset globalToLocal(GlobalOffset point);
  GlobalOffset localToGlobal(OverlayOffset point);
  Size get size;
}
