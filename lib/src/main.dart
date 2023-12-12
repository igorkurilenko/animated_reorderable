import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'const.dart';
import 'model/model.dart' as model;
import 'model/permutations.dart';
import 'util/measure_util.dart';
import 'widget/item_widget.dart';
import 'widget/overlayed_item_widget.dart';
import 'util/misc.dart';
import 'util/overrided_sliver_child_builder_delegate.dart';
import 'util/sliver_grid_delegate_decorator.dart';

typedef IdGetter = int Function(int index);
typedef ReorderableGetter = bool Function(int index);
typedef DraggableGetter = bool Function(int index);
typedef SwipeAwayDirectionGetter = AxisDirection? Function(int index);
typedef ReorderCallback = void Function(Permutations permutations);
typedef SwipeAwayCallback = AnimatedRemovedItemBuilder? Function(int index);

abstract class AnimatedReorderable extends StatelessWidget {
  const AnimatedReorderable({super.key, required this.controller});

  final AnimatedReorderableController controller;

  factory AnimatedReorderable.grid({
    required AnimatedReorderableController controller,
    required GridView gridView,
  }) =>
      _GridView(
        gridView: gridView,
        controller: controller.setup(
          childrenDelegate: gridView.childrenDelegate,
          scrollController: gridView.controller,
        ),
      );

  factory AnimatedReorderable.list({
    required AnimatedReorderableController controller,
    required ListView listView,
  }) =>
      _ListView(
        listView: listView,
        controller: controller.setup(
          childrenDelegate: listView.childrenDelegate,
          scrollController: listView.controller,
        ),
      );

  Clip get clipBehavior;
  EdgeInsetsGeometry? get padding;
  Axis get scrollDirection;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          controller.handleConstraintsChange(constraints);
          return Stack(
            children: [
              _ItemsLayer(
                key: controller.itemsLayerKey,
                controller: controller,
                builder: buildCollectionView,
              ),
              _OverlayedItemsLayer(
                key: controller.overlayedItemsLayerKey,
                controller: controller,
                clipBehavior: clipBehavior,
                padding: padding,
                scrollDirection: scrollDirection,
              ),
            ],
          );
        },
      );

  Widget buildCollectionView(BuildContext context);
}

class _GridView extends AnimatedReorderable {
  const _GridView({
    required super.controller,
    required this.gridView,
  });

  final GridView gridView;

  @override
  Clip get clipBehavior => gridView.clipBehavior;

  @override
  EdgeInsetsGeometry? get padding => gridView.padding;

  @override
  Axis get scrollDirection => gridView.scrollDirection;

  @override
  Widget buildCollectionView(BuildContext context) => GridView.custom(
        key: gridView.key,
        scrollDirection: gridView.scrollDirection,
        reverse: gridView.reverse,
        controller: controller.scrollController,
        primary: gridView.primary,
        physics: gridView.physics,
        shrinkWrap: gridView.shrinkWrap,
        padding: gridView.padding,
        gridDelegate: SliverGridLayoutNotifier(
          gridDelegate: gridView.gridDelegate,
          onLayout: controller.handleSliverGridLayoutChange,
        ),
        childrenDelegate:
            controller.overrideChildrenDelegate(gridView.childrenDelegate),
        cacheExtent: gridView.cacheExtent,
        semanticChildCount: gridView.semanticChildCount,
        dragStartBehavior: gridView.dragStartBehavior,
        clipBehavior: clipBehavior,
        keyboardDismissBehavior: gridView.keyboardDismissBehavior,
        restorationId: gridView.restorationId,
      );
}

class _ListView extends AnimatedReorderable {
  const _ListView({
    required super.controller,
    required this.listView,
  });

  final ListView listView;

  @override
  Clip get clipBehavior => listView.clipBehavior;

  @override
  EdgeInsetsGeometry? get padding => listView.padding;

  @override
  Axis get scrollDirection => listView.scrollDirection;

  @override
  Widget buildCollectionView(BuildContext context) => ListView.custom(
        key: listView.key,
        scrollDirection: listView.scrollDirection,
        reverse: listView.reverse,
        controller: controller.scrollController,
        primary: listView.primary,
        physics: listView.physics,
        shrinkWrap: listView.shrinkWrap,
        padding: listView.padding,
        itemExtent: listView.itemExtent,
        prototypeItem: listView.prototypeItem,
        childrenDelegate:
            controller.overrideChildrenDelegate(listView.childrenDelegate),
        cacheExtent: listView.cacheExtent,
        semanticChildCount: listView.semanticChildCount,
        dragStartBehavior: listView.dragStartBehavior,
        keyboardDismissBehavior: listView.keyboardDismissBehavior,
        restorationId: listView.restorationId,
        clipBehavior: clipBehavior,
      );
}

class _ItemsLayer extends StatefulWidget {
  const _ItemsLayer({
    super.key,
    required this.controller,
    required this.builder,
  });

  final AnimatedReorderableController controller;
  final WidgetBuilder builder;

  @override
  State<_ItemsLayer> createState() => _ItemsLayerState();
}

class _ItemsLayerState extends State<_ItemsLayer> {
  AnimatedReorderableController get controller => widget.controller;

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

class _OverlayedItemsLayer extends StatefulWidget {
  const _OverlayedItemsLayer({
    super.key,
    required this.controller,
    required this.clipBehavior,
    this.padding,
    required this.scrollDirection,
  });

  final AnimatedReorderableController controller;
  final Clip clipBehavior;
  final EdgeInsetsGeometry? padding;
  final Axis scrollDirection;

  @override
  State<_OverlayedItemsLayer> createState() => _OverlayedItemsLayerState();
}

class _OverlayedItemsLayerState extends State<_OverlayedItemsLayer> {
  final canvasKey = GlobalKey();

  AnimatedReorderableController get controller => widget.controller;
  EdgeInsetsGeometry get effectivePadding =>
      widget.padding ?? mediaQueryScrollablePaddingOf(widget.scrollDirection);

  Offset? globalToLocal(Offset point) =>
      canvasKey.currentContext?.findRenderBox()?.globalToLocal(point);

  Rect? computeCanvasGeometry([Offset offset = Offset.zero]) =>
      canvasKey.currentContext?.computeGeometry(offset);

  @override
  Widget build(BuildContext context) => Padding(
        padding: effectivePadding,
        child: Stack(
          key: canvasKey,
          clipBehavior: widget.clipBehavior,
          children: [
            for (var item in controller.overlayedItemsToRender)
              OverlayedItemWidget(
                key: ValueKey(item.id),
                item: item,
                onDragStart: controller.handleItemDragStart,
                onDragUpdate: controller.handleItemDragUpdate,
                onDragEnd: controller.handleItemDragEnd,
                onSwipeStart: controller.handleItemSwipeStart,
                onSwipeUpdate: controller.handleItemSwipeUpdate,
                onSwipeEnd: controller.handleItemSwipeEnd,
              ),
          ],
        ),
      );
}

class AnimatedReorderableController {
  AnimatedReorderableController({
    required this.idGetter,
    ReorderableGetter? reorderableGetter,
    DraggableGetter? draggableGetter,
    this.swipeAwayDirectionGetter,
    this.didReorder,
    this.didSwipeAway,
    required this.vsync,
    this.motionAnimationDuration = duration500ms,
    this.motionAnimationCurve = Curves.easeInOut,
    this.draggedItemDecorator = defaultDraggedItemDecorator,
    this.draggedItemDecorationAnimationDuration = duration500ms,
    this.swipedItemDecorator = defaultDraggedItemDecorator,
    this.swipedItemDecorationAnimationDuration = duration500ms,
    this.autoScrollerVelocityScalar = defaultAutoScrollVelocityScalar,
    this.swipeAwayExtent = defaultSwipeAwayExtent,
    this.swipeAwayVelocity = defaultSwipeAwayVelocity,
    this.swipeAwaySpringDescription = defaultFlingSpringDescription,
  })  : reorderableGetter = reorderableGetter ?? returnTrue,
        draggableGetter = draggableGetter ?? returnTrue;

  final _itemsLayerKey = GlobalKey<_ItemsLayerState>();
  final _overlayedItemsLayerKey = GlobalKey<_OverlayedItemsLayerState>();

  final IdGetter idGetter;
  final ReorderableGetter reorderableGetter;
  final DraggableGetter draggableGetter;
  final SwipeAwayDirectionGetter? swipeAwayDirectionGetter;
  final double autoScrollerVelocityScalar;
  final double swipeAwayExtent;
  final double swipeAwayVelocity;
  final SpringDescription swipeAwaySpringDescription;

  final ReorderCallback? didReorder;
  final SwipeAwayCallback? didSwipeAway;

  final TickerProvider vsync;

  final Duration motionAnimationDuration;
  final Curve motionAnimationCurve;

  final model.AnimatedItemDecorator? draggedItemDecorator;
  final Duration draggedItemDecorationAnimationDuration;
  final model.AnimatedItemDecorator? swipedItemDecorator;
  final Duration swipedItemDecorationAnimationDuration;
  final _state = model.ControllerState();
  ScrollController? _scrollController;
  EdgeDraggingAutoScroller? _autoScroller;
  late OverridedSliverChildBuilderDelegate _childrenDelegate;
  SliverGridLayout? _gridLayout;

  void insertItem(
    int index, {
    required AnimatedItemBuilder builder,
    Duration duration = duration500ms,
  }) {
    if (itemCount == null) {
      throw ('AnimatedReorderableController must be connected with a ListView or GridView');
    }
    if (index < 0 || index > itemCount!) {
      throw RangeError.value(index);
    }

    final item = _state.insertItem(
      index: index,
      itemFactory: (index) {
        final x = createItem(index);
        x.setSize(
          measureItemSizeAt(index: index),
          notify: false,
        );
        x.measured = true;
        return x;
      },
    );

    recomputeItemPositions()
        .where((u) => !_state.isDragged(id: u.item.id))
        .where((u) => !_state.isSwiped(id: u.item.id))
        .where((u) => u.index != index)
        .map((u) =>
            _state.overlayedItemBy(id: u.item.id) ??
            model.OverlayedItem(
              interactive: false,
              index: u.index,
              id: u.item.id,
              builder: model.ItemBuilder.adaptOtherItemBuilder(u.item),
              zIndex: defaultZIndex,
              size: u.item.size,
              position: overlayedItemsLayer!.globalToLocal(
                u.oldPosition - scrollOffset,
              )!,
            ))
        .map(overlay)
        .forEach((x) => x
            .animateTo(
              overlayedItemsLayer!.globalToLocal(
                getGlobalAnchorPosition(itemId: x.id),
              )!,
              curve: motionAnimationCurve,
              duration: motionAnimationDuration,
              vsync: vsync,
            )
            .whenComplete(() => unoverlay(x)));

    item.animateItemBuilder(
      builder: builder,
      duration: duration,
      vsync: vsync,
    );

    itemsLayer?.rebuild(() {});
  }

  void removeItem(
    int index, {
    AnimatedRemovedItemBuilder? builder,
    int? zIndex,
    Duration duration = duration500ms,
  }) {
    if (itemCount == null) {
      throw ('AnimatedReorderableController must be connected with a ListView or GridView');
    }
    if (index < 0 || index >= itemCount!) {
      throw RangeError.value(index);
    }

    final item = _state.removeItem(index: index);
    if (item == null) return;

    final originalScrollOffset = scrollOffset;

    if (builder != null) {
      final outgoingItem = _state.overlayedItemBy(id: item.id) ??
          model.OverlayedItem(
            id: item.id,
            index: index,
            builder: item.builder,
            size: item.size,
            position: overlayedItemsLayer!.globalToLocal(
              item.position - scrollOffset,
            )!,
          );

      overlay(outgoingItem);

      outgoingItem
          .animateOutgoing(
        builder: builder,
        zIndex: zIndex,
        duration: duration,
        vsync: vsync,
      )
          .whenComplete(() {
        overlayedItemsLayer!.rebuild(() {
          _state.removeOverlayedItem(id: item.id)?.dispose();
          item.dispose();
        });
      });
    } else {
      overlayedItemsLayer!.rebuild(() {
        _state.removeOverlayedItem(id: item.id)?.dispose();
        item.dispose();
      });
    }

    recomputeItemPositions()
        .where((u) => !_state.isDragged(id: u.item.id))
        .where((u) => !_state.isSwiped(id: u.item.id))
        .map(
          (u) =>
              _state.overlayedItemBy(id: u.item.id) ??
              model.OverlayedItem(
                interactive: false,
                index: u.index,
                id: u.item.id,
                builder: model.ItemBuilder.adaptOtherItemBuilder(u.item),
                zIndex: defaultZIndex,
                size: u.item.size,
                position: overlayedItemsLayer!.globalToLocal(
                  u.oldPosition - scrollOffset,
                )!,
              ),
        )
        .map((x) => overlay(x))
        .forEach(
          (x) => x
              .animateTo(
                overlayedItemsLayer!.globalToLocal(
                  getGlobalAnchorPosition(itemId: x.id),
                )!,
                vsync: vsync,
                curve: motionAnimationCurve,
                duration: motionAnimationDuration,
              )
              .whenComplete(
                () => unoverlay(x),
              ),
        );

    itemsLayer?.rebuild(() {});

    addPostFrame(() {
      if (scrollOffset == originalScrollOffset) return;

      final delta = scrollOffset - originalScrollOffset;

      scrollController!
          .jumpTo(scrollController!.position.pixels + delta.distance);

      addPostFrame(() => recomputeItemPositions());
    });
  }

  void moveItem(
    int index, {
    required int destIndex,
    Duration duration = duration500ms,
  }) {
    if (itemCount == null) {
      throw ('AnimatedReorderableController must be connected with a ListView or GridView');
    }
    if (index < 0 || index >= itemCount!) {
      throw RangeError.value(index);
    }
    if (!reorderableGetter(index)) {
      throw ('The item is not reorderable at $index');
    }
    if (!reorderableGetter(destIndex)) {
      throw ('The item is not reorderable at $destIndex');
    }
    if (index == destIndex) return;

    ensureItemsAreMeasured(
      fromIndex: 0,
      toIndex: math.max(index, destIndex),
    );

    final permutations = _state.moveItem(
      index: index,
      destIndex: destIndex,
      reorderableGetter: reorderableGetter,
      itemFactory: createItem,
    );

    recomputeItemPositions()
        .where((u) => !_state.isDragged(id: u.item.id))
        .where((u) => !_state.isSwiped(id: u.item.id))
        .map((u) =>
            _state.overlayedItemBy(id: u.item.id) ??
            model.OverlayedItem(
              interactive: false,
              index: u.index,
              id: u.item.id,
              builder: model.ItemBuilder.adaptOtherItemBuilder(u.item),
              zIndex: defaultZIndex,
              size: u.item.size,
              position: overlayedItemsLayer!.globalToLocal(
                u.oldPosition - scrollOffset,
              )!,
            ))
        .map(overlay)
        .forEach((x) => x
            .animateTo(
              overlayedItemsLayer!.globalToLocal(
                getGlobalAnchorPosition(itemId: x.id),
              )!,
              curve: motionAnimationCurve,
              duration: motionAnimationDuration,
              vsync: vsync,
            )
            .whenComplete(() => unoverlay(x)));

    itemsLayer?.rebuild(() => didReorder!.call(permutations));
  }

  void dispose() {
    _state.dispose();
  }
}

extension _AnimatedReorderableController on AnimatedReorderableController {
  AnimatedReorderableController setup({
    required SliverChildDelegate childrenDelegate,
    ScrollController? scrollController,
  }) {
    _state
      ..reset()
      ..itemCount = getChildCount(childrenDelegate);
    setupScrollController(scrollController ?? ScrollController());
    return this;
  }

  model.OverlayedItem overlay(model.OverlayedItem item) {
    if (_state.isOverlayed(id: item.id)) return item;
    overlayedItemsLayer?.rebuild(() => _state.putOverlayedItem(item));
    _state.renderedItemBy(id: item.id)?.rebuild();
    return item;
  }

  void unoverlay(model.OverlayedItem item) {
    if (!_state.isOverlayed(id: item.id)) return;
    overlayedItemsLayer?.rebuild(() => _state.removeOverlayedItem(id: item.id));
    _state.renderedItemBy(id: item.id)?.rebuild();
  }

  void reorderAndAutoScrollIfNecessary() {
    reorderIfNecessary();
    autoScrollIfNecessary();
  }

  void ensureItemsAreMeasured({
    required int fromIndex,
    required int toIndex,
  }) {
    final from = math.min(fromIndex, toIndex);
    final to = math.max(fromIndex, toIndex);
    VoidCallback? after;

    for (var index = from; index <= to; index++) {
      final item = ensureItemAt(index: index);

      if (!item.measured) {
        final size = measureItemSizeAt(index: index);
        item
          ..setSize(size, notify: false)
          ..measured = true;

        after = recomputeItemPositions;
      }
    }

    after?.call();
  }

  Size measureItemSizeAt({required int index}) =>
      _gridLayout?.getChildSize(index, scrollController!.axis) ??
      MeasureUtil.measureWidget(
        context: _scrollController!.scrollableState!.context,
        builder: (context) =>
            _childrenDelegate.originalBuilder(context, index)!,
        constraints: scrollController!.axis == Axis.vertical
            ? BoxConstraints(maxWidth: _state.constraintsMark?.maxWidth ?? 0.0)
            : BoxConstraints(maxHeight: _state.constraintsMark?.maxHeight ?? 0.0),
      );
}

extension _ScrollHandler on AnimatedReorderableController {
  void handleScroll() {
    final delta = markScrollOffset(scrollOffset);

    if (_state.shiftItemsOnScroll) {
      for (var x in _state.overlayedItems
          .where((x) => !_state.isDragged(id: x.id))
          .where((x) => !_state.isSwiped(id: x.id))) {
        x.shift(-delta);
      }
    }
  }
}

extension _SliverGridLayoutChangeHandler on AnimatedReorderableController {
  void handleSliverGridLayoutChange(SliverGridLayout layout) =>
      _gridLayout = layout;
}

extension _ConstraintsChangeHandler on AnimatedReorderableController {
  void handleConstraintsChange(BoxConstraints constraints) {
    if (_state.constraintsMark != null &&
        scrollController != null &&
        scrollController!.hasClients) {
      final scaleFactor = scrollController!.axis == Axis.vertical
          ? constraints.maxWidth / _state.constraintsMark!.maxWidth
          : constraints.maxHeight / _state.constraintsMark!.maxHeight;

      for (var x in _state.items) {
        x.scale(scaleFactor);
      }
      for (var x in _state.overlayedItems) {
        x.scale(scaleFactor);
      }

      _state.shiftItemsOnScroll = false;
      scrollController!.scaleScrollPosition(scaleFactor);
      _state.shiftItemsOnScroll = true;
    }

    _state.constraintsMark = constraints;
  }
}

extension _ItemDragHandlers on AnimatedReorderableController {
  void handleItemDragStart(model.OverlayedItem item) {
    item.stopMotion();
    _state.draggedItem = item;
    overlay(item);
    item.animateDecoration(
      decorator: draggedItemDecorator,
      duration: draggedItemDecorationAnimationDuration,
      vsync: vsync,
    );
  }

  void handleItemDragUpdate(model.OverlayedItem _) =>
      reorderAndAutoScrollIfNecessary();

  void handleItemDragEnd(model.OverlayedItem item) {
    _state.draggedItem = null;
    stopAutoScroll(forceStopAnimation: true);
    Future.wait([
      item.animateUndecoration(),
      item.animateFlingTo(
        overlayedItemsLayer!.globalToLocal(
          getGlobalAnchorPosition(itemId: item.id),
        )!,
        velocity: item.swipeVelocity,
        screenSize: getScreenSize(),
        vsync: vsync,
      ),
    ]).whenComplete(
      () => unoverlay(item),
    );
  }

  void reorderIfNecessary() {
    if (_state.draggedItem == null) return;
    final item = _state.draggedItem!;

    if (!reorderableGetter(item.index)) return;

    final pointerPosition = item.pointerPosition!;
    final renderedItem = _state.renderedItemAt(position: pointerPosition);

    if (renderedItem?.id == _state.itemUnderThePointerId) return;
    _state.itemUnderThePointerId = renderedItem?.id;

    if (renderedItem == null) return;
    if (renderedItem.id == item.id) return;
    if (!renderedItem.reorderable) return;

    moveItem(item.index, destIndex: renderedItem.index);

    addPostFrame(() => _state.itemUnderThePointerId =
        _state.renderedItemAt(position: pointerPosition)?.id);
  }
}

extension _ItemSwipeHandlers on AnimatedReorderableController {
  void handleItemSwipeStart(model.OverlayedItem item) {
    item.stopMotion();
    _state.swipedItem = item;
    overlay(item);
    item.animateDecoration(
      decorator: swipedItemDecorator,
      duration: swipedItemDecorationAnimationDuration,
      vsync: vsync,
    );
  }

  void handleItemSwipeUpdate(model.OverlayedItem item) {
    // noop
  }

  void handleItemSwipeEnd(model.OverlayedItem item) {
    _state.swipedItem = null;

    final undecorateFuture = item.animateUndecoration();

    final swipedToRemove = item.swipedToRemove(
      extentToRemove: swipeAwayExtent,
      velocityToRemove: swipeAwayVelocity,
    );

    if (swipedToRemove) {
      final removedItemBuilder = didSwipeAway!.call(item.index);
      final screenSize = getScreenSize();

      removeItem(
        item.index,
        builder: removedItemBuilder ?? (context, animation) => item.widget!,
        zIndex: item.zIndex,
      );

      item.animateFlingTo(
        switch (item.swipeDirection!) {
          AxisDirection.left => Offset(-item.geometry.width, item.position.dy),
          AxisDirection.right => Offset(screenSize.width, item.position.dy),
          AxisDirection.up => Offset(item.position.dx, -item.geometry.height),
          AxisDirection.down => Offset(item.position.dx, screenSize.height),
        },
        velocity: item.swipeVelocity,
        screenSize: getScreenSize(),
        vsync: vsync,
      ); //.whenComplete(() => unoverlay(item));
    } else {
      Future.wait([
        undecorateFuture,
        item.animateFlingTo(
          overlayedItemsLayer!.globalToLocal(
            getGlobalAnchorPosition(itemId: item.id),
          )!,
          velocity: item.swipeVelocity,
          screenSize: getScreenSize(),
          vsync: vsync,
        )
      ]).whenComplete(
        () => unoverlay(item),
      );
    }
  }
}

extension _Misc on AnimatedReorderableController {
  int? get itemCount => _state.itemCount;

  Iterable<model.OverlayedItem> get overlayedItems => _state.overlayedItems;

  Iterable<model.OverlayedItem> get overlayedItemsToRender => overlayedItems
      .where((x) => _state.isRendered(id: x.id) || x.outgoing)
      .toList()
    ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

  List<model.ItemPositionUpdate> recomputeItemPositions() =>
      _state.recomputeItemPositions(
        canvasGeometry: overlayedItemsLayer!.computeCanvasGeometry()!,
        axisDirection: scrollController!.axisDirection,
      );

  GlobalKey<_ItemsLayerState> get itemsLayerKey => _itemsLayerKey;

  _ItemsLayerState? get itemsLayer => itemsLayerKey.currentState;

  GlobalKey<_OverlayedItemsLayerState> get overlayedItemsLayerKey =>
      _overlayedItemsLayerKey;

  _OverlayedItemsLayerState? get overlayedItemsLayer =>
      overlayedItemsLayerKey.currentState;

  Size getScreenSize() {
    final screenView = WidgetsBinding.instance.platformDispatcher.views.first;
    return screenView.physicalSize / screenView.devicePixelRatio;
  }

  Offset getGlobalAnchorPosition({required int itemId}) =>
      _state.itemBy(id: itemId)!.position - scrollOffset;
}

extension _Scrolling on AnimatedReorderableController {
  ScrollController? get scrollController => _scrollController;

  void setupScrollController(ScrollController? value) {
    if (_scrollController == value) return;
    addPostFrame(() {
      setupAutoscroller();
      markScrollOffset(scrollOffset);
    });
    _scrollController?.removeListener(handleScroll);
    (_scrollController = value)?.addListener(handleScroll);
  }

  Offset get scrollOffset => scrollController!.scrollOffset!;

  void setupAutoscroller() {
    if (_scrollController == null) return;
    if (!_scrollController!.hasClients) return;

    _autoScroller = EdgeDraggingAutoScroller(
      _scrollController!.position.context as ScrollableState,
      velocityScalar: autoScrollerVelocityScalar,
      onScrollViewScrolled: () => reorderAndAutoScrollIfNecessary(),
    );
  }

  void autoScrollIfNecessary() {
    if (_state.draggedItem == null) return;

    _autoScroller?.startAutoScrollIfNecessary(
      _state.draggedItem!.geometry.deflate(alpha),
    );
  }

  void stopAutoScroll({bool forceStopAnimation = false}) {
    _autoScroller?.stopAutoScroll();

    if (forceStopAnimation) {
      final pixels = scrollController!.position.pixels;
      scrollController!.position.jumpTo(pixels);
    }
  }

  Offset markScrollOffset(Offset scrollOffset) {
    if (_scrollController == null) return Offset.zero;
    if (!_scrollController!.hasClients) return Offset.zero;

    final delta = scrollOffset - _state.scrollOffsetMark;
    _state.scrollOffsetMark = scrollOffset;
    return delta;
  }
}

extension _ChildrenDelegate on AnimatedReorderableController {
  OverridedSliverChildBuilderDelegate get childrenDelegate => _childrenDelegate;
  set childrenDelegate(OverridedSliverChildBuilderDelegate value) =>
      _childrenDelegate = value;

  SliverChildDelegate overrideChildrenDelegate(SliverChildDelegate delegate) =>
      childrenDelegate = OverridedSliverChildBuilderDelegate.override(
        delegate: delegate,
        overridedChildBuilder: buildItemWidget,
        overridedChildCountGetter: () => itemCount,
      );

  Widget buildItemWidget(BuildContext context, int index) {
    final item = ensureItemAt(index: index);
    return ItemWidget(
      key: ValueKey(item.id),
      index: index,
      id: item.id,
      reorderableGetter: reorderableGetter,
      draggableGetter: draggableGetter,
      swipeAwayDirectionGetter: swipeAwayDirectionGetter,
      overlayedGetter: (id) => _state.isOverlayed(id: id),
      builder: item.builder.build,
      onInit: registerRenderedItem,
      didUpdate: (renderedItem) {
        unregisterRenderedItem(renderedItem);
        registerRenderedItem(renderedItem);
      },
      onDispose: unregisterRenderedItem,
      onDeactivate: unregisterRenderedItem,
      didBuild: (renderedItem) {
        final scrollablePosition =
            scrollController?.scrollablePosition ?? Offset.zero;
        final itemGeometry = renderedItem.computeGeometry(
          scrollOffset - scrollablePosition,
        );
        item.setGeometry(itemGeometry ?? item.geometry);
        item.measured |= itemGeometry != null;
      },
      recognizeDrag: (context, event) {
        final geometry = context.computeGeometry()!;

        model.OverlayedItem(
          index: index,
          id: item.id,
          position: overlayedItemsLayer!.globalToLocal(geometry.position)!,
          size: geometry.size,
          interactive: true,
          builder: model.ItemBuilder.adaptOtherItemBuilder(item),
          recognizerFactory: createReoderGestureRecognizer,
        ).recognizeDrag(
          event,
          context: context,
          onDragStart: (overlayedItem) {
            overlayedItem.setZIndex(maxZIndex);
            overlayedItem.recognizerFactory = createImmediateGestureRecognizer;
            handleItemDragStart(overlayedItem);
          },
          onDragUpdate: handleItemDragUpdate,
          onDragEnd: handleItemDragEnd,
        );
      },
      recognizeSwipe: (context, event) {
        final geometry = context.computeGeometry()!;

        model.OverlayedItem(
          index: index,
          id: item.id,
          position: overlayedItemsLayer!.globalToLocal(geometry.position)!,
          size: geometry.size,
          interactive: true,
          builder: model.ItemBuilder.adaptOtherItemBuilder(item),
          recognizerFactory: scrollController!.axis == Axis.horizontal
              ? createHorizontalSwipeAwayGestureRecognizer
              : createVerticalSwipeAwayGestureRecognizer,
        ).recognizeSwipe(
          event,
          context: context,
          swipeDirection: swipeAwayDirectionGetter!.call(index)!,
          onSwipeStart: (overlayedItem) {
            overlayedItem.setZIndex(maxZIndex);
            handleItemSwipeStart(overlayedItem);
          },
          onSwipeUpdate: handleItemSwipeUpdate,
          onSwipeEnd: handleItemSwipeEnd,
        );
      },
    );
  }

  model.Item ensureItemAt({required int index}) =>
      _state.itemAt(index: index) ?? spawnItemAt(index: index);

  model.Item spawnItemAt({required int index}) {
    final item = createItem(index);
    _state.putItem(item);
    _state.setIndex(itemId: item.id, index: index);
    return item;
  }

  model.Item createItem(int index) => model.Item(
        id: idGetter(index),
        builder: model.ItemBuilder.adaptIndexedWidgetBuilder(
          childrenDelegate.originalBuilder,
        ),
      );

  void registerRenderedItem(RenderedItem item) {
    _state.putRenderedItem(item);

    if (_state.isOverlayed(id: item.id)) {
      addPostFrame(() => overlayedItemsLayer?.rebuild(() {}));
    }
  }

  void unregisterRenderedItem(RenderedItem item) {
    final registeredRenderedItem = _state.renderedItemBy(id: item.id);
    if (registeredRenderedItem == item) {
      _state.removeRenderedItemBy(id: item.id);

      if (_state.isOverlayed(id: item.id)) {
        addPostFrame(() => overlayedItemsLayer?.rebuild(() {}));
      }
    }
  }
}
