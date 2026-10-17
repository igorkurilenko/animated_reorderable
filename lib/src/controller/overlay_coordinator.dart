import 'package:flutter/widgets.dart';

import '../animated_reorderable.dart' show MultiDragGestureRecognizerFactory;
import '../const.dart';
import '../model/model.dart';
import '../model/swipe_direction.dart';
import '../util/geometry.dart';
import '../util/measure_util.dart';
import '../util/scheduling.dart';
import 'scroll_sync.dart';

/// The space overlayed items are positioned in. It covers the list.
abstract interface class OverlaySpace {
  OverlayOffset globalToLocal(GlobalOffset point);
  GlobalOffset localToGlobal(OverlayOffset point);
  Size get size;
}

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
    required this.itemBuilder,
  });

  final OverlaySpace overlay;
  final ItemRegistry items;
  final ScrollSync scrollSync;
  final TickerProvider vsync;
  final ValueGetter<Duration> motionAnimationDuration;
  final ValueGetter<Curve> motionAnimationCurve;
  final ValueGetter<Axis> scrollDirection;

  /// Builds the item at an index as the wrapped view would.
  final ValueGetter<NullableIndexedWidgetBuilder> itemBuilder;

  bool _isHeld(Key key) =>
      items.isDragged(key: key) || items.isSwiped(key: key);

  OverlayedItem createOverlayedItem(
    RenderedItem renderedItem, {
    MultiDragGestureRecognizerFactory? recognizerFactory,
    Item? item,
  }) => OverlayedItem(
    item: item ?? items.itemBy(key: renderedItem.key)!,
    index: renderedItem.index,
    position: overlay.globalToLocal(renderedItem.globalPosition!),
    // The item lays out in the overlay as it would in the list.
    constraints:
        renderedItem.constraints ?? BoxConstraints.tight(renderedItem.size!),
    size: renderedItem.size!,
    recognizerFactory: recognizerFactory,
  );

  /// Overlays the rendered items, except [except] and the held ones, so
  /// they can move to their slots at [newIndex] when the list lays out.
  ///
  /// After another change in the same frame, the list may not have built
  /// its items again yet. Items already in the overlay keep their indexes,
  /// which the model has moved, and removed items stay as they are.
  void overlayRenderedItems({
    required int Function(RenderedItem item) newIndex,
    Key? except,
  }) {
    for (var renderedItem
        in items.renderedItems
            .where((x) => x.key != except)
            .where((x) => items.itemBy(key: x.key) != null)
            .where((x) => !_isHeld(x.key))) {
      final overlayedItem =
          items.overlayedItemBy(key: renderedItem.key) ??
          items.putOverlayedItem(
            createOverlayedItem(renderedItem)..index = newIndex(renderedItem),
          );
      overlayedItem.setInteractive(false);
    }
  }

  /// Overlays [item], which was at [index] and is neither rendered nor
  /// overlayed, just outside the overlay, so it can move in to its slot at
  /// [newIndex] when the list lays out.
  void overlayNotRenderedItem(
    Item item, {
    required int index,
    required int newIndex,
  }) {
    if (items.isRendered(key: item.key)) return;
    if (items.isOverlayed(key: item.key)) return;

    final fakeGeometry = getFakeAnchorGeometryOfNotRenderedItem(
      notRenderedItemIndex: index,
      anyRenderedItem: items.renderedItems.first,
    );
    if (fakeGeometry == null) return;

    items.putOverlayedItem(
      OverlayedItem(
        item: item,
        index: newIndex,
        position: OverlayOffset(fakeGeometry.topLeft),
        constraints: BoxConstraints.tight(fakeGeometry.size),
        size: fakeGeometry.size,
        interactive: false,
      ),
    );
  }

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
      // It keeps its size while the removed item builder animates it.
      ..setConstraints(BoxConstraints.tight(outgoingItem.size))
      ..setInteractive(false);
    removedItem
        .animateRemovedItemBuilder(
          builder: builder,
          duration: duration,
          vsync: vsync,
        )
        .whenComplete(() => items.removeOutgoingItem(outgoingItem));
  }

  void unoverlay(OverlayedItem item) {
    if (items.overlayedItemBy(key: item.key) != item) return;
    items.removeOverlayedItem(key: item.key);
    addPostFrame(() {
      if (items.overlayedItemBy(key: item.key) != item) {
        items.disposeOverlayedItem(item);
      }
    });
  }

  /// Where an item that the list did not build at [notRenderedItemIndex]
  /// would be: just outside the overlay, before or after
  /// [anyRenderedItem]. Null while the view has no scroll position.
  Rect? getFakeAnchorGeometryOfNotRenderedItem({
    required int notRenderedItemIndex,
    required RenderedItem anyRenderedItem,
    Size? itemSize,
  }) {
    final scrollPosition = scrollSync.scrollPosition;
    if (scrollPosition == null) return null;

    final gridLayout = scrollSync.gridLayout;
    itemSize ??=
        gridLayout?.getChildSize(notRenderedItemIndex, scrollDirection()) ??
        // A list lays out all its items with the same constraints.
        measureItemWidgetAt(
          scrollPosition,
          index: notRenderedItemIndex,
          constraints: anyRenderedItem.constraints,
        );

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

  Size measureItemWidgetAt(
    ScrollPosition scrollPosition, {
    required int index,
    BoxConstraints? constraints,
  }) => MeasureUtil.measureWidget(
    context: scrollPosition.context.storageContext,
    builder: (context) => itemBuilder()(context, index)!,
    constraints:
        constraints ??
        // As wide as the overlay, which covers the list, or as high.
        (scrollDirection() == Axis.vertical
            ? BoxConstraints(maxWidth: overlay.size.width)
            : BoxConstraints(maxHeight: overlay.size.height)),
  );

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

    final anchorPosition = overlay.globalToLocal(globalPosition);

    if (items.isSwiped(key: item.key)) {
      // It stays in its slot, swiped as far.
      overlayedItem.setPosition(anchorPosition + overlayedItem.swipeOffset);
      return;
    }

    if (overlayedItem.anchorPosition != anchorPosition) {
      overlayedItem
          .animateTo(
            anchorPosition,
            vsync: vsync,
            duration: motionAnimationDuration(),
            curve: motionAnimationCurve(),
          )
          .whenComplete(() => unoverlay(overlayedItem));
    } else if (!(overlayedItem.motionAnimationStatus?.isAnimating ?? false)) {
      unoverlay(overlayedItem);
    }
  }

  /// Fits removed items to the layout and moves the overlayed items that
  /// the list did not build out of sight.
  void reconcileItemsLayer() {
    fitOutgoingItemsToLayout();

    for (var overlayedItem
        in items.overlayedItems
            .where((x) => !items.isRendered(key: x.key))
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
          .whenComplete(() => unoverlay(overlayedItem));
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

  /// The list's placeholder follows the item's size in the overlay.
  void didResizeItem(Size size, OverlayedItem item) {
    if (item.size == size) return;
    if (item == items.draggedItem) keepUnderPointer(item, size: size);
    items.setOverlayedItemSize(item, size);
  }

  /// Keeps the pointer over the same point of a dragged item, relative to
  /// its size, when the item is about to change its [size].
  void keepUnderPointer(OverlayedItem item, {required Size size}) {
    final globalPointerPosition = item.globalPointerPosition;
    if (globalPointerPosition == null || item.size.isEmpty) return;
    final pointer = overlay.globalToLocal(globalPointerPosition);
    final grip = pointer - item.position;
    item.setPosition(
      OverlayOffset(
        pointer -
            Offset(
              grip.dx * size.width / item.size.width,
              grip.dy * size.height / item.size.height,
            ),
      ),
    );
  }

  /// The overlayed items move with the content as the view scrolls, except
  /// the held ones, which stay under the pointer.
  void shiftOverlayedItems(Offset delta) {
    for (var x
        in [...items.overlayedItems, ...items.outgoingItems]
            .where((x) => x != items.draggedItem)
            .where((x) => x != items.swipedItem)) {
      x.shift(-delta);
    }
  }

  /// Where [item] is on the screen.
  Rect globalRectOf(OverlayedItem item) =>
      overlay.localToGlobal(item.position) & item.size;

  /// Lifts [item] above the other items, into the overlay if it is not
  /// there yet, and decorates it with [decorator].
  void lift(
    OverlayedItem item, {
    required AnimatedItemDecorator? decorator,
    required Duration decorationDuration,
  }) {
    if (!items.isOverlayed(key: item.key)) {
      items.putOverlayedItem(item);
    }
    items.setZIndex(item, maxZIndex);

    item.animateDecoration(
      decorator: decorator,
      duration: decorationDuration,
      vsync: vsync,
    );
  }

  /// Flings [item] back to its slot in the list, and takes it out of the
  /// overlay once it is there and [undecoration] is done.
  void flingBackToSlot(
    OverlayedItem item, {
    required Future undecoration,
    required Velocity velocity,
    SpringDescription springDescription = defaultFlingSpringDescription,
  }) {
    Future.wait([
      undecoration,
      item.animateFlingTo(
        overlay.globalToLocal(
          items.renderedItemBy(key: item.key)!.globalPosition!,
        ),
        velocity: velocity,
        screenSize: _screenSize,
        springDescription: springDescription,
        vsync: vsync,
      ),
    ]).whenComplete(() => unoverlay(item));
  }

  /// Flings [item], which is swiped away, out of the overlay through its
  /// edge in [direction].
  void flingOut(
    OverlayedItem item, {
    required SwipeDirection direction,
    required Velocity velocity,
    required SpringDescription springDescription,
  }) => item.animateFlingTo(
    direction.flingTarget(
      item.position,
      itemSize: item.size,
      bounds: overlay.size,
    ),
    velocity: velocity,
    screenSize: _screenSize,
    springDescription: springDescription,
    vsync: vsync,
  );

  Size get _screenSize {
    final screenView = WidgetsBinding.instance.platformDispatcher.views.first;
    return screenView.physicalSize / screenView.devicePixelRatio;
  }
}
