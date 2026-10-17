import 'package:flutter/widgets.dart';

import '../animated_reorderable.dart';
import '../model/model.dart';
import '../util/scheduling.dart';
import 'overlay_coordinator.dart';
import 'scroll_sync.dart';

/// A drag of an item, from its start to its end: the item follows the
/// pointer, takes the place of the items it is dragged over and scrolls
/// the view at its edges (GoF State).
class DragSession {
  DragSession({
    required this.item,
    required this.items,
    required this.overlay,
    required this.scrollSync,
    required this.widget,
    required this.reorderItem,
  });

  final OverlayedItem item;
  final ItemRegistry items;
  final OverlayCoordinator overlay;
  final ScrollSync scrollSync;

  /// The latest configuration.
  final ValueGetter<AnimatedReorderable> widget;
  final void Function(int index, {required int destIndex}) reorderItem;

  /// The rendered item the pointer was over, so the dragged item takes its
  /// place only once, when the pointer gets there.
  Key? _itemUnderThePointerKey;

  void start(DragStartDetails details) {
    final widget = this.widget();
    widget.onItemDragStart?.call(details, item.index);

    item.stopMotion();

    items.draggedItem = item;

    overlay.lift(
      item,
      decorator: widget.draggedItemDecorator,
      decorationDuration: widget.draggedItemDecorationAnimationDuration,
    );
  }

  void update(DragUpdateDetails details) {
    widget().onItemDragUpdate?.call(details, item.index);

    item.shift(details.delta);

    reorderAndAutoScroll();
  }

  void end(DragEndDetails details) {
    widget().onItemDragEnd?.call(details, item.index);

    items.draggedItem = null;

    scrollSync.stopAutoScroll(forceStopAnimation: true);

    overlay.flingBackToSlot(
      item,
      undecoration: item.animateUndecoration(),
      velocity: details.velocity,
    );
  }

  void reorderAndAutoScroll() {
    _reorderIfOverAnotherItem();
    scrollSync.autoScroll(overlay.globalRectOf(item));
  }

  void _reorderIfOverAnotherItem() {
    final widget = this.widget();
    final pointerPosition = item.globalPointerPosition;
    if (widget.onReorder == null || pointerPosition == null) return;
    if (!(widget.reorderableGetter?.call(item.index) ?? true)) return;

    final renderedItem = items.renderedItemAt(position: pointerPosition);

    if (renderedItem?.key == _itemUnderThePointerKey) return;
    _itemUnderThePointerKey = renderedItem?.key;

    if (renderedItem == null) return;
    if (renderedItem.key == item.key) return;
    if (!renderedItem.reorderable) return;

    reorderItem(item.index, destIndex: renderedItem.index);

    addPostFrame(
      () => _itemUnderThePointerKey = items
          .renderedItemAt(position: pointerPosition)
          ?.key,
    );
  }
}

/// A swipe of an item, from its start to its end: the item follows the
/// pointer along its swipe axis, and is flung out and removed or back to
/// its slot at the end (GoF State).
class SwipeSession {
  SwipeSession({
    required this.item,
    required this.items,
    required this.overlay,
    required this.widget,
  });

  final OverlayedItem item;
  final ItemRegistry items;
  final OverlayCoordinator overlay;

  /// The latest configuration.
  final ValueGetter<AnimatedReorderable> widget;

  void start(DragStartDetails details) {
    final widget = this.widget();
    widget.onItemSwipeStart?.call(details, item.index);

    item.stopMotion();

    items.swipedItem = item;

    overlay.lift(
      item,
      decorator: widget.swipedItemDecorator,
      decorationDuration: widget.swipedItemDecorationAnimationDuration,
    );
  }

  void update(DragUpdateDetails details) {
    widget().onItemSwipeUpdate?.call(details, item.index);

    item.shift(details.delta);
  }

  void end(DragEndDetails details) {
    final widget = this.widget();
    widget.onItemSwipeEnd?.call(details, item.index);

    items.swipedItem = null;

    final undecoration = item.animateUndecoration();
    final swipeDirection = item.swipeToRemoveDirection;
    final onSwipeToRemove = widget.onSwipeToRemove;
    final removes =
        swipeDirection?.removes(
          extent: item.swipeExtent,
          velocity: details.velocity,
          minExtent: widget.swipeToRemoveExtent,
          minVelocity: widget.swipeToRemoveVelocity,
        ) ??
        false;

    if (swipeDirection != null && onSwipeToRemove != null && removes) {
      onSwipeToRemove(item.index);

      overlay.flingOut(
        item,
        direction: swipeDirection,
        velocity: details.velocity,
        springDescription: widget.swipeToRemoveSpringDescription,
      );
    } else {
      overlay.flingBackToSlot(
        item,
        undecoration: undecoration,
        velocity: details.velocity,
        springDescription: widget.swipeToRemoveSpringDescription,
      );
    }
  }
}
