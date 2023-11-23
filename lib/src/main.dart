import 'dart:developer';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'const.dart';
import 'model/model.dart' as model;
import 'widget/idle_item_widget.dart';
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
  GlobalKey stackKey = GlobalKey();
  AnimatedReorderableController get controller => widget.controller;
  EdgeInsetsGeometry get effectivePadding =>
      widget.padding ?? mediaQueryScrollablePaddingOf(widget.scrollDirection);
  Offset? globalToLocal(Offset point) =>
      stackKey.currentContext?.findRenderBox()?.globalToLocal(point);

  @override
  Widget build(BuildContext context) => Padding(
        padding: effectivePadding,
        child: Stack(
          key: stackKey,
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
  GlobalKey stackKey = GlobalKey();
  AnimatedReorderableController get controller => widget.controller;
  EdgeInsetsGeometry get effectivePadding =>
      widget.padding ?? mediaQueryScrollablePaddingOf(widget.scrollDirection);
  Offset? globalToLocal(Offset point) =>
      stackKey.currentContext?.findRenderBox()?.globalToLocal(point);

  @override
  Widget build(BuildContext context) => Padding(
        padding: effectivePadding,
        child: Stack(
          key: stackKey,
          clipBehavior: widget.clipBehavior,
          children: [
            for (var item in controller.overlayedItems)
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
    this.duration = du300ms,
    this.curve = Curves.easeInOut,
    this.draggedItemDecorator = draggedOrSwipedItemDecorator,
    this.swipedItemDecorator = draggedOrSwipedItemDecorator,
    this.autoScrollerVelocityScalar = defaultAutoScrollVelocityScalar,
  })  : reorderableGetter = reorderableGetter ?? returnTrue,
        draggableGetter = draggableGetter ?? returnTrue;

  late GlobalKey<_OverlayedItemsLayerState> _overlayedItemsLayerKey;
  late GlobalKey<_CollectionViewLayerState> _idleItemsLayerKey;
  late GlobalKey<_OutgoingItemsLayerState> _outgoingItemsLayerKey;

  final IdGetter idGetter;
  final ReorderableGetter reorderableGetter;
  final DraggableGetter draggableGetter;
  final SwipeAwayDirectionGetter? swipeAwayDirectionGetter;
  final double autoScrollerVelocityScalar;

  final ReorderCallback didReorder;
  SwipeAwayCallback? didSwipeAway;

  final TickerProvider vsync;
  final Duration duration;
  final Curve curve;

  final model.AnimatedItemDecorator? draggedItemDecorator;
  final model.AnimatedItemDecorator? swipedItemDecorator;

  final _state = model.ControllerState();
  ScrollController? _scrollController;
  EdgeDraggingAutoScroller? _autoScroller;
  Offset _scrollOffsetMark = Offset.zero;
  bool _shiftItemsOnScroll = true;
  BoxConstraints? _constraintsMark;
  late OverridedSliverChildBuilderDelegate _childrenDelegate;
  SliverGridLayout? _gridLayout;
  model.OverlayedItem? _draggedItem;
  model.OverlayedItem? _swipedItem;

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
    required int destinationIndex,
    Duration duration = du300ms,
  }) {}

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

  void overlay(model.OverlayedItem item) {
    rebuildOverlayedItemsLayer(() {
      _state.putOverlayedItem(item);
    });

    _state.idleItemBy(id: item.id)?.setOverlayed(true);
    _state.renderedItemBy(id: item.id)?.rebuild();
  }

  void overlayOff(model.OverlayedItem item) {
    rebuildOverlayedItemsLayer(() {
      _state.removeOverlayedItem(id: item.id);
    });

    _state.idleItemBy(id: item.id)?.setOverlayed(false);
    _state.renderedItemBy(id: item.id)?.rebuild();
  }

  Future decorateDraggedItem(model.OverlayedItem item) =>
      item
          .decorateBuilder(
            draggedItemDecorator,
            decoratorId: draggedItemDecoratorId,
            vsync: vsync,
            duration: duration,
          )
          ?.forwardDecoration() ??
      Future.value();

  Future undecorateDraggedItem(model.OverlayedItem item) =>
      item.decoratedBuilder(draggedItemDecoratorId)?.reverseDecoration() ??
      Future.value();

  Future decorateSwipedItem(model.OverlayedItem item) =>
      item
          .decorateBuilder(
            swipedItemDecorator,
            decoratorId: swipedItemDecoratorId,
            vsync: vsync,
            duration: duration,
          )
          ?.forwardDecoration() ??
      Future.value();

  Future undecorateSwipedItem(model.OverlayedItem item) =>
      item.decoratedBuilder(swipedItemDecoratorId)?.reverseDecoration() ??
      Future.value();

  Future anchor(model.OverlayedItem item) {
    final anchorLocation =
        _state.idleItemBy(id: item.id)!.location - scrollOffset;

    return item.forwardLocationAnimation(
      end: overlayedItemsLayerState!.globalToLocal(anchorLocation)!,
      from: 0.0,
      vsync: vsync,
      duration: duration,
      curve: Curves.easeInOut,
    );
  }
}

extension _ScrollHandler on AnimatedReorderableController {
  void handleScroll() {
    final delta = markScrollOffset(scrollOffset);

    if (_shiftItemsOnScroll) {
      _state.shiftOverlayedItems(
        -delta,
        where: (x) => x != _draggedItem && x != _swipedItem,
      );
      _state.shiftOutgoingItems(-delta);
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

      for(var x in _state.allItems) {
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
    _draggedItem = item;
    overlay(item);
    decorateDraggedItem(item);
  }

  void handleItemDragUpdate(model.OverlayedItem item) {
    autoScrollIfNecessary(item);
  }

  void handleItemDragEnd(model.OverlayedItem item) {
    _draggedItem = null;
    stopAutoScroll(forceStopAnimation: true);
    Future.wait([
      undecorateDraggedItem(item),
      anchor(item),
    ]).whenComplete(
      () => overlayOff(item),
    );
  }
}

extension _ItemSwipeHandlers on AnimatedReorderableController {
  void handleItemSwipeStart(model.OverlayedItem item) {
    _swipedItem = item;
    overlay(item);
    decorateSwipedItem(item);
  }

  void handleItemSwipeUpdate(model.OverlayedItem item) {
    // TODO: implement
  }

  void handleItemSwipeEnd(model.OverlayedItem item) {
    _swipedItem = null;
    Future.wait([
      undecorateSwipedItem(item),
      anchor(item),
    ]).whenComplete(
      () => overlayOff(item),
    );
  }
}

class Permutations {
  void apply<T>(List<T> list) {}
}

extension _Misc on AnimatedReorderableController {
  int? get itemCount => _state.itemCount;
  set itemCount(int? value) => _state.itemCount = value;
  Iterable<model.OutgoingItem> get outgoingItems => _state.outgoingItems;
  Iterable<model.OverlayedItem> get overlayedItems => _state.overlayedItems;

  bool isDragged(model.Item item) => item.id == _draggedItem?.id;
  bool isNotDragged(model.Item item) => !isDragged(item);
  bool isSwiped(model.Item item) => item.id == _swipedItem?.id;
  bool isNotSwiped(model.Item item) => !isSwiped(item);

  GlobalKey<_OutgoingItemsLayerState> get outgoingItemsLayerKey =>
      _outgoingItemsLayerKey;
  set outgoingItemsLayerKey(GlobalKey<_OutgoingItemsLayerState> value) =>
      _outgoingItemsLayerKey = value;
  _OutgoingItemsLayerState? get outgoingItemsLayerState =>
      outgoingItemsLayerKey.currentState;
  void rebuildOutgoingItemsLayer(VoidCallback cb) =>
      outgoingItemsLayerState?.rebuild(cb);
  Offset? globalToOutgoingItemsLayer(Offset point) =>
      outgoingItemsLayerState?.findRenderBox()?.globalToLocal(point);

  GlobalKey<_CollectionViewLayerState> get collectionViewLayerKey =>
      _idleItemsLayerKey;
  set collectionViewLayerKey(GlobalKey<_CollectionViewLayerState> value) =>
      _idleItemsLayerKey = value;
  _CollectionViewLayerState? get collectionViewLayerState =>
      collectionViewLayerKey.currentState;
  void rebuildCollectionViewLayer(VoidCallback cb) =>
      collectionViewLayerState?.rebuild(cb);

  GlobalKey<_OverlayedItemsLayerState> get overlayedItemsLayerKey =>
      _overlayedItemsLayerKey;
  set overlayedItemsLayerKey(GlobalKey<_OverlayedItemsLayerState> value) =>
      _overlayedItemsLayerKey = value;
  _OverlayedItemsLayerState? get overlayedItemsLayerState =>
      overlayedItemsLayerKey.currentState;
  void rebuildOverlayedItemsLayer(VoidCallback cb) =>
      overlayedItemsLayerState?.rebuild(cb);
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
      onScrollViewScrolled: () {
        if (_draggedItem == null) return;
        autoScrollIfNecessary(_draggedItem!);
      },
    );
  }

  void autoScrollIfNecessary(model.OverlayedItem draggedItem) =>
      _autoScroller?.startAutoScrollIfNecessary(
        draggedItem.geometry.deflate(alpha),
      );

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
        overridedChildBuilder: buildIdleItemWidget,
        overridedChildCountGetter: () => itemCount,
      );

  Widget buildIdleItemWidget(BuildContext context, int index) {
    final item = ensureIdleItemAt(index: index);
    item.setDraggable(draggableGetter(index));
    item.setReorderable(reorderableGetter(index));
    item.setSwipeDirection(swipeAwayDirectionGetter?.call(index));

    return IdleItemWidget(
      key: ValueKey(item.id),
      controller: this,
      index: index,
      item: item,
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
      },
      recognizeDrag: (context, event) {
        final scrollableGeometry =
            scrollController!.scrollableState!.computeGeometry()!;
        final geometry = context.computeGeometry()!;
        final layerGeometry = overlayedItemsLayerState!.computeGeometry()!;
        log('layer origin: ${layerGeometry.location}');
        log('scrollable origin: ${scrollableGeometry.location}');
        log('padding: ${overlayedItemsLayerState!.effectivePadding}');

        model.OverlayedItem(
          index: index,
          id: item.id,
          location: overlayedItemsLayerState!.globalToLocal(geometry.location)!,
          size: geometry.size,
          draggable: true,
          reorderable: item.reorderable,
          builder: model.ItemBuilder.adaptOtherItemBuilder(item),
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
      recognizeSwipe: (context, event) {
        final geometry = context.computeGeometry()!;

        model.OverlayedItem(
          index: index,
          id: item.id,
          location: overlayedItemsLayerState!.globalToLocal(geometry.location)!,
          size: geometry.size,
          draggable: true,
          reorderable: false,
          builder: model.ItemBuilder.adaptOtherItemBuilder(item),
          recognizerFactory: scrollController!.axis == Axis.horizontal
              ? createHorizontalSwipeAwayGestureRecognizer
              : createVerticalSwipeAwayGestureRecognizer,
        ).recognizeSwipe(
          event,
          context: context,
          swipeDirection: item.swipeDirection!,
          onSwipeStart: handleItemSwipeStart,
          onSwipeUpdate: handleItemSwipeUpdate,
          onSwipeEnd: handleItemSwipeEnd,
        );
      },
    );
  }

  model.IdleItem ensureIdleItemAt({required int index}) =>
      _state.idleItemAt(index: index) ??
      _state.putIdleItem(
        createIdleItem(index: index),
      );

  model.IdleItem createIdleItem({
    required int index,
    Offset position = Offset.zero,
    Size size = Size.zero,
  }) =>
      model.IdleItem(
        id: idGetter(index),
        location: position,
        size: size,
        draggable: draggableGetter(index),
        reorderable: reorderableGetter(index),
        swipeAwayDirection: swipeAwayDirectionGetter?.call(index),
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
