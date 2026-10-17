import 'package:flutter/widgets.dart';

/// Finds where a scroll position with new content dimensions keeps its
/// content in place, or returns null to leave the position as it is.
typedef ScrollOffsetAnchor = double? Function(ScrollMetrics position);

/// Scroll physics that let [anchor] move the position when the content
/// changes its dimensions, like a grid that gets fewer columns.
///
/// The position is corrected during layout, so the frame that lays out the
/// new dimensions already shows the content in place.
class AnchoredScrollPhysics extends ScrollPhysics {
  const AnchoredScrollPhysics({required this.anchor, super.parent});

  final ScrollOffsetAnchor anchor;

  @override
  AnchoredScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      AnchoredScrollPhysics(anchor: anchor, parent: buildParent(ancestor));

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    // Like RangeMaintainingScrollPhysics, leave a moving position alone.
    final pixels = velocity == 0.0
        ? anchor(newPosition)
              ?.clamp(newPosition.minScrollExtent, newPosition.maxScrollExtent)
        : null;
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: pixels == null
          ? newPosition
          : newPosition.copyWith(pixels: pixels),
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}
