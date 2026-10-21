import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../animated_reorderable.dart' show MultiDragGestureRecognizerFactory;
import '../const.dart';
import '../model/model.dart';
import '../model/swipe_direction.dart';
import '../util/key_map.dart';
import '../util/scheduling.dart';
import '../widget/item_widget.dart' show ViewEdge;
import 'scroll_sync.dart';

/// Moves items between the list and the overlay above it.
///
/// It exists while the overlay is mounted: the controller creates one when
/// the overlay attaches and drops it when the overlay detaches. Code that
/// needs the overlay runs only while it has one.
class OverlayCoordinator {
  OverlayCoordinator({
    required this.overlay,
    required this.items,
    required this.scrollSync,
    required this.vsync,
    required this.motionAnimationDuration,
    required this.motionAnimationCurve,
    required this.scrollDirection,
  });

  final OverlaySpace overlay;
  final ItemRegistry items;
  final ScrollSync scrollSync;
  final TickerProvider vsync;
  final ValueGetter<Duration> motionAnimationDuration;
  final ValueGetter<Curve> motionAnimationCurve;
  final ValueGetter<Axis> scrollDirection;

  bool _isHeld(Key key) =>
      items.isDragged(key: key) || items.isSwiped(key: key);

  /// The space [item] is positioned in: its group's layer while that shows
  /// it, or else the list's overlay.
  OverlaySpace spaceOf(OverlayedItem item) => item.sharedSpace ?? overlay;

  OverlayedItem createOverlayedItem(
    RenderedItem renderedItem, {
    MultiDragGestureRecognizerFactory? recognizerFactory,
    Item? item,
  }) => OverlayedItem(
    item: item ?? items.itemBy(key: renderedItem.key)!,
    index: renderedItem.index,
    // Where it shows, which may be on its way to its slot in place.
    position: overlay.globalToLocal(renderedItem.shownPosition!),
    // The item lays out in the overlay as it would in the list.
    constraints:
        renderedItem.constraints ?? BoxConstraints.tight(renderedItem.size!),
    size: renderedItem.size!,
    recognizerFactory: recognizerFactory,
  );

  /// Moves the rendered items whose index a change moved, except [except]
  /// and the held ones, to their new slots, once the list lays them out
  /// there.
  ///
  /// The list paints an item only in a slot that shows, so an item moves in
  /// place, in the list, to a slot that shows, even from out of sight. An
  /// item that shows now and goes out of sight moves through the overlay.
  /// An item that shows neither now nor in its new slot doesn't move at
  /// all, and one that keeps its index keeps its slot.
  ///
  /// The new indexes come from the model, which the change has moved
  /// already. After another change in the same frame, the list may not
  /// have built its items again yet: they are still where the list laid
  /// them out, and removed items stay as they are.
  void moveRenderedItems({Key? except}) {
    final indexOf = items.childIndexGetter();
    final slots = {for (final x in items.renderedItems) x.index: x};
    for (var renderedItem
        in items.renderedItems
            .where((x) => x.key != except)
            .where((x) => items.itemBy(key: x.key) != null)
            .where((x) => !_isHeld(x.key))
            .toList()) {
      var overlayedItem = items.overlayedItemBy(key: renderedItem.key);
      if (overlayedItem == null) {
        final index = indexOf(renderedItem.key);
        if (index == null || index == renderedItem.index) continue;
        if (_shows(slots[index], at: (x) => x.globalPosition)) {
          renderedItem.willMove();
          continue;
        }
        if (!_shows(renderedItem, at: (x) => x.shownPosition)) continue;
        overlayedItem = items.putOverlayedItem(
          createOverlayedItem(renderedItem)..index = index,
        );
      }
      overlayedItem.setInteractive(false);
    }
  }

  /// Whether [item] shows in the overlay, which covers the list, if it is
  /// [at] where it is.
  bool _shows(
    RenderedItem? item, {
    required GlobalOffset? Function(RenderedItem item) at,
  }) {
    if (item == null) return false;
    final position = at(item);
    final size = item.size;
    if (position == null || size == null) return false;
    return (overlay.globalToLocal(position) & size).overlaps(
      Offset.zero & overlay.size,
    );
  }

  /// The edges of the view that items a change brought into sight come in
  /// through, by key, until the frame after the change is over.
  final _entering = keyMap<({ViewEdge edge, Object change})>();

  /// Lets [item], which was at [index] out of sight, come in through the
  /// edge of the view nearest to where it was, if the list lays it out in
  /// a slot that shows in the next frame. It moves in place then, from just
  /// outside the view, at its own size. An item the list doesn't show then
  /// comes into sight later as any item does.
  void enterNotRenderedItem(Item item, {required int index}) {
    if (items.isRendered(key: item.key)) return;
    if (items.isOverlayed(key: item.key)) return;
    final renderedIndexes = items.renderedItems.map((x) => x.index);
    if (renderedIndexes.isEmpty) return;
    final change = Object();
    _entering[item.key] = (
      edge: index < renderedIndexes.reduce(math.min)
          ? ViewEdge.leading
          : ViewEdge.trailing,
      change: change,
    );
    addPostFrame(() {
      if (_entering[item.key]?.change == change) _entering.remove(item.key);
    });
  }

  /// The edge of the view that the item with [key] comes in through, once.
  ViewEdge? takeEntry(Key key) => _entering.remove(key)?.edge;

  /// Animates [removedItem] out with [builder] where the list showed it as
  /// [renderedItem], or lets it go if the list did not show it.
  void animateOut(
    Item removedItem, {
    required RenderedItem? renderedItem,
    required AnimatedRemovedItemBuilder builder,
    required Duration duration,
    required int zIndex,
  }) {
    if (renderedItem == null) {
      items.releaseRemovedItem(removedItem);
      return;
    }

    // It leaves its key to an item the list may show with it.
    final outgoingItem = items.putOutgoingItem(
      key: renderedItem.key,
      ifAbsent: () => createOverlayedItem(renderedItem, item: removedItem),
    );
    items.setZIndex(outgoingItem, zIndex);
    outgoingItem
      // It keeps its size while it goes.
      ..setConstraints(BoxConstraints.tight(outgoingItem.size))
      ..setInteractive(false);
    final gone = outgoingItem.swipedAway
        ? _goAsItIs(outgoingItem, removedItem, duration: duration)
        : removedItem.animateRemovedItemBuilder(
            builder: builder,
            duration: duration,
            vsync: vsync,
          );
    gone.whenComplete(() => items.removeOutgoingItem(outgoingItem));
  }

  /// Lets [removedItem], which [outgoingItem] shows swiped away, go as it
  /// is: its throw is all of its going, so the removed item builder doesn't
  /// build it. It is gone once it is out of sight and [duration] is over.
  Future _goAsItIs(
    OverlayedItem outgoingItem,
    Item removedItem, {
    required Duration duration,
  }) => Future.wait([
    removedItem.leaveAsItIs(
      outgoingItem.builtChild,
      vsync: vsync,
      duration: duration,
    ),
    outgoingItem.thrown,
  ]);

  /// Takes [item] out of the overlay once it gets where it moved, unless
  /// the list has yet to lay it out at its index: its place moves as it
  /// gets there, and the reconcile after the layout moves it on.
  void land(OverlayedItem item) {
    final renderedItem = items.renderedItemBy(key: item.key);
    if (renderedItem != null && renderedItem.index != item.index) return;
    unoverlay(item);
  }

  void unoverlay(OverlayedItem item) {
    if (items.overlayedItemBy(key: item.key) != item) return;
    items.removeOverlayedItem(key: item.key);
    item.sharedSpace?.unhost(item);
    item.sharedSpace = null;
    addPostFrame(() {
      if (items.overlayedItemBy(key: item.key) != item) {
        items.disposeOverlayedItem(item);
      }
    });
  }

  /// Where an item of [itemSize] that the list did not build at
  /// [notRenderedItemIndex] would be: just outside the overlay, before or
  /// after [anyRenderedItem]. Null while the view has no scroll position.
  Rect? getFakeAnchorGeometryOfNotRenderedItem({
    required int notRenderedItemIndex,
    required RenderedItem anyRenderedItem,
    required Size itemSize,
  }) {
    final scrollPosition = scrollSync.scrollPosition;
    if (scrollPosition == null) return null;

    final gridLayout = scrollSync.gridLayout;

    // Just outside the overlay, which covers the list. It is the space the
    // overlayed items are positioned in, unlike the screen.
    final bounds = Offset.zero & overlay.size;
    // In line with a list's items, or in the middle of a grid.
    final anyRenderedItemPosition = gridLayout == null
        ? anyRenderedItem.globalPosition
        : null;
    final crossAxisPosition = anyRenderedItemPosition != null
        ? overlay.globalToLocal(anyRenderedItemPosition)
        : bounds.center - Offset(itemSize.width / 2, itemSize.height / 2);
    final before = notRenderedItemIndex < anyRenderedItem.index;
    final fakePosition = switch (scrollPosition.axisDirection) {
      AxisDirection.down => Offset(
        crossAxisPosition.dx,
        before ? bounds.top - itemSize.height : bounds.bottom,
      ),
      AxisDirection.right => Offset(
        before ? bounds.left - itemSize.width : bounds.right,
        crossAxisPosition.dy,
      ),
      AxisDirection.up => Offset(
        crossAxisPosition.dx,
        before ? bounds.bottom : bounds.top - itemSize.height,
      ),
      AxisDirection.left => Offset(
        before ? bounds.right : bounds.left - itemSize.width,
        crossAxisPosition.dy,
      ),
    };

    return fakePosition & itemSize;
  }

  /// Moves the overlayed item of [item] to where the list laid [item] out.
  void reconcileItem(RenderedItem item) {
    final overlayedItem = items.overlayedItemBy(key: item.key);
    if (overlayedItem == null) return;
    final dragged = items.isDragged(key: item.key);

    // They change when the list resizes.
    final constraints = item.constraints;
    if (constraints != null && constraints != overlayedItem.constraints) {
      overlayedItem.setConstraints(constraints);
      if (dragged) {
        // Its new size, unless its main axis extent changes too.
        final size = constraints.constrain(overlayedItem.size);
        keepUnderPointer(overlayedItem, size: size);
        items.setOverlayedItemSize(overlayedItem, size);
      }
    }

    if (dragged) return;

    final globalPosition = item.globalPosition;
    if (globalPosition == null) return;

    final anchorPosition = spaceOf(overlayedItem).globalToLocal(globalPosition);

    if (items.isSwiped(key: item.key)) {
      // It stays in its slot, swiped as far, and heads anew for a slot that
      // moved while it was on its way there.
      final swiped = anchorPosition + overlayedItem.swipeOffset;
      if (overlayedItem.motionAnimationStatus?.isAnimating ?? false) {
        overlayedItem.animateTo(
          swiped,
          vsync: vsync,
          duration: motionAnimationDuration(),
          curve: motionAnimationCurve(),
        );
      } else {
        overlayedItem.setPosition(swiped);
      }
      return;
    }

    // Rounding leaves an item a hair off its slot after a scroll by a
    // fraction of a pixel, which is no reason to head for it anew.
    final offCourse = overlayedItem.anchorPosition - anchorPosition;
    if (offCourse.distance >= retargetTolerance) {
      overlayedItem
          .animateTo(
            anchorPosition,
            vsync: vsync,
            duration: motionAnimationDuration(),
            curve: motionAnimationCurve(),
          )
          .whenComplete(() => land(overlayedItem));
    } else if (!overlayedItem.isAnimating) {
      // On its slot and done. One let go still takes off its decoration,
      // or flies to its new look, and lands once it has.
      unoverlay(overlayedItem);
    }
  }

  /// Moves each overlayed item whose slot [test] picks to where the list
  /// laid the slot out.
  void reconcileOverlayedItems(
    bool Function(OverlayedItem item, RenderedItem slot) test,
  ) {
    for (final item in items.overlayedItems.toList()) {
      if (items.renderedItemBy(key: item.key) case final slot?
          when test(item, slot)) {
        reconcileItem(slot);
      }
    }
  }

  /// Fits removed items to the layout and moves the overlayed items that
  /// the list did not build out of sight.
  void reconcileItemsLayer() {
    fitOutgoingItemsToLayout();

    for (var overlayedItem
        in items.overlayedItems
            .where((x) => !items.isRendered(key: x.key))
            // A held item stays under the pointer, whatever the list shows.
            .where((x) => !_isHeld(x.key))
            .toList()) {
      final fakeGeometry = getFakeAnchorGeometryOfNotRenderedItem(
        notRenderedItemIndex: overlayedItem.index,
        anyRenderedItem: items.renderedItems.first,
        itemSize: overlayedItem.size,
      );
      if (fakeGeometry == null) return;

      overlayedItem
          .animateTo(
            OverlayOffset(fakeGeometry.topLeft),
            vsync: vsync,
            duration: motionAnimationDuration(),
            curve: motionAnimationCurve(),
          )
          .whenComplete(() => land(overlayedItem));
    }
  }

  /// A removed item has no slot any more. It fades out in place, as wide
  /// as the list's slots (or as big as the grid's) after a resize.
  void fitOutgoingItemsToLayout() {
    for (var item in items.outgoingItems) {
      final slot =
          items.renderedItems.where((x) => x.index == item.index).firstOrNull ??
          items.renderedItems.firstOrNull;
      final constraints = slot?.constraints;
      if (constraints == null) continue;
      item.setConstraints(
        constraints.tighten(width: item.size.width, height: item.size.height),
      );
    }
  }

  /// Takes [item], swiped while it moved in place, on to its slot along
  /// the list, as the swipe moves it across.
  void moveSwipedItemToSlot(OverlayedItem item) {
    final slot = items.renderedItemBy(key: item.key)?.globalPosition;
    if (slot == null) return;
    final swiped = overlay.globalToLocal(slot) + item.swipeOffset;
    if ((item.position - swiped).distance < retargetTolerance) return;
    item.animateTo(
      swiped,
      vsync: vsync,
      duration: motionAnimationDuration(),
      curve: motionAnimationCurve(),
    );
  }

  /// The list's placeholder follows the item's size in the overlay.
  void didResizeItem(Size size, OverlayedItem item) {
    if (item.size == size) return;
    if (item == items.draggedItem) keepUnderPointer(item, size: size);
    items.setOverlayedItemSize(item, size);
  }

  /// The item laid out at [size], which the frame paints it at: a dragged
  /// item stays under the pointer in that frame, rather than in the next.
  void didLayOutItem(Size size, OverlayedItem item) {
    if (item == items.draggedItem) item.keepPointerAsLaidOut(size);
  }

  /// Keeps the pointer over the same point of a dragged item, relative to
  /// its size, when the item is about to change its [size].
  void keepUnderPointer(OverlayedItem item, {required Size size}) {
    final anchored = item.anchoredSize;
    final globalPointerPosition = item.globalPointerPosition;
    if (globalPointerPosition == null || anchored.isEmpty) {
      item.anchorTo(size);
      return;
    }
    final pointer = spaceOf(item).globalToLocal(globalPointerPosition);
    final grip = pointer - item.position;
    final position = OverlayOffset(
      pointer -
          Offset(
            grip.dx * size.width / anchored.width,
            grip.dy * size.height / anchored.height,
          ),
    );
    item
      ..setPosition(position)
      ..anchorTo(size, pointerOffset: pointer - position);
  }

  /// The overlayed items move with the content as the view scrolls, except
  /// the held ones, which stay under the pointer. One that lands in a
  /// group's layer goes out of sight at the list's edges from then on.
  void shiftOverlayedItems(Offset delta) {
    if (delta == Offset.zero) return;
    for (var x
        in [...items.overlayedItems, ...items.outgoingItems]
            .where((x) => x != items.draggedItem)
            .where((x) => x != items.swipedItem)) {
      x.shift(-delta);
      if (x.sharedSpace != null) x.setClippedToList(true);
    }
  }

  /// Where [item] is on the screen.
  Rect globalRectOf(OverlayedItem item) =>
      spaceOf(item).localToGlobal(item.position) & item.size;

  /// Lifts [item] above the other items, into the overlay if it is not
  /// there yet, or into [sharedSpace], a group's layer, and decorates it
  /// with [decorator].
  void lift(
    OverlayedItem item, {
    required AnimatedItemDecorator? decorator,
    required Duration decorationDuration,
    SharedOverlaySpace? sharedSpace,
  }) {
    final overlayed = items.isOverlayed(key: item.key);
    // From where it shows now. It was made as the pointer went down, and a
    // long press later the item may have moved on in place since.
    final shown = overlayed
        ? spaceOf(item).localToGlobal(item.position)
        : items.renderedItemBy(key: item.key)?.shownPosition;
    if (sharedSpace != null) item.sharedSpace = sharedSpace;
    // Held again, it goes over all the lists of its group.
    item.setClippedToList(false);
    if (shown != null) item.setPosition(spaceOf(item).globalToLocal(shown));
    if (!overlayed) items.putOverlayedItem(item);
    items.setZIndex(item, maxZIndex);

    item.animateDecoration(
      decorator: decorator,
      duration: decorationDuration,
      vsync: vsync,
    );
  }

  /// Flings [item] back to its slot in the list as its decoration goes, and
  /// takes it out of the overlay once it is there and its decoration gone.
  void flingBackToSlot(
    OverlayedItem item, {
    required Velocity velocity,
    SpringDescription springDescription = defaultFlingSpringDescription,
  }) {
    final flung = item.animateFlingTo(
      spaceOf(item)
          .globalToLocal(items.renderedItemBy(key: item.key)!.globalPosition!),
      velocity: velocity,
      springDescription: springDescription,
      vsync: vsync,
    );
    Future.wait([
      // Once the fling is under way, so it goes by the time the item lands.
      item.animateUndecoration(),
      // It lands as its new list's look, once it has flown there.
      ?item.flight?.done,
      flung,
    ]).whenComplete(() => land(item));
  }

  /// Throws [item], which is swiped away, out of the overlay through its
  /// edge in [direction], on at the speed it is let go at.
  void throwOut(
    OverlayedItem item, {
    required SwipeDirection direction,
    required Velocity velocity,
  }) => item.animateThrowOut(
    direction.throwTarget(
      item.position,
      itemSize: item.size,
      bounds: overlay.size,
    ),
    velocity: velocity,
    duration: throwOutDuration,
    vsync: vsync,
  );
}
