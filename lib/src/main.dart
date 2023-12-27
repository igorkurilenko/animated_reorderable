import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'const.dart';
import 'model/model.dart' as model;
import 'model/permutations.dart';
import 'widget/item_widget.dart';
import 'widget/overlayed_item_widget.dart';
import 'util/overrided_sliver_child_builder_delegate.dart';
import 'util/sliver_grid_delegate_decorator.dart';
import 'util/measure_util.dart';
import 'util/misc.dart';

typedef IdGetter = int Function(int index);
typedef ReorderableGetter = bool Function(int index);
typedef DraggableGetter = bool Function(int index);
typedef SwipeAwayDirectionGetter = AxisDirection? Function(int index);
typedef ReorderCallback = void Function(Permutations permutations);
typedef SwipeAwayCallback = AnimatedRemovedItemBuilder Function(int index);

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
              Align(
                alignment: Alignment.center,
                child: _ItemsLayer(
                  key: controller.itemsLayerKey,
                  controller: controller,
                  builder: buildCollectionView,
                  didBuild: controller.handleDidBuildItemsLayer,
                ),
              ),
              _OverlayedItemsLayer(
                key: controller.overlayedItemsLayerKey,
                controller: controller,
                clipBehavior: clipBehavior,
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
    this.didBuild,
  });

  final AnimatedReorderableController controller;
  final WidgetBuilder builder;
  final VoidCallback? didBuild;

  @override
  State<_ItemsLayer> createState() => _ItemsLayerState();
}

class _ItemsLayerState extends State<_ItemsLayer> {
  AnimatedReorderableController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    addPostFrame(() => widget.didBuild?.call());

    return widget.builder(context);
  }
}

class _OverlayedItemsLayer extends StatefulWidget {
  const _OverlayedItemsLayer({
    super.key,
    required this.controller,
    required this.clipBehavior,
    required this.scrollDirection,
  });

  final AnimatedReorderableController controller;
  final Clip clipBehavior;
  final Axis scrollDirection;

  @override
  State<_OverlayedItemsLayer> createState() => _OverlayedItemsLayerState();
}

class _OverlayedItemsLayerState extends State<_OverlayedItemsLayer> {
  final canvasKey = GlobalKey();

  AnimatedReorderableController get controller => widget.controller;

  Offset? globalToLocal(Offset point) =>
      canvasKey.currentContext?.findRenderBox()?.globalToLocal(point);

  Offset? localToGlobal(Offset point) =>
      canvasKey.currentContext?.findRenderBox()?.localToGlobal(point);

  Rect? computeCanvasGeometry([Offset offset = Offset.zero]) =>
      canvasKey.currentContext?.computeGeometry(offset);

  @override
  Widget build(BuildContext context) => Stack(
        key: canvasKey,
        clipBehavior: widget.clipBehavior,
        children: [
          for (var item in controller.overlayedItemsOrderedByZIndex)
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
    this.motionAnimationDuration = defaultMotionAnimationDuration,
    this.motionAnimationCurve = defaultMotionAnimationCurve,
    this.draggedItemDecorator = defaultDraggedItemDecorator,
    this.draggedItemDecorationAnimationDuration =
        defaultDraggedItemDecorationAnimationDuration,
    this.swipedItemDecorator = defaultDraggedItemDecorator,
    this.swipedItemDecorationAnimationDuration =
        defaultSwipedItemDecorationAnimationDuration,
    this.autoScrollerVelocityScalar = defaultAutoScrollVelocityScalar,
    this.swipeAwayExtent = defaultSwipeAwayExtent,
    this.swipeAwayVelocity = defaultSwipeAwayVelocity,
    this.swipeAwaySpringDescription = defaultFlingSpringDescription,
  })  : reorderableGetter = reorderableGetter ?? returnTrue,
        draggableGetter = draggableGetter ?? returnTrue;

  final _state =
      model.ControllerState<_ItemsLayerState, _OverlayedItemsLayerState>();

  ScrollController? _scrollController;
  EdgeDraggingAutoScroller? _autoScroller;
  late OverridedSliverChildBuilderDelegate _childrenDelegate;

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

  void insertItem(
    int index,
    AnimatedItemBuilder builder, {
    Duration duration = defaultInsertItemAnimationDuration,
  }) {
    if (_state.itemCount == null) {
      throw ('$runtimeType must be connected with a $ListView or $GridView');
    }
    if (index < 0 || index > _state.itemCount!) {
      throw RangeError.value(index);
    }

    final insertedItem = _state.insertItem(
      index: index,
      itemFactory: createItem,
    );

    insertedItem.animateItemBuilder(
      builder: builder,
      duration: duration,
      vsync: vsync,
    );

    overlayedItemsLayer!.rebuild(() {
      for (var renderedItem in _state.renderedItems
          .where((x) => x.id != insertedItem.id)
          .where(isNotDragged)
          .where(isNotSwiped)) {
        _state.putOverlayedItemIfAbsent(
          id: renderedItem.id,
          ifAbsent: () => createOverlayedItem(renderedItem),
        )
          ..index = renderedItem.index >= index
              ? renderedItem.index + 1
              : renderedItem.index
          ..setInteractive(false, notify: false);
      }
    });

    itemsLayer!.rebuild();
  }

  void removeItem(
    int index,
    AnimatedRemovedItemBuilder builder, {
    int? zIndex,
    Duration duration = defaultRemoveItemAnimationDuration,
  }) {
    if (_state.itemCount == null) {
      throw ('$runtimeType must be connected with a $ListView or $GridView');
    }
    if (index < 0 || index >= _state.itemCount!) {
      throw RangeError.value(index);
    }

    final removedItem = _state.removeItem(index: index);
    if (removedItem == null) return;

    final renderedItem = _state.renderedItemBy(id: removedItem.id);
    if (renderedItem == null) {
      removedItem.dispose();
    }

    overlayedItemsLayer!.rebuild(() {
      for (var renderedItem in _state.renderedItems
          .where((x) => x.id != removedItem.id)
          .where(isNotDragged)
          .where(isNotSwiped)) {
        _state.putOverlayedItemIfAbsent(
          id: renderedItem.id,
          ifAbsent: () => createOverlayedItem(renderedItem),
        )
          ..index = renderedItem.index > index
              ? renderedItem.index - 1
              : renderedItem.index
          ..setInteractive(false, notify: false);
      }

      if (renderedItem != null) {
        _state.putOverlayedItemIfAbsent(
          id: renderedItem.id,
          ifAbsent: () => createOverlayedItem(
            renderedItem,
            builder: removedItem.builder,
          ),
        )
          ..outgoing = true
          ..setInteractive(false, notify: false)
          ..setZIndex(zIndex ?? outgoingItemZIndex, notify: false)
          ..animateRemovedItemBuilder(
            builder: builder,
            duration: duration,
            vsync: vsync,
          ).whenComplete(
            () => overlayedItemsLayer!.rebuild(() {
              _state.removeOverlayedItem(id: removedItem.id)?.dispose();
              removedItem.dispose();
            }),
          );
      }
    });

    itemsLayer!.rebuild();
  }

  void moveItem(
    int index, {
    required int destIndex,
    Duration? duration,
    Curve? curve,
  }) {
    if (_state.itemCount == null) {
      throw ('$runtimeType must be connected with a $ListView or $GridView');
    }
    if (index < 0 || index >= _state.itemCount!) {
      throw RangeError.value(index);
    }
    if (!reorderableGetter(index)) {
      throw ('The item is not reorderable at $index');
    }
    if (!reorderableGetter(destIndex)) {
      throw ('The item is not reorderable at $destIndex');
    }
    if (index == destIndex) return;

    final itemAtIndex = ensureItemAt(index: index);
    final itemAtDestIndex = ensureItemAt(index: destIndex);

    final permutations = _state.moveItem(
      index: index,
      destIndex: destIndex,
      reorderableGetter: reorderableGetter,
      itemFactory: createItem,
    );

    overlayedItemsLayer!.rebuild(() {
      for (var renderedItem
          in _state.renderedItems.where(isNotDragged).where(isNotSwiped)) {
        _state.putOverlayedItemIfAbsent(
          id: renderedItem.id,
          ifAbsent: () => createOverlayedItem(renderedItem),
        )
          ..index = permutations.indexOf(renderedItem.id) ?? renderedItem.index
          ..setInteractive(false, notify: false);
      }

      if (!_state.isRendered(id: itemAtIndex.id)) {
        final fakeGeometry = getFakeAnchorGeometryOfNotRenderedItem(
          notRenderedItemIndex: index,
          anyRenderedItemIndex: _state.renderedItems.first.index,
        );

        _state
            .putOverlayedItem(
              model.OverlayedItem(
                index: permutations.indexOf(itemAtIndex.id)!,
                id: itemAtIndex.id,
                position: fakeGeometry.topLeft,
                constraints: BoxConstraints.tight(fakeGeometry.size),
                builder: model.ItemBuilder.adaptOtherItemBuilder(itemAtIndex),
                interactive: false,
              ),
            )
            .addListener(overlayedItemsLayer!.rebuild);
      }

      if (!_state.isRendered(id: itemAtDestIndex.id)) {
        final fakeGeometry = getFakeAnchorGeometryOfNotRenderedItem(
          notRenderedItemIndex: destIndex,
          anyRenderedItemIndex: _state.renderedItems.first.index,
        );

        _state
            .putOverlayedItem(
              model.OverlayedItem(
                index: permutations.indexOf(itemAtDestIndex.id)!,
                id: itemAtDestIndex.id,
                position: fakeGeometry.topLeft,
                constraints: BoxConstraints.tight(fakeGeometry.size),
                builder:
                    model.ItemBuilder.adaptOtherItemBuilder(itemAtDestIndex),
                interactive: false,
              ),
            )
            .addListener(overlayedItemsLayer!.rebuild);
      }
    });

    itemsLayer!.rebuild(() => didReorder!.call(permutations));
  }

  void dispose() => _state.dispose();
}

extension _RenderedItemLifecycleHandlers on AnimatedReorderableController {
  void handleRenderedItemInit(RenderedItem item) => registerRenderedItem(item);

  void handleRenderedItemDidUpdate(RenderedItem item) {
    unregisterRenderedItem(item);
    registerRenderedItem(item);
  }

  void handleRenderedItemDispose(RenderedItem item) =>
      unregisterRenderedItem(item);

  void handleRenderedItemDeactivate(RenderedItem item) =>
      unregisterRenderedItem(item);

  void handleRenderedItemDidBuild(item) {
    if (isDragged(item)) return;
    if (isSwiped(item)) return;

    final globalPosition = item.globalPosition;
    if (globalPosition == null) return;

    final overlayedItem = _state.overlayedItemBy(id: item.id);
    if (overlayedItem == null) return;

    final anchorPosition = overlayedItemsLayer!.globalToLocal(globalPosition)!;

    if (overlayedItem.anchorPosition != anchorPosition) {
      overlayedItem
          .animateTo(
            anchorPosition,
            vsync: vsync,
            duration: motionAnimationDuration,
            curve: motionAnimationCurve,
          )
          .whenComplete(
            () => unoverlay(overlayedItem),
          );
    } else if (overlayedItem.motionAnimationStatus?.idle ?? true) {
      unoverlay(overlayedItem);
    }
  }
}

extension _ItemsLayerLyfecycleHandlers on AnimatedReorderableController {
  void handleDidBuildItemsLayer() {
    for (var overlayedItem in _state.overlayedItems
        .where(isNotRendered)
        .where((x) => !x.outgoing)
        .toList()) {
      final fakeGeometry = getFakeAnchorGeometryOfNotRenderedItem(
        notRenderedItemIndex: overlayedItem.index,
        anyRenderedItemIndex: _state.renderedItems.first.index,
        itemSize: overlayedItem.constraints.biggest,
      );

      overlayedItem
          .animateTo(
            fakeGeometry.topLeft,
            vsync: vsync,
            duration: motionAnimationDuration,
            curve: motionAnimationCurve,
          )
          .whenComplete(
            () => unoverlay(overlayedItem),
          );
    }
  }
}

extension _OverlayedItemDragHandlers on AnimatedReorderableController {
  void handleItemDragStart(model.OverlayedItem item) {
    item.stopMotion();

    _state.draggedItem = item;

    if (!_state.isOverlayed(id: item.id)) {
      overlayedItemsLayer?.rebuild(
        () => _state.putOverlayedItem(item)
          ..setZIndex(
            maxZIndex,
            notify: false,
          ),
      );
      _state.renderedItemBy(id: item.id)?.rebuild();
    } else {
      item.setZIndex(maxZIndex);
    }

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
          _state.renderedItemBy(id: item.id)!.globalPosition!,
        )!,
        velocity: item.swipeVelocity,
        screenSize: getScreenSize(),
        vsync: vsync,
      ),
    ]).whenComplete(
      () => unoverlay(item),
    );
  }
}

extension _OverlayedItemSwipeHandlers on AnimatedReorderableController {
  void handleItemSwipeStart(model.OverlayedItem item) {
    item.stopMotion();

    _state.swipedItem = item;

    if (!_state.isOverlayed(id: item.id)) {
      overlayedItemsLayer?.rebuild(
        () => _state.putOverlayedItem(item)
          ..setZIndex(
            maxZIndex,
            notify: false,
          ),
      );
      _state.renderedItemBy(id: item.id)?.rebuild();
    } else {
      item.setZIndex(maxZIndex);
    }

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
    final screenSize = getScreenSize();

    if (item.swipedToRemove(
      extentToRemove: swipeAwayExtent,
      velocityToRemove: swipeAwayVelocity,
    )) {
      final removedItemBuilder = didSwipeAway!.call(item.index);

      removeItem(
        item.index,
        removedItemBuilder,
        zIndex: item.zIndex,
      );

      item.animateFlingTo(
        switch (item.swipeToRemoveDirection!) {
          AxisDirection.left =>
            Offset(-item.constraints.maxWidth, item.position.dy),
          AxisDirection.right => Offset(screenSize.width, item.position.dy),
          AxisDirection.up =>
            Offset(item.position.dx, -item.constraints.maxHeight),
          AxisDirection.down => Offset(item.position.dx, screenSize.height),
        },
        velocity: item.swipeVelocity,
        screenSize: screenSize,
        vsync: vsync,
      );
    } else {
      Future.wait([
        undecorateFuture,
        item.animateFlingTo(
          overlayedItemsLayer!.globalToLocal(
            _state.renderedItemBy(id: item.id)!.globalPosition!,
          )!,
          velocity: item.swipeVelocity,
          screenSize: screenSize,
          vsync: vsync,
        )
      ]).whenComplete(
        () => unoverlay(item),
      );
    }
  }
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

extension _ConstraintsChangeHandler on AnimatedReorderableController {
  void handleConstraintsChange(BoxConstraints constraints) {
    if (_state.constraints != null &&
        scrollController != null &&
        scrollController!.hasClients) {
      final scaleFactor = scrollController!.axis == Axis.vertical
          ? constraints.maxWidth / _state.constraints!.maxWidth
          : constraints.maxHeight / _state.constraints!.maxHeight;

      for (var x in _state.overlayedItems) {
        x.scale(scaleFactor);
      }

      _state.shiftItemsOnScroll = false;
      scrollController!.scaleScrollPosition(scaleFactor);
      _state.shiftItemsOnScroll = true;
    }

    _state.constraints = constraints;
  }
}

extension _SliverGridLayoutChangeHandler on AnimatedReorderableController {
  void handleSliverGridLayoutChange(SliverGridLayout layout) =>
      _state.gridLayout = layout;
}

extension _ChildrenDelegate on AnimatedReorderableController {
  OverridedSliverChildBuilderDelegate get childrenDelegate => _childrenDelegate;
  set childrenDelegate(OverridedSliverChildBuilderDelegate value) =>
      _childrenDelegate = value;

  SliverChildDelegate overrideChildrenDelegate(SliverChildDelegate delegate) =>
      childrenDelegate = OverridedSliverChildBuilderDelegate.override(
        delegate: delegate,
        overridedChildBuilder: buildItemWidget,
        overridedChildCountGetter: () => _state.itemCount,
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
      onInit: handleRenderedItemInit,
      didUpdate: handleRenderedItemDidUpdate,
      onDispose: handleRenderedItemDispose,
      onDeactivate: handleRenderedItemDeactivate,
      didBuild: handleRenderedItemDidBuild,
      recognizeDrag: (renderedItem, event) {
        createOverlayedItem(
          renderedItem,
          recognizerFactory: createReoderGestureRecognizer,
        ).recognizeDrag(
          event,
          context: context,
          onDragStart: (overlayedItem) {
            overlayedItem.recognizerFactory = createImmediateGestureRecognizer;
            handleItemDragStart(overlayedItem);
          },
          onDragUpdate: handleItemDragUpdate,
          onDragEnd: handleItemDragEnd,
        );
      },
      recognizeSwipe: (renderedItem, event) {
        createOverlayedItem(
          renderedItem,
          recognizerFactory: scrollController!.axis == Axis.horizontal
              ? createHorizontalSwipeAwayGestureRecognizer
              : createVerticalSwipeAwayGestureRecognizer,
        ).recognizeSwipe(
          event,
          context: context,
          swipeDirection: swipeAwayDirectionGetter!.call(index)!,
          onSwipeStart: handleItemSwipeStart,
          onSwipeUpdate: handleItemSwipeUpdate,
          onSwipeEnd: handleItemSwipeEnd,
        );
      },
    );
  }
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
    if (!_state.draggedItem!.constraints.isTight) return;

    final size = _state.draggedItem!.constraints.biggest;
    final position = overlayedItemsLayer!.localToGlobal(
      _state.draggedItem!.position,
    )!;

    _autoScroller?.startAutoScrollIfNecessary((position & size).deflate(alpha));
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

    final delta = scrollOffset - _state.scrollOffset;
    _state.scrollOffset = scrollOffset;
    return delta;
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

  model.OverlayedItem createOverlayedItem(
    RenderedItem renderedItem, {
    int? index,
    bool interactive = true,
    bool outgoing = false,
    int zIndex = defaultZIndex,
    model.RecognizerFactory? recognizerFactory,
    model.ItemBuilder? builder,
  }) =>
      model.OverlayedItem(
        index: index ?? renderedItem.index,
        id: renderedItem.id,
        position: overlayedItemsLayer!.globalToLocal(
          renderedItem.globalPosition!,
        )!,
        constraints: BoxConstraints.tight(renderedItem.size!),
        zIndex: zIndex,
        interactive: interactive,
        outgoing: outgoing,
        builder: builder ??
            model.ItemBuilder.adaptOtherItemBuilder(
              _state.itemBy(id: renderedItem.id)!,
            ),
        recognizerFactory: recognizerFactory,
      )..addListener(overlayedItemsLayer!.rebuild);

  void registerRenderedItem(RenderedItem item) => _state.putRenderedItem(item);

  void unregisterRenderedItem(RenderedItem item) {
    final registeredRenderedItem = _state.renderedItemBy(id: item.id);
    if (registeredRenderedItem == item) {
      _state.removeRenderedItemBy(id: item.id);
    }
  }

  void reorderAndAutoScrollIfNecessary() {
    reorderIfNecessary();
    autoScrollIfNecessary();
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

  void unoverlay(model.OverlayedItem item) {
    if (!_state.isOverlayed(id: item.id)) return;
    overlayedItemsLayer?.rebuild(() => _state.removeOverlayedItem(id: item.id));
    _state.renderedItemBy(id: item.id)?.rebuild();
  }

  Rect getFakeAnchorGeometryOfNotRenderedItem({
    required int notRenderedItemIndex,
    required int anyRenderedItemIndex,
    Size? itemSize,
  }) {
    itemSize ??= _state.gridLayout
            ?.getChildSize(notRenderedItemIndex, scrollController!.axis) ??
        measureItemWidgetAt(index: notRenderedItemIndex);

    final screenGeometry = Offset.zero & getScreenSize();
    final fakePosition = switch (scrollController!.axisDirection) {
      AxisDirection.down => notRenderedItemIndex < anyRenderedItemIndex
          ? screenGeometry.topCenter -
              Offset(itemSize.width / 2, itemSize.height)
          : screenGeometry.bottomCenter - Offset(itemSize.width / 2, 0),
      AxisDirection.right => notRenderedItemIndex < anyRenderedItemIndex
          ? screenGeometry.centerLeft -
              Offset(itemSize.width, itemSize.height / 2)
          : screenGeometry.centerRight - Offset(0, itemSize.height / 2),
      AxisDirection.up => notRenderedItemIndex < anyRenderedItemIndex
          ? screenGeometry.bottomCenter - Offset(itemSize.width / 2, 0)
          : screenGeometry.topCenter -
              Offset(itemSize.width / 2, itemSize.height),
      AxisDirection.left => notRenderedItemIndex < anyRenderedItemIndex
          ? screenGeometry.centerRight - Offset(0, itemSize.height / 2)
          : screenGeometry.centerLeft -
              Offset(itemSize.width, itemSize.height / 2),
    };

    return fakePosition & itemSize;
  }

  Size measureItemWidgetAt({required int index}) => MeasureUtil.measureWidget(
        context: _scrollController!.scrollableState!.context,
        builder: (context) =>
            _childrenDelegate.originalBuilder(context, index)!,
        constraints: scrollController!.axis == Axis.vertical
            ? BoxConstraints(maxWidth: _state.constraints!.maxWidth)
            : BoxConstraints(maxHeight: _state.constraints!.maxHeight),
      );

  Size getScreenSize() {
    final screenView = WidgetsBinding.instance.platformDispatcher.views.first;
    return screenView.physicalSize / screenView.devicePixelRatio;
  }
}

extension _StateUtils on AnimatedReorderableController {
  Iterable<model.OverlayedItem> get overlayedItemsOrderedByZIndex =>
      _state.overlayedItems.toList()
        ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

  bool isDragged(RenderedItem item) => _state.isDragged(id: item.id);

  bool isSwiped(RenderedItem item) => _state.isSwiped(id: item.id);

  bool isNotDragged(RenderedItem item) => !isDragged(item);

  bool isNotSwiped(RenderedItem item) => !isSwiped(item);

  bool isRendered(model.OverlayedItem item) => _state.isRendered(id: item.id);

  bool isNotRendered(model.OverlayedItem item) => !isRendered(item);

  GlobalKey<_ItemsLayerState> get itemsLayerKey => _state.itemsLayerKey;

  GlobalKey<_OverlayedItemsLayerState> get overlayedItemsLayerKey =>
      _state.overlayedItemsLayerKey;

  _ItemsLayerState? get itemsLayer => _state.itemsLayerState;

  _OverlayedItemsLayerState? get overlayedItemsLayer =>
      _state.overlayedItemsLayerState;
}
