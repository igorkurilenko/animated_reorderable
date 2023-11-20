import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

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
  }) {
    controller.scrollController = gridView.controller ?? ScrollController();
    controller.itemCount = getChildCount(gridView.childrenDelegate);
    return _GridView(controller: controller, gridView: gridView);
  }

  factory AnimatedReorderable.list({
    required AnimatedReorderableController controller,
    required ListView listView,
  }) {
    controller.scrollController = listView.controller ?? ScrollController();
    controller.itemCount = getChildCount(listView.childrenDelegate);
    return _ListView(controller: controller, listView: listView);
  }

  Clip get clipBehavior;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          _OutgoingItemsLayer(
            controller: controller,
            clipBehavior: clipBehavior,
          ),
          _CollectionViewLayer(
            controller: controller,
            builder: buildCollectionView,
          ),
          _OverlayedItemsLayer(
            controller: controller,
            clipBehavior: clipBehavior,
          ),
        ],
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
    required this.controller,
    required this.clipBehavior,
  });

  final AnimatedReorderableController controller;
  final Clip clipBehavior;

  @override
  State<_OutgoingItemsLayer> createState() => _OutgoingItemsLayerState();
}

class _OutgoingItemsLayerState extends State<_OutgoingItemsLayer> {
  AnimatedReorderableController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller._setOutgoingItemsLayerState = setState;
  }

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: widget.clipBehavior,
        children: [
          for (var item in controller.outgoingItems)
            OutgoingItemWidget(
              key: ValueKey(item.id),
              item: item,
              offset: -controller.scrollController!.scrollableLocation!,
            )
        ],
      );
}

class _CollectionViewLayer extends StatefulWidget {
  const _CollectionViewLayer({
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
  void initState() {
    super.initState();
    controller._setCollectionViewLayerState = setState;
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

class _OverlayedItemsLayer extends StatefulWidget {
  const _OverlayedItemsLayer({
    required this.controller,
    required this.clipBehavior,
  });

  final AnimatedReorderableController controller;
  final Clip clipBehavior;

  @override
  State<_OverlayedItemsLayer> createState() => _OverlayedItemsLayerState();
}

class _OverlayedItemsLayerState extends State<_OverlayedItemsLayer> {
  AnimatedReorderableController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller._setOverlayedItemsLayerState = setState;
  }

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: widget.clipBehavior,
        children: [
          for (var item in controller.overlayedItems)
            OverlayedItemWidget(
              key: ValueKey(item.id),
              item: item,
              offset: -controller.scrollController!.scrollableLocation!,
              onDragStart: controller.handleItemDragStart,
              onDragUpdate: controller.handleItemDragUpdate,
              onDragEnd: controller.handleItemDragEnd,
              onSwipeStart: controller.handleItemSwipeStart,
              onSwipeUpdate: controller.handleItemSwipeUpdate,
              onSwipeEnd: controller.handleItemSwipeEnd,
            )
        ],
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
  })  : reorderableGetter = reorderableGetter ?? returnTrue,
        draggableGetter = draggableGetter ?? returnTrue;

  late StateSetter _setOutgoingItemsLayerState;
  late StateSetter _setCollectionViewLayerState;
  late StateSetter _setOverlayedItemsLayerState;

  final IdGetter idGetter;
  final ReorderableGetter reorderableGetter;
  final DraggableGetter draggableGetter;
  final SwipeAwayDirectionGetter? swipeAwayDirectionGetter;

  final ReorderCallback didReorder;
  SwipeAwayCallback? didSwipeAway;

  final TickerProvider vsync;
  final Duration duration;
  final Curve curve;

  final model.AnimatedItemDecorator? draggedItemDecorator;
  final model.AnimatedItemDecorator? swipedItemDecorator;

  final _state = model.ControllerState();
  ScrollController? _scrollController;
  Offset _scrollOffsetMark = Offset.zero;
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

  void _overlayIfNecessary(
    model.OverlayedItem item, {
    model.AnimatedItemDecorator? decorator,
  }) {
    if (_state.isOverlayed(itemId: item.id)) return;

    _setOverlayedItemsLayerState(() {
      _state.putOverlayedItem(item);

      if (decorator != null) {
        final controller = AnimationController(vsync: vsync, duration: du300ms);
        item.decorateBuilder(decorator, controller: controller);
        controller.forward();
      }
    });

    _state.idleItemBy(id: item.id)?.setOverlayed(true);
    _state.renderedItemBy(id: item.id)?.rebuild();
  }

  void _overlayOff(model.OverlayedItem item) {
    if (_state.isNotOverlayed(itemId: item.id)) return;

    if (item.builder is model.AnimatedDecoratedItemBuilder) {
      (item.builder as model.AnimatedDecoratedItemBuilder).reverseAnimation();
    }
  }
}

extension _State on AnimatedReorderableController {
  int? get itemCount => _state.itemCount;
  set itemCount(int? value) => _state.itemCount = value;
  Iterable<model.OutgoingItem> get outgoingItems => _state.outgoingItems;
  Iterable<model.OverlayedItem> get overlayedItems => _state.overlayedItems;
}

extension _Scrolling on AnimatedReorderableController {
  ScrollController? get scrollController => _scrollController;
  set scrollController(ScrollController? value) {
    if (_scrollController == value) return;
    _scrollController?.removeListener(handleScroll);
    (_scrollController = value)?.addListener(handleScroll);
  }

  Offset get scrollOffset => scrollController!.scrollOffset!;

  Offset markScrollOffset() {
    if (_scrollController == null) return Offset.zero;
    if (!_scrollController!.hasClients) return Offset.zero;

    final delta = scrollOffset - _scrollOffsetMark;
    _scrollOffsetMark = scrollOffset;
    return delta;
  }
}

extension _OverridedSliverChildBuilderDelegate
    on AnimatedReorderableController {
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
    final idleItem = ensureIdleItemAt(index: index);
    idleItem.setDraggable(draggableGetter(index));
    idleItem.setReorderable(reorderableGetter(index));
    idleItem.setSwipeDirection(swipeAwayDirectionGetter?.call(index));

    return IdleItemWidget(
      key: ValueKey(idleItem.id),
      controller: this,
      index: index,
      item: idleItem,
      reorderGestureRecognizerFactory: createReoderGestureRecognizer,
      swipeAwayGestureRecognizerFactory:
          scrollController!.axis == Axis.horizontal
              ? createHorizontalSwipeAwayGestureRecognizer
              : createVerticalSwipeAwayGestureRecognizer,
      onInit: _registerRenderedItem,
      didUpdate: (renderedItem) {
        _unregisterRenderedItem(renderedItem);
        _registerRenderedItem(renderedItem);
      },
      onDispose: _unregisterRenderedItem,
      onDeactivate: _unregisterRenderedItem,
      didBuild: (renderedItem) {
        final geometry = renderedItem.computeGeometry(scrollOffset);
        idleItem.setGeometry(geometry ?? idleItem.geometry);
      },
      onDragStart: handleItemDragStart,
      onDragUpdate: handleItemDragUpdate,
      onDragEnd: handleItemDragEnd,
      onSwipeStart: handleItemSwipeStart,
      onSwipeUpdate: handleItemSwipeUpdate,
      onSwipeEnd: handleItemSwipeEnd,
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

  void _registerRenderedItem(RenderedItem renderedItem) {
    _state.putRenderedItem(renderedItem);
    _state.setOrder(index: renderedItem.index, id: renderedItem.id);
  }

  void _unregisterRenderedItem(RenderedItem item) {
    final registeredRenderedItem = _state.renderedItemBy(id: item.id);
    if (registeredRenderedItem == item) {
      _state.removeRenderedItemBy(id: item.id);
    }
  }
}

extension _ScrollHandler on AnimatedReorderableController {
  void handleScroll() {
    final delta = markScrollOffset();
    _state.shiftOverlayedItems(-delta,
        where: (x) => x != _draggedItem && x != _swipedItem);
    _state.shiftOutgoingItems(-delta);
  }
}

extension _SliverGridLayoutChangeHandler on AnimatedReorderableController {
  void handleSliverGridLayoutChange(SliverGridLayout layout) {
    _gridLayout = layout;
  }
}

extension _ItemDragHandlers on AnimatedReorderableController {
  void handleItemDragStart(model.OverlayedItem item) {
    _draggedItem = item;
    _overlayIfNecessary(item, decorator: draggedItemDecorator);
  }

  void handleItemDragUpdate(model.OverlayedItem item) {
    // TODO: implement
  }

  void handleItemDragEnd(model.OverlayedItem item) {
    _draggedItem = null;
    _overlayOff(item);
  }
}

extension _ItemSwipeHandlers on AnimatedReorderableController {
  void handleItemSwipeStart(model.OverlayedItem item) {
    _swipedItem = item;
    _overlayIfNecessary(item, decorator: swipedItemDecorator);
  }

  void handleItemSwipeUpdate(model.OverlayedItem item) {
    // TODO: implement
  }

  void handleItemSwipeEnd(model.OverlayedItem item) {
    _swipedItem = null;
    _overlayOff(item);
  }
}

class Permutations {
  void apply<T>(List<T> list) {}
}
