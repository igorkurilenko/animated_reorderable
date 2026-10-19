import 'package:flutter/widgets.dart';

import '../const.dart';
import '../util/scheduling.dart';

/// Keeps up with a view around the list that scrolls across it, such as a
/// board of lists that scrolls sideways: auto-scrolling it for a dragged
/// item, and how it scrolls.
class BoardScroll {
  BoardScroll({
    required this.velocityScalar,
    required this.onScroll,
    required this.onAutoScroll,
  });

  final double Function() velocityScalar;

  /// Called once after each frame in which the board scrolled, once the
  /// frame has laid out the list where the board took it.
  final VoidCallback onScroll;

  /// Called after the auto-scroller scrolled the board.
  final VoidCallback onAutoScroll;

  ScrollableState? _board;
  ScrollPosition? _position;
  EdgeDraggingAutoScroller? _autoScroller;
  var _scrollReportScheduled = false;

  set board(ScrollableState? value) {
    final position = value?.position;
    if (_board == value && _position == position) return;
    _autoScroller?.stopAutoScroll();
    _autoScroller = null;
    _position?.removeListener(_handleScroll);
    _board = value;
    _position = position?..addListener(_handleScroll);
  }

  void _handleScroll() {
    if (_scrollReportScheduled) return;
    _scrollReportScheduled = true;
    addPostFrame(() {
      _scrollReportScheduled = false;
      onScroll();
    });
  }

  /// Scrolls the board while [draggedItem], a rectangle on the screen, is
  /// at one of its edges.
  void autoScroll(Rect draggedItem) {
    final board = _board;
    if (board == null) return;
    (_autoScroller ??= EdgeDraggingAutoScroller(
      board,
      velocityScalar: velocityScalar(),
      onScrollViewScrolled: onAutoScroll,
    )).startAutoScrollIfNecessary(draggedItem.deflate(autoScrollEdgeInset));
  }

  void stopAutoScroll() => _autoScroller?.stopAutoScroll();

  void dispose() => _position?.removeListener(_handleScroll);
}
