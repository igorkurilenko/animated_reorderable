import 'package:flutter/widgets.dart';

/// Finds where a scroll position with new content dimensions keeps its
/// content in place, or returns null to leave the position as it is.
typedef ScrollOffsetAnchor = double? Function(ScrollMetrics position);

/// Scroll physics that let [anchor] move the position when the content
/// changes its dimensions, like a grid that gets fewer columns, and tell
/// [onAdjust] how far the position moves otherwise, like a list that
/// shrinks under its offset.
///
/// The position is corrected during layout, so the frame that lays out the
/// new dimensions already shows the content in place.
class AnchoredScrollPhysics extends ScrollPhysics {
  const AnchoredScrollPhysics({
    required this.anchor,
    this.onAdjust,
    super.parent,
  });

  final ScrollOffsetAnchor anchor;

  /// Called during layout with how far, in pixels, the parent physics move
  /// a position that [anchor] leaves as it is, like one that comes back
  /// within the range of content that shrank under it.
  final ValueChanged<double>? onAdjust;

  @override
  AnchoredScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      AnchoredScrollPhysics(
        anchor: anchor,
        onAdjust: onAdjust,
        parent: buildParent(ancestor),
      );

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    // Like RangeMaintainingScrollPhysics, leave a moving position alone.
    final anchored = velocity == 0.0
        ? anchor(newPosition)
              ?.clamp(newPosition.minScrollExtent, newPosition.maxScrollExtent)
        : null;
    final pixels = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: anchored == null
          ? newPosition
          : newPosition.copyWith(pixels: anchored),
      isScrolling: isScrolling,
      velocity: velocity,
    );
    if (anchored == null && pixels != newPosition.pixels) {
      onAdjust?.call(pixels - newPosition.pixels);
    }
    return pixels;
  }
}
