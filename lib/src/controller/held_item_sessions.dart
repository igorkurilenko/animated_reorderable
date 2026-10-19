import 'package:flutter/widgets.dart';

import '../animated_reorderable_controller.dart';
import '../options.dart';
import '../model/model.dart';
import '../util/scheduling.dart';
import 'overlay_coordinator.dart';
import 'scroll_sync.dart';

/// A drag of an item, from its start to its end: the item follows the
/// pointer, takes the place of the items it is dragged over and scrolls
/// the view at its edges. In a group, it goes to the group's other lists
/// as it is dragged over them (GoF State).
class DragSession {
  DragSession({required this.item, required this._host});

  final OverlayedItem item;
  AnimatedReorderableController _host;

  /// The list the item is in, which changes as it goes to another list of
  /// its group.
  AnimatedReorderableController get host => _host;

  /// The list the app didn't let the item go to, while the pointer is over
  /// it, so the app is asked once.
  AnimatedReorderableController? _refusedBy;

  ItemRegistry get items => _host.registry;
  OverlayCoordinator get overlay => _host.overlayCoordinator!;
  ScrollSync get scrollSync => _host.scrollSync;

  /// The latest options of the item's list.
  ReorderOptions get _options => _host.reorder;

  /// The rendered item the pointer was over, so the dragged item takes its
  /// place only once, when the pointer gets there.
  Key? _itemUnderThePointerKey;

  void start(DragStartDetails details) {
    final options = _options;
    options.callbacks.onStart?.call(details, item.index);

    item.stopMotion();

    items.draggedItem = item;

    // A group's layer shows it, so it can go over the group's other lists.
    final group = _host.groupForDrags;
    group?.host(item, _host);
    overlay.lift(
      item,
      decorator: options.decoration.decorator,
      decorationDuration: options.decoration.duration,
      sharedSpace: group,
    );
  }

  void update(DragUpdateDetails details) {
    _options.callbacks.onUpdate?.call(details, item.index);

    item.shift(details.delta);

    followPointer();
  }

  /// Takes the item to the list and the place under the pointer, and
  /// scrolls what it is at the edge of.
  void followPointer() {
    _moveToAnotherListIfOverOne();
    reorderAndAutoScroll();
  }

  void end(DragEndDetails details) {
    _options.callbacks.onEnd?.call(details, item.index);

    items.draggedItem = null;

    scrollSync.stopAutoScroll(forceStopAnimation: true);

    overlay.flingBackToSlot(
      item,
      undecoration: item.animateUndecoration(),
      velocity: details.velocity,
    );
    _host.didEndDrag(this);
  }

  void reorderAndAutoScroll() {
    _reorderIfOverAnotherItem();
    final rect = overlay.globalRectOf(item);
    scrollSync.autoScroll(rect);
    _host.autoScrollBoard(rect);
  }

  /// Moves the item to the list of its group that the pointer is over, if
  /// the app lets it.
  void _moveToAnotherListIfOverOne() {
    final group = _host.groupForDrags;
    final pointer = item.globalPointerPosition;
    if (group == null || pointer == null || item.sharedSpace != group) return;
    final to = group.memberAt(pointer);
    if (to != _refusedBy) _refusedBy = null;
    if (to == null || to == _host || to == _refusedBy) return;
    if (!group.moveHeldItem(this, to: to, index: to.dropIndexAt(pointer))) {
      _refusedBy = to;
      return;
    }
    _host = to;
    // It takes the place of the item it went in at, not the next one.
    _itemUnderThePointerKey = items.renderedItemAt(position: pointer)?.key;
  }

  void _reorderIfOverAnotherItem() {
    final options = _options;
    final pointerPosition = item.globalPointerPosition;
    if (options.onReorder == null || pointerPosition == null) return;
    if (!(options.reorderableGetter?.call(item.index) ?? true)) return;

    final renderedItem = items.renderedItemAt(position: pointerPosition);

    if (renderedItem?.key == _itemUnderThePointerKey) return;
    _itemUnderThePointerKey = renderedItem?.key;

    if (renderedItem == null) return;
    if (renderedItem.key == item.key) return;
    if (!renderedItem.reorderable) return;

    _host.reorderItem(item.index, destIndex: renderedItem.index);

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
    required this.options,
  });

  final OverlayedItem item;
  final ItemRegistry items;
  final OverlayCoordinator overlay;

  /// The latest options.
  final ValueGetter<SwipeToRemoveOptions> options;

  void start(DragStartDetails details) {
    final options = this.options();
    options.callbacks.onStart?.call(details, item.index);

    item.stopMotion();

    items.swipedItem = item;

    overlay
      ..lift(
        item,
        decorator: options.decoration.decorator,
        decorationDuration: options.decoration.duration,
      )
      ..moveSwipedItemToSlot(item);
  }

  void update(DragUpdateDetails details) {
    options().callbacks.onUpdate?.call(details, item.index);

    item.shift(details.delta);
  }

  void end(DragEndDetails details) {
    final options = this.options();
    options.callbacks.onEnd?.call(details, item.index);

    items.swipedItem = null;

    final undecoration = item.animateUndecoration();
    final swipeDirection = item.swipeToRemoveDirection;
    final onSwipeToRemove = options.onSwipeToRemove;
    final removes =
        swipeDirection?.removes(
          extent: item.swipeExtent,
          velocity: details.velocity,
          minExtent: options.extent,
          minVelocity: options.velocity,
        ) ??
        false;

    if (swipeDirection != null && onSwipeToRemove != null && removes) {
      onSwipeToRemove(item.index);

      overlay.flingOut(
        item,
        direction: swipeDirection,
        velocity: details.velocity,
        springDescription: options.springDescription,
      );
    } else {
      overlay.flingBackToSlot(
        item,
        undecoration: undecoration,
        velocity: details.velocity,
        springDescription: options.springDescription,
      );
    }
  }
}
