import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'const.dart';
import 'model/model.dart' as model;
import 'model/permutations.dart';
import 'widget/item_widget.dart';
import 'widget/outgoing_item_widget.dart';
import 'widget/overlayed_item_widget.dart';
import 'util/misc.dart';
import 'util/overrided_sliver_child_builder_delegate.dart';
import 'util/sliver_grid_delegate_decorator.dart';

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
              _OutgoingItemsLayer(
                key: controller.outgoingItemsLayerKey,
                controller: controller,
                clipBehavior: clipBehavior,
                padding: padding,
                scrollDirection: scrollDirection,
              ),
              _CollectionViewLayer(
                key: controller.collectionViewLayerKey,
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

class _OutgoingItemsLayer extends StatefulWidget {
  const _OutgoingItemsLayer({
    super.key,
    required this.controller,
    required this.clipBehavior,
    required this.padding,
    required this.scrollDirection,
  });

  final AnimatedReorderableController controller;
  final Clip clipBehavior;
  final EdgeInsetsGeometry? padding;
  final Axis scrollDirection;

  @override
  State<_OutgoingItemsLayer> createState() => _OutgoingItemsLayerState();
}

class _OutgoingItemsLayerState extends State<_OutgoingItemsLayer> {
  GlobalKey canvasKey = GlobalKey();

  AnimatedReorderableController get controller => widget.controller;
  EdgeInsetsGeometry get effectivePadding =>
      widget.padding ?? mediaQueryScrollablePaddingOf(widget.scrollDirection);

  Offset? globalToLocal(Offset point) =>
      canvasKey.currentContext?.findRenderBox()?.globalToLocal(point);

  @override
  Widget build(BuildContext context) => Padding(
        padding: effectivePadding,
        child: Stack(
          key: canvasKey,
          clipBehavior: widget.clipBehavior,
          children: [
            for (var item in controller.outgoingItems)
              OutgoingItemWidget(
                key: ValueKey(item.id),
                item: item,
              )
          ],
        ),
      );
}

class _CollectionViewLayer extends StatefulWidget {
  const _CollectionViewLayer({
    super.key,
    required this.controller,
    required this.builder,
  });

  final AnimatedReorderableController controller;
  final WidgetBuilder builder;

  @override
  State<_CollectionViewLayer> createState() => _CollectionViewLayerState();
}

class _CollectionViewLayerState extends State<_CollectionViewLayer> {
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
            for (var item
                in controller.overlayedItems.toList()
                  ..sort((a, b) => a.zIndex.compareTo(b.zIndex)))
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
    required this.didReorder,
    this.didSwipeAway,
    required this.vsync,
    this.motionAnimationDuration = du300ms,
    this.motionAnimationCurve = Curves.easeInOut,
    this.draggedItemDecorator = defaultDraggedItemDecorator,
    this.draggedItemDecorationAnimationDuration = du300ms,
    this.swipedItemDecorator = defaultDraggedItemDecorator,
    this.swipedItemDecorationAnimationDuration = du300ms,
    this.autoScrollerVelocityScalar = defaultAutoScrollVelocityScalar,
  })  : reorderableGetter = reorderableGetter ?? returnTrue,
        draggableGetter = draggableGetter ?? returnTrue;

  late GlobalKey<_OutgoingItemsLayerState> _outgoingItemsLayerKey;
  late GlobalKey<_CollectionViewLayerState> _itemsLayerKey;
  late GlobalKey<_OverlayedItemsLayerState> _overlayedItemsLayerKey;

  final IdGetter idGetter;
  final ReorderableGetter reorderableGetter;
  final DraggableGetter draggableGetter;
  final SwipeAwayDirectionGetter? swipeAwayDirectionGetter;
  final double autoScrollerVelocityScalar;

  final ReorderCallback didReorder;
  SwipeAwayCallback? didSwipeAway;

  final TickerProvider vsync;

  final Duration motionAnimationDuration;
  final Curve motionAnimationCurve;

  final model.AnimatedItemDecorator? draggedItemDecorator;
  final Duration draggedItemDecorationAnimationDuration;
  final model.AnimatedItemDecorator? swipedItemDecorator;
  final Duration swipedItemDecorationAnimationDuration;
  late final _state = model.ControllerState(
    AnimationController(
      vsync: vsync,
      duration: motionAnimationDuration,
    ),
  );
  ScrollController? _scrollController;
  EdgeDraggingAutoScroller? _autoScroller;
  Offset _scrollOffsetMark = Offset.zero;
  bool _shiftItemsOnScroll = true;
  BoxConstraints? _constraintsMark;
  late OverridedSliverChildBuilderDelegate _childrenDelegate;
  SliverGridLayout? _gridLayout;

  void insertItem(
    int index, {
    required AnimatedItemBuilder builder,
    Duration duration = du300ms,
  }) {}

  void removeItem(
    int index, {
    required AnimatedRemovedItemBuilder builder,
    Duration duration = du300ms,
  }) {}

  void moveItem(
    int index, {
    required int destIndex,
    Duration duration = du300ms,
  }) {
    if (itemCount == null) {
      throw ('AnimatedReorderableController has not been attached to collection view');
    }
    if (index < 0 || index >= itemCount!) {
      throw RangeError.value(index);
    }
    if (!reorderableGetter(index)) {
      throw ('Item is not reorderable at $index');
    }
    if (!reorderableGetter(destIndex)) {
      throw ('Item is not reorderable at $destIndex');
    }
    if (index == destIndex) return;

    measureItems(
      fromIndex: 0,
      toIndex: math.max(index, destIndex),
    );

    final permutations = _state.moveItem(
      index: index,
      destIndex: destIndex,
      reorderableGetter: reorderableGetter,
      itemFactory: createItem,
    );

    _state
      ..recomputeItemPositions(
        canvasGeometry: overlayedItemsLayer!.computeCanvasGeometry()!,
        axisDirection: scrollController!.axisDirection,
      )
      ..forwardMotionAnimation(from: 0)
      ..renderedItems
          .where((x) => _state.isNotDragged(itemId: x.id))
          .where((x) => _state.hasPositionUpdate(itemId: x.id))
          .map((x) =>
              _state.overlayedItemBy(id: x.id) ??
              model.OverlayedItem(
                index: permutations.indexOf(x.id) ?? x.index,
                id: x.id,
                position: overlayedItemsLayer!.globalToLocal(x.globalPosition)!,
                size: x.size,
                draggable: false,
                builder: model.ItemBuilder.adaptIndexedWidgetBuilder(x.builder),
                zIndex:
                    x.index == index ? maxZIndex : _state.overlayedItemsNumber,
              ))
          .map(overlay)
          .forEach((x) => anchor(x).whenComplete(() => unoverlay(x)));

    collectionViewLayer?.rebuild(() => didReorder(permutations));
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
    this.scrollController = scrollController ?? ScrollController();
    itemCount = getChildCount(childrenDelegate);
    outgoingItemsLayerKey = GlobalKey();
    collectionViewLayerKey = GlobalKey();
    overlayedItemsLayerKey = GlobalKey();
    return this;
  }

  model.OverlayedItem overlay(model.OverlayedItem item) {
    if (_state.isOverlayed(itemId: item.id)) return item;
    overlayedItemsLayer?.rebuild(() => _state.putOverlayedItem(item));
    _state.renderedItemBy(id: item.id)?.rebuild();
    return item;
  }

  void unoverlay(model.OverlayedItem item) {
    if (!_state.isOverlayed(itemId: item.id)) return;
    overlayedItemsLayer?.rebuild(() => _state.removeOverlayedItem(id: item.id));
    _state.renderedItemBy(id: item.id)?.rebuild();
  }

  Future decorateDragged(model.OverlayedItem item) =>
      item
          .decorateBuilder(
            draggedItemDecorator,
            vsync: vsync,
            decoratorId: draggedItemDecoratorId,
            duration: draggedItemDecorationAnimationDuration,
          )
          ?.forwardDecoration() ??
      Future.value();

  Future undecorateDragged(model.OverlayedItem item) =>
      item.decoratedBuilder(draggedItemDecoratorId)?.reverseDecoration() ??
      Future.value();

  Future decorateSwiped(model.OverlayedItem item) =>
      item
          .decorateBuilder(
            swipedItemDecorator,
            vsync: vsync,
            decoratorId: swipedItemDecoratorId,
            duration: swipedItemDecorationAnimationDuration,
          )
          ?.forwardDecoration() ??
      Future.value();

  Future undecorateSwiped(model.OverlayedItem item) =>
      item.decoratedBuilder(swipedItemDecoratorId)?.reverseDecoration() ??
      Future.value();

  Future anchor(model.OverlayedItem item) {
    final anchorPosition = _state.itemBy(id: item.id)!.position - scrollOffset;

    return item.forwardMotionAnimation(
      end: overlayedItemsLayer!.globalToLocal(anchorPosition)!,
      from: 0.0,
      vsync: vsync,
      duration: motionAnimationDuration,
      curve: motionAnimationCurve,
    );
  }

  void reorderAndAutoScrollIfNecessary() {
    reorderIfNecessary();
    autoScrollIfNecessary();
  }

  void measureItems({
    required int fromIndex,
    required int toIndex,
  }) {
    for (var index = math.min(fromIndex, toIndex);
        index <= math.max(fromIndex, toIndex);
        index++) {
      final item = ensureItemAt(index: index);

      if (!item.measured) {
        // TODO: measure
      }
    }
  }
}

extension _ScrollHandler on AnimatedReorderableController {
  void handleScroll() {
    final delta = markScrollOffset(scrollOffset);

    if (_shiftItemsOnScroll) {
      for (var x in _state.outgoingItems) {
        x.shift(-delta);
      }
      for (var x in _state.overlayedItems
          .where((x) => _state.isNotDragged(itemId: x.id))
          .where((x) => _state.isNotSwiped(itemId: x.id))) {
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
    if (_constraintsMark != null &&
        scrollController != null &&
        scrollController!.hasClients) {
      final scaleFactor = scrollController!.axis == Axis.vertical
          ? constraints.maxWidth / _constraintsMark!.maxWidth
          : constraints.maxHeight / _constraintsMark!.maxHeight;

      for (var x in _state.outgoingItems) {
        x.scale(scaleFactor);
      }
      for (var x in _state.items) {
        x.scale(scaleFactor);
      }
      for (var x in _state.overlayedItems) {
        x.scale(scaleFactor);
      }

      _shiftItemsOnScroll = false;
      scrollController!.scaleScrollPosition(scaleFactor);
      _shiftItemsOnScroll = true;
    }

    _constraintsMark = constraints;
  }
}

extension _ItemDragHandlers on AnimatedReorderableController {
  void handleItemDragStart(model.OverlayedItem item) {
    _state.draggedItem = item;
    overlay(item);
    decorateDragged(item);
  }

  void handleItemDragUpdate(model.OverlayedItem _) =>
      reorderAndAutoScrollIfNecessary();

  void handleItemDragEnd(model.OverlayedItem item) {
    _state.draggedItem = null;
    stopAutoScroll(forceStopAnimation: true);
    Future.wait([
      undecorateDragged(item),
      anchor(item),
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
    _state.swipedItem = item;
    overlay(item);
    decorateSwiped(item);
  }

  void handleItemSwipeUpdate(model.OverlayedItem item) {
    // noop
  }

  void handleItemSwipeEnd(model.OverlayedItem item) {
    _state.swipedItem = null;
    Future.wait([
      undecorateSwiped(item),
      anchor(item),
    ]).whenComplete(
      () => unoverlay(item),
    );
  }
}

extension _Misc on AnimatedReorderableController {
  int? get itemCount => _state.itemCount;
  set itemCount(int? value) => _state.itemCount = value;
  Iterable<model.OutgoingItem> get outgoingItems => _state.outgoingItems;
  Iterable<model.OverlayedItem> get overlayedItems => _state.overlayedItems;

  GlobalKey<_OutgoingItemsLayerState> get outgoingItemsLayerKey =>
      _outgoingItemsLayerKey;
  set outgoingItemsLayerKey(GlobalKey<_OutgoingItemsLayerState> value) =>
      _outgoingItemsLayerKey = value;
  _OutgoingItemsLayerState? get outgoingItemsLayer =>
      outgoingItemsLayerKey.currentState;

  GlobalKey<_CollectionViewLayerState> get collectionViewLayerKey =>
      _itemsLayerKey;
  set collectionViewLayerKey(GlobalKey<_CollectionViewLayerState> value) =>
      _itemsLayerKey = value;
  _CollectionViewLayerState? get collectionViewLayer =>
      collectionViewLayerKey.currentState;

  GlobalKey<_OverlayedItemsLayerState> get overlayedItemsLayerKey =>
      _overlayedItemsLayerKey;
  set overlayedItemsLayerKey(GlobalKey<_OverlayedItemsLayerState> value) =>
      _overlayedItemsLayerKey = value;
  _OverlayedItemsLayerState? get overlayedItemsLayer =>
      overlayedItemsLayerKey.currentState;
}

extension _Scrolling on AnimatedReorderableController {
  ScrollController? get scrollController => _scrollController;
  set scrollController(ScrollController? value) {
    if (_scrollController == value) return;
    addPostFrame(() {
      initAutoscroller();
      markScrollOffset(scrollOffset);
    });
    _scrollController?.removeListener(handleScroll);
    (_scrollController = value)?.addListener(handleScroll);
  }

  Offset get scrollOffset => scrollController!.scrollOffset!;

  void initAutoscroller() {
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

    final delta = scrollOffset - _scrollOffsetMark;
    _scrollOffsetMark = scrollOffset;
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
      overlayedGetter: (id) => _state.isOverlayed(itemId: id),
      builder: item.builder.build,
      onInit: registerRenderedItem,
      didUpdate: (renderedItem) {
        unregisterRenderedItem(renderedItem);
        registerRenderedItem(renderedItem);
      },
      onDispose: unregisterRenderedItem,
      onDeactivate: unregisterRenderedItem,
      didBuild: (renderedItem) {
        final geometry = renderedItem.computeGeometry(scrollOffset);
        item.setGeometry(geometry ?? item.geometry);
        item.measured = true;
      },
      recognizeDrag: (context, event) {
        final geometry = context.computeGeometry()!;

        model.OverlayedItem(
          index: index,
          id: item.id,
          position: overlayedItemsLayer!.globalToLocal(geometry.position)!,
          size: geometry.size,
          draggable: true,
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
          draggable: true,
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
      _state.itemAt(index: index) ?? _state.putItem(createItem(index));

  model.Item createItem(int index) => model.Item(
        id: idGetter(index),
        builder: model.ItemBuilder.adaptIndexedWidgetBuilder(
          childrenDelegate.originalBuilder,
        ),
      );

  void registerRenderedItem(RenderedItem renderedItem) {
    _state.putRenderedItem(renderedItem);
    _state.setOrder(index: renderedItem.index, id: renderedItem.id);
  }

  void unregisterRenderedItem(RenderedItem item) {
    final registeredRenderedItem = _state.renderedItemBy(id: item.id);
    if (registeredRenderedItem == item) {
      _state.removeRenderedItemBy(id: item.id);
    }
  }
}
