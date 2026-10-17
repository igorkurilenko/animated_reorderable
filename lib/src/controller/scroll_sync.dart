import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../const.dart';
import '../util/geometry.dart';
import '../util/scheduling.dart';

/// Keeps up with the wrapped view's scrolling: which scroll position is the
/// view's, how far it scrolled, auto-scrolling for a dragged item, and the
/// grid's layout, which keeps the first visible item in place when the
/// grid's cross axis resizes.
class ScrollSync {
  ScrollSync({
    required this.isOwnPosition,
    required this.velocityScalar,
    required this.itemCount,
    required this.onScroll,
    required this.onAutoScroll,
  });

  /// Whether a position of the scroll controller is the wrapped view's.
  final bool Function(ScrollPosition position) isOwnPosition;
  final double Function() velocityScalar;
  final int Function() itemCount;

  /// Called with how far the content moved on the screen since the last
  /// time, as the view scrolls.
  final ValueChanged<Offset> onScroll;

  /// Called after the auto-scroller scrolled the view.
  final VoidCallback onAutoScroll;

  ScrollController? _scrollController;
  EdgeDraggingAutoScroller? _autoScroller;
  Offset _scrollOffset = Offset.zero;
  SliverGridLayout? _gridLayout;

  /// The scroll extent before the grid, like its padding.
  double _gridPrecedingScrollExtent = 0.0;

  /// The first visible item of the grid before its cross axis resized:
  /// its index, its leading edge relative to the viewport's and its main
  /// axis extent.
  ({int index, double leadingEdge, double extent})? _scrollAnchor;

  ScrollController? get scrollController => _scrollController;

  set scrollController(ScrollController? value) {
    if (_scrollController == value) return;
    addPostFrame(() {
      _setUpAutoScroller();
      markScrollOffset();
    });
    _scrollController?.removeListener(_handleScroll);
    (_scrollController = value)?.addListener(_handleScroll);
  }

  /// The position of the wrapped view's own [Scrollable]. The scroll
  /// controller can be shared, like the [PrimaryScrollController], so it
  /// can have other positions too.
  ScrollPosition? get scrollPosition =>
      _scrollController?.positions.where(isOwnPosition).firstOrNull;

  /// The grid's layout, or null for a list.
  SliverGridLayout? get gridLayout => _gridLayout;

  void _setUpAutoScroller() {
    final scrollPosition = this.scrollPosition;
    if (scrollPosition == null) return;

    _autoScroller = EdgeDraggingAutoScroller(
      scrollPosition.context as ScrollableState,
      velocityScalar: velocityScalar(),
      onScrollViewScrolled: onAutoScroll,
    );
  }

  /// Scrolls the view while [draggedItem], a rectangle on the screen, is at
  /// one of its edges.
  void autoScroll(Rect draggedItem) => _autoScroller
      ?.startAutoScrollIfNecessary(draggedItem.deflate(autoScrollEdgeInset));

  void stopAutoScroll({bool forceStopAnimation = false}) {
    _autoScroller?.stopAutoScroll();

    final scrollPosition = this.scrollPosition;
    if (forceStopAnimation && scrollPosition != null) {
      scrollPosition.jumpTo(scrollPosition.pixels);
    }
  }

  void _handleScroll() => onScroll(markScrollOffset());

  /// Takes the current scroll offset as the baseline, and returns how far
  /// the content moved on the screen since the last one.
  Offset markScrollOffset() {
    final scrollPosition = this.scrollPosition;
    if (scrollPosition == null) return Offset.zero;

    final scrollOffset = scrollPosition.toRelativeOffset();
    final delta = scrollOffset - _scrollOffset;
    _scrollOffset = scrollOffset;
    return delta;
  }

  void didLayOutGrid(SliverGridLayout layout, SliverConstraints constraints) {
    _gridLayout = layout;
    _gridPrecedingScrollExtent = constraints.precedingScrollExtent;
  }

  /// Remembers the first visible item before the grid lays out again.
  ///
  /// A grid's layout changes with its cross axis, so a grid keeps its
  /// first visible item in place when the cross axis resizes. A list needs
  /// nothing: its items keep their scroll offsets, as in a plain
  /// [ListView].
  void anchorFirstVisibleGridItem() {
    final layout = _gridLayout;
    final itemCount = this.itemCount();
    final scrollPosition = this.scrollPosition;
    if (layout == null || itemCount == 0) return;
    if (scrollPosition == null || !scrollPosition.hasPixels) return;

    final scrollOffset = scrollPosition.pixels - _gridPrecedingScrollExtent;
    final index = math.min(
      layout.getMinChildIndexForScrollOffset(math.max(0.0, scrollOffset)),
      itemCount - 1,
    );
    final geometry = layout.getGeometryForChildIndex(index);
    _scrollAnchor = (
      index: index,
      leadingEdge: geometry.scrollOffset - scrollOffset,
      extent: geometry.mainAxisExtent,
    );
    addPostFrame(() => _scrollAnchor = null);

    // Makes the viewport ask its physics for a correction even if the
    // grid's scroll extent stays the same.
    scrollPosition.correctBy(0.0);
  }

  /// The scroll offset that keeps the anchored item in place in the grid's
  /// new layout. The grid has laid out by the time its viewport asks.
  double? anchoredScrollOffset(ScrollMetrics position) {
    final anchor = _scrollAnchor;
    final layout = _gridLayout;
    if (anchor == null || layout == null) return null;
    _scrollAnchor = null;

    final geometry = layout.getGeometryForChildIndex(anchor.index);
    // An item partly scrolled away keeps the same part of it hidden.
    final leadingEdge = anchor.leadingEdge < 0 && anchor.extent > 0
        ? anchor.leadingEdge * geometry.mainAxisExtent / anchor.extent
        : anchor.leadingEdge;
    return _gridPrecedingScrollExtent + geometry.scrollOffset - leadingEdge;
  }

  void dispose() => _scrollController?.removeListener(_handleScroll);
}
