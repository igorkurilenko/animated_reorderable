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
                didBuild: controller.handleDidBuildItemsLayer,
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

  Offset? localToGlobal(Offset point) =>
      canvasKey.currentContext?.findRenderBox()?.localToGlobal(point);

  Rect? computeCanvasGeometry([Offset offset = Offset.zero]) =>
      canvasKey.currentContext?.computeGeometry(offset);

  @override
  Widget build(BuildContext context) => Padding(
        padding: effectivePadding,
        child: Stack(
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
    int index,
    AnimatedItemBuilder builder, {
    Duration duration = defaultInsertItemAnimationDuration,
  }) {
    if (itemCount == null) {
      throw ('AnimatedReorderableController must be connected with a ListView or GridView');
    }
    if (index < 0 || index > itemCount!) {
      throw RangeError.value(index);
    }

    final insertedItem = _state.insertItem(
      index: index,
      itemFactory: createItem,
    );

    overlayedItemsLayer!.rebuild(() {
      for (var renderedItem in _state.renderedItems
          .where((x) => x.id != insertedItem.id)
          .where(isNotDragged)
          .where(isNotSwiped)) {
        _state.putOverlayedItem(
          ensureOverlayedItem(
            renderedItem,
            index: renderedItem.index >= index
                ? renderedItem.index + 1
                : renderedItem.index,
            interactive: false,
          ),
        );
      }
    });

    insertedItem.animateItemBuilder(
      builder: builder,
      duration: duration,
      vsync: vsync,
    );

    itemsLayer?.rebuild(() {});
  }

  void removeItem(
    int index,
    AnimatedRemovedItemBuilder builder, {
    int? zIndex,
    Duration duration = defaultRemoveItemAnimationDuration,
  }) {
    if (itemCount == null) {
      throw ('AnimatedReorderableController must be connected with a ListView or GridView');
    }
    if (index < 0 || index >= itemCount!) {
      throw RangeError.value(index);
    }

    final removedItem = _state.removeItem(index: index);
    if (removedItem == null) return;

    final renderedItem = _state.renderedItemBy(id: removedItem.id);

    if (renderedItem != null) {
      final outgoingItem = ensureOverlayedItem(
        renderedItem,
        builder: removedItem.builder,
        zIndex: zIndex ?? outgoingItemZIndex,
        interactive: false,
      );

      overlayIfNecessary(outgoingItem);

      outgoingItem
        ..outgoing = true
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
    } else {
      removedItem.dispose();
    }

    overlayedItemsLayer!.rebuild(() {
      for (var renderedItem in _state.renderedItems
          .where((x) => x.id != removedItem.id)
          .where(isNotDragged)
          .where(isNotSwiped)) {
        _state.putOverlayedItem(
          ensureOverlayedItem(
            renderedItem,
            index: renderedItem.index > index
                ? renderedItem.index - 1
                : renderedItem.index,
            interactive: false,
          ),
        );
      }
    });

    itemsLayer?.rebuild(() {});
  }

  void moveItem(
    int index, {
    required int destIndex,
    Duration? duration,
    Curve? curve,
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
        _state.putOverlayedItem(
          ensureOverlayedItem(
            renderedItem,
            index: permutations.indexOf(renderedItem.id) ?? renderedItem.index,
            interactive: false,
          ),
        );
      }

      if (!_state.isRendered(id: itemAtIndex.id)) {
        final fakeGeometry = getNotRenderedItemFakeAnchorGeometry(
          notRenderedItemIndex: index,
          anyRenderedItemIndex: _state.renderedItems.first.index,
        );

        _state.putOverlayedItem(
          model.OverlayedItem(
            index: permutations.indexOf(itemAtIndex.id)!,
            id: itemAtIndex.id,
            position: fakeGeometry.topLeft,
            constraints: BoxConstraints.tight(fakeGeometry.size),
            builder: model.ItemBuilder.adaptOtherItemBuilder(itemAtIndex),
            interactive: false,
          ),
        );
      }

      if (!_state.isRendered(id: itemAtDestIndex.id)) {
        final fakeGeometry = getNotRenderedItemFakeAnchorGeometry(
          notRenderedItemIndex: destIndex,
          anyRenderedItemIndex: _state.renderedItems.first.index,
        );

        _state.putOverlayedItem(
          model.OverlayedItem(
            index: permutations.indexOf(itemAtDestIndex.id)!,
            id: itemAtDestIndex.id,
            position: fakeGeometry.topLeft,
            constraints: BoxConstraints.tight(fakeGeometry.size),
            builder: model.ItemBuilder.adaptOtherItemBuilder(itemAtDestIndex),
            interactive: false,
          ),
        );
      }
    });

    itemsLayer?.rebuild(() => didReorder!.call(permutations));
  }

  void dispose() => _state.dispose();
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

  void overlayIfNecessary(model.OverlayedItem item) {
    if (_state.isOverlayed(id: item.id)) return;
    overlayedItemsLayer?.rebuild(() => _state.putOverlayedItem(item));
    _state.renderedItemBy(id: item.id)?.rebuild();
    return;
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

  Size measureItemWidgetAt({required int index}) => MeasureUtil.measureWidget(
        context: _scrollController!.scrollableState!.context,
        builder: (context) =>
            _childrenDelegate.originalBuilder(context, index)!,
        constraints: scrollController!.axis == Axis.vertical
            ? BoxConstraints(maxWidth: _state.constraints!.maxWidth)
            : BoxConstraints(maxHeight: _state.constraints!.maxHeight),
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

extension _ItemDragHandlers on AnimatedReorderableController {
  void handleItemDragStart(model.OverlayedItem item) {
    item.stopMotion();
    _state.draggedItem = item;
    overlayIfNecessary(item);
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
    overlayIfNecessary(item);
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
        removedItemBuilder ?? (_, __) => item.widget!,
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
        screenSize: getScreenSize(),
        vsync: vsync,
      );
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

extension _ItemLayerHandlers on AnimatedReorderableController {
  void handleDidBuildItemsLayer() {
    for (var overlayedItem in _state.overlayedItems
        .where(isNotRendered)
        .where((x) => !x.outgoing)
        .toList()) {
      final fakeGeometry = getNotRenderedItemFakeAnchorGeometry(
          notRenderedItemIndex: overlayedItem.index,
          anyRenderedItemIndex: _state.renderedItems.first.index,
          itemSize: overlayedItem.constraints.biggest);

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

extension _Misc on AnimatedReorderableController {
  int? get itemCount => _state.itemCount;

  Iterable<model.OverlayedItem> get overlayedItems => _state.overlayedItems;
  Iterable<model.OverlayedItem> get overlayedItemsOrderedByZIndex =>
      overlayedItems.toList()..sort((a, b) => a.zIndex.compareTo(b.zIndex));

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
      _state.renderedItemBy(id: itemId)?.globalPosition ?? Offset.zero;

  bool isDragged(RenderedItem item) => _state.isDragged(id: item.id);
  bool isSwiped(RenderedItem item) => _state.isSwiped(id: item.id);
  bool isNotDragged(RenderedItem item) => !isDragged(item);
  bool isNotSwiped(RenderedItem item) => !isSwiped(item);
  bool isRendered(model.OverlayedItem item) => _state.isRendered(id: item.id);
  bool isNotRendered(model.OverlayedItem item) => !isRendered(item);
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
        if (isDragged(renderedItem)) return;
        if (isSwiped(renderedItem)) return;

        final globalPosition = renderedItem.globalPosition;
        if (globalPosition == null) return;

        final overlayedItem = _state.overlayedItemBy(id: renderedItem.id);
        if (overlayedItem == null) return;

        final anchorPosition =
            overlayedItemsLayer!.globalToLocal(globalPosition)!;

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
      },
      recognizeDrag: (renderedItem, event) {
        ensureOverlayedItem(
          renderedItem,
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
      recognizeSwipe: (renderedItem, event) {
        ensureOverlayedItem(
          renderedItem,
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
    }
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

  model.OverlayedItem ensureOverlayedItem(
    RenderedItem renderedItem, {
    int? index,
    bool interactive = true,
    int zIndex = defaultZIndex,
    model.RecognizerFactory? recognizerFactory,
    model.ItemBuilder? builder,
  }) =>
      _state.overlayedItemBy(id: renderedItem.id) ??
      model.OverlayedItem(
        index: index ?? renderedItem.index,
        id: renderedItem.id,
        position: overlayedItemsLayer!.globalToLocal(
          renderedItem.globalPosition!,
        )!,
        constraints: BoxConstraints.tight(renderedItem.size!),
        zIndex: zIndex,
        interactive: interactive,
        builder: builder ??
            model.ItemBuilder.adaptOtherItemBuilder(
              _state.itemBy(id: renderedItem.id)!,
            ),
        recognizerFactory: recognizerFactory,
      );

  Rect getNotRenderedItemFakeAnchorGeometry({
    required int notRenderedItemIndex,
    required int anyRenderedItemIndex,
    Size? itemSize,
  }) {
    final screenGeometry = Offset.zero & getScreenSize();
    final size = itemSize ??
        _gridLayout?.getChildSize(
            notRenderedItemIndex, scrollController!.axis) ??
        measureItemWidgetAt(index: notRenderedItemIndex);
    final fakePosition = switch (scrollController!.axisDirection) {
      AxisDirection.down => notRenderedItemIndex < anyRenderedItemIndex
          ? screenGeometry.topCenter - Offset(size.width / 2, size.height)
          : screenGeometry.bottomCenter - Offset(size.width / 2, 0),
      AxisDirection.right => notRenderedItemIndex < anyRenderedItemIndex
          ? screenGeometry.centerLeft - Offset(size.width, size.height / 2)
          : screenGeometry.centerRight - Offset(0, size.height / 2),
      AxisDirection.up => notRenderedItemIndex < anyRenderedItemIndex
          ? screenGeometry.bottomCenter - Offset(size.width / 2, 0)
          : screenGeometry.topCenter - Offset(size.width / 2, size.height),
      AxisDirection.left => notRenderedItemIndex < anyRenderedItemIndex
          ? screenGeometry.centerRight - Offset(0, size.height / 2)
          : screenGeometry.centerLeft - Offset(size.width, size.height / 2),
    };

    return fakePosition & size;
  }
}
