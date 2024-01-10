import 'package:flutter/widgets.dart';

import 'animated_reorderable_controller.dart';
import 'const.dart';
import 'model/model.dart' as model;
import 'model/permutations.dart';
import 'util/overrided_sliver_child_builder_delegate.dart';
import 'util/sliver_grid_delegate_decorator.dart';
import 'util/misc.dart';
import 'widget/items_layer.dart';
import 'widget/overlayed_items_layer.dart';

typedef KeyGetter = Key Function(int index);
typedef ReorderableGetter = bool Function(int index);
typedef DraggableGetter = bool Function(int index);
typedef SwipeToRemoveDirectionGetter = AxisDirection? Function(int index);
typedef ReorderCallback = void Function(Permutations permutations);
typedef SwipeToRemoveCallback = void Function(int index);

abstract class AnimatedReorderable extends StatefulWidget {
  const AnimatedReorderable({
    super.key,
    required this.keyGetter,
    this.motionAnimationDuration = defaultMotionAnimationDuration,
    this.motionAnimationCurve = defaultMotionAnimationCurve,
    this.autoScrollerVelocityScalar = defaultAutoScrollVelocityScalar,
    this.draggableGetter,
    this.reorderableGetter,
    this.onReorder,
    this.swipeToRemoveDirectionGetter,
    this.swipeToRemoveSpringDescription = defaultFlingSpringDescription,
    this.swipeToRemoveExtent = defaultSwipeToRemoveExtent,
    this.swipeToRemoveVelocity = defaultSwipeToRemoveVelocity,
    this.onSwipeToRemove,
    this.draggedItemDecorator,
    this.draggedItemDecorationAnimationDuration =
        defaultDraggedItemDecorationAnimationDuration,
    this.swipedItemDecorator,
    this.swipedItemDecorationAnimationDuration =
        defaultSwipedItemDecorationAnimationDuration,
  })  : assert(
            (swipeToRemoveDirectionGetter != null && onSwipeToRemove != null) ||
                swipeToRemoveDirectionGetter == null,
            "The 'onSwipeToRemove' parameter must be specified"),
        assert(
            (reorderableGetter != null && onReorder != null) ||
                reorderableGetter == null,
            "The 'onReorder' parameter must be specified");

  factory AnimatedReorderable.list({
    Key? key,
    required KeyGetter keyGetter,
    Duration motionAnimationDuration = defaultMotionAnimationDuration,
    Curve motionAnimationCurve = defaultMotionAnimationCurve,
    double autoScrollerVelocityScalar = defaultAutoScrollVelocityScalar,
    DraggableGetter? draggableGetter,
    ReorderableGetter? reorderableGetter,
    ReorderCallback? onReorder,
    SwipeToRemoveDirectionGetter? swipeToRemoveDirectionGetter,
    double swipeToRemoveExtent = defaultSwipeToRemoveExtent,
    double swipeToRemoveVelocity = defaultSwipeToRemoveVelocity,
    SpringDescription swipeToRemoveSpringDescription =
        defaultFlingSpringDescription,
    SwipeToRemoveCallback? onSwipeToRemove,
    model.AnimatedItemDecorator? draggedItemDecorator =
        defaultDraggedItemDecorator,
    Duration draggedItemDecorationAnimationDuration =
        defaultDraggedItemDecorationAnimationDuration,
    model.AnimatedItemDecorator? swipedItemDecorator =
        defaultDraggedItemDecorator,
    Duration swipedItemDecorationAnimationDuration =
        defaultSwipedItemDecorationAnimationDuration,
    required ListView listView,
  }) =>
      _ListView(
        key: key,
        keyGetter: keyGetter,
        motionAnimationDuration: motionAnimationDuration,
        motionAnimationCurve: motionAnimationCurve,
        autoScrollerVelocityScalar: autoScrollerVelocityScalar,
        draggableGetter: draggableGetter,
        reorderableGetter: reorderableGetter,
        onReorder: onReorder,
        swipeToRemoveDirectionGetter: swipeToRemoveDirectionGetter,
        swipeToRemoveExtent: swipeToRemoveExtent,
        swipeToRemoveVelocity: swipeToRemoveVelocity,
        swipeToRemoveSpringDescription: swipeToRemoveSpringDescription,
        onSwipeToRemove: onSwipeToRemove,
        draggedItemDecorator: draggedItemDecorator,
        draggedItemDecorationAnimationDuration:
            draggedItemDecorationAnimationDuration,
        swipedItemDecorator: swipedItemDecorator,
        swipedItemDecorationAnimationDuration:
            swipedItemDecorationAnimationDuration,
        listView: listView,
      );

  factory AnimatedReorderable.grid({
    Key? key,
    required KeyGetter keyGetter,
    Duration motionAnimationDuration = defaultMotionAnimationDuration,
    Curve motionAnimationCurve = defaultMotionAnimationCurve,
    double autoScrollerVelocityScalar = defaultAutoScrollVelocityScalar,
    DraggableGetter? draggableGetter,
    ReorderableGetter? reorderableGetter,
    ReorderCallback? onReorder,
    SwipeToRemoveDirectionGetter? swipeToRemoveDirectionGetter,
    double swipeToRemoveExtent = defaultSwipeToRemoveExtent,
    double swipeToRemoveVelocity = defaultSwipeToRemoveVelocity,
    SpringDescription swipeToRemoveSpringDescription =
        defaultFlingSpringDescription,
    SwipeToRemoveCallback? onSwipeToRemove,
    model.AnimatedItemDecorator? draggedItemDecorator =
        defaultDraggedItemDecorator,
    Duration draggedItemDecorationAnimationDuration =
        defaultDraggedItemDecorationAnimationDuration,
    model.AnimatedItemDecorator? swipedItemDecorator =
        defaultDraggedItemDecorator,
    Duration swipedItemDecorationAnimationDuration =
        defaultSwipedItemDecorationAnimationDuration,
    required GridView gridView,
  }) =>
      _GridView(
        key: key,
        keyGetter: keyGetter,
        motionAnimationDuration: motionAnimationDuration,
        motionAnimationCurve: motionAnimationCurve,
        autoScrollerVelocityScalar: autoScrollerVelocityScalar,
        draggableGetter: draggableGetter,
        reorderableGetter: reorderableGetter,
        onReorder: onReorder,
        swipeToRemoveDirectionGetter: swipeToRemoveDirectionGetter,
        swipeToRemoveExtent: swipeToRemoveExtent,
        swipeToRemoveVelocity: swipeToRemoveVelocity,
        swipeToRemoveSpringDescription: swipeToRemoveSpringDescription,
        onSwipeToRemove: onSwipeToRemove,
        draggedItemDecorator: draggedItemDecorator,
        draggedItemDecorationAnimationDuration:
            draggedItemDecorationAnimationDuration,
        swipedItemDecorator: swipedItemDecorator,
        swipedItemDecorationAnimationDuration:
            swipedItemDecorationAnimationDuration,
        gridView: gridView,
      );

  final KeyGetter keyGetter;

  final DraggableGetter? draggableGetter;

  final ReorderableGetter? reorderableGetter;
  final ReorderCallback? onReorder;

  final SwipeToRemoveDirectionGetter? swipeToRemoveDirectionGetter;
  final SwipeToRemoveCallback? onSwipeToRemove;

  final SpringDescription swipeToRemoveSpringDescription;
  final double swipeToRemoveExtent;
  final double swipeToRemoveVelocity;

  final Duration motionAnimationDuration;
  final Curve motionAnimationCurve;

  final double autoScrollerVelocityScalar;

  final model.AnimatedItemDecorator? draggedItemDecorator;
  final Duration draggedItemDecorationAnimationDuration;
  final model.AnimatedItemDecorator? swipedItemDecorator;
  final Duration swipedItemDecorationAnimationDuration;

  static AnimatedReorderableState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<AnimatedReorderableState>();
  }

  static AnimatedReorderableState of(BuildContext context) {
    final AnimatedReorderableState? result =
        AnimatedReorderable.maybeOf(context);
    assert(() {
      if (result == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
              'AnimatedReorderable.of() called with a context that does not contain an AnimatedReorderable.'),
          ErrorDescription(
            'No AnimatedReorderable ancestor could be found starting from the context that was passed to AnimatedReorderable.of().',
          ),
          ErrorHint(
            'This can happen when the context provided is from the same StatefulWidget that '
            'built the AnimatedReorderable. Please see the AnimatedReorderable documentation for examples '
            'of how to refer to an AnimatedReorderableState object:\n'
            '  https://pub.dev/packages/animated_reorderable',
          ),
          context.describeElement('The context used was'),
        ]);
      }
      return true;
    }());
    return result!;
  }
}

abstract class AnimatedReorderableState<T extends AnimatedReorderable>
    extends State<T> with TickerProviderStateMixin {
  late final AnimatedReorderableController _controller;

  ScrollController? get scrollController;

  SliverChildDelegate get childrenDelegate;

  Clip get clipBehavior;

  @override
  void initState() {
    super.initState();

    _controller = AnimatedReorderableController(
      keyGetter: widget.keyGetter,
      itemCount: getChildCount(childrenDelegate),
      reorderableGetter: widget.reorderableGetter,
      draggableGetter: widget.draggableGetter,
      swipeToRemoveDirectionGetter: widget.swipeToRemoveDirectionGetter,
      onReorder: widget.onReorder,
      onSwipeToRemove: widget.onSwipeToRemove,
      motionAnimationDuration: widget.motionAnimationDuration,
      motionAnimationCurve: widget.motionAnimationCurve,
      draggedItemDecorator: widget.draggedItemDecorator,
      draggedItemDecorationAnimationDuration:
          widget.draggedItemDecorationAnimationDuration,
      swipedItemDecorator: widget.swipedItemDecorator,
      swipedItemDecorationAnimationDuration:
          widget.swipedItemDecorationAnimationDuration,
      autoScrollerVelocityScalar: widget.autoScrollerVelocityScalar,
      swipeToRemoveExtent: widget.swipeToRemoveExtent,
      swipeToRemoveVelocity: widget.swipeToRemoveVelocity,
      swipeToRemoveSpringDescription: widget.swipeToRemoveSpringDescription,
      vsync: this,
    );

    _controller.scrollController = scrollController ?? ScrollController();
  }

  void insertItem(
    int index,
    AnimatedItemBuilder builder, {
    Duration duration = defaultInsertItemAnimationDuration,
  }) =>
      _controller.insertItem(index, builder, duration);

  void removeItem(
    int index,
    AnimatedRemovedItemBuilder builder, {
    Duration duration = defaultRemoveItemAnimationDuration,
    int? zIndex,
  }) =>
      _controller.removeItem(index, builder, duration, zIndex: zIndex);

  void moveItem(
    int index, {
    required int destIndex,
  }) =>
      _controller.moveItem(index, destIndex: destIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          _controller.handleConstraintsChange(constraints);
          return Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: ItemsLayer(
                  key: _controller.itemsLayerKey,
                  controller: _controller,
                  collectionViewBuilder: buildCollectionView,
                  didBuild: _controller.handleDidBuildItemsLayer,
                ),
              ),
              OverlayedItemsLayer(
                key: _controller.overlayedItemsLayerKey,
                controller: _controller,
                clipBehavior: clipBehavior,
              ),
            ],
          );
        },
      );

  Widget buildCollectionView(BuildContext context);
}

class _ListView extends AnimatedReorderable {
  const _ListView({
    super.key,
    required super.keyGetter,
    super.motionAnimationDuration,
    super.motionAnimationCurve,
    super.autoScrollerVelocityScalar,
    super.draggableGetter,
    super.reorderableGetter,
    super.onReorder,
    super.swipeToRemoveDirectionGetter,
    super.swipeToRemoveExtent,
    super.swipeToRemoveVelocity,
    super.swipeToRemoveSpringDescription,
    super.onSwipeToRemove,
    super.draggedItemDecorator,
    super.draggedItemDecorationAnimationDuration,
    super.swipedItemDecorator,
    super.swipedItemDecorationAnimationDuration,
    required this.listView,
  });

  final ListView listView;

  @override
  State<AnimatedReorderable> createState() => _ListViewState();
}

class _ListViewState extends AnimatedReorderableState<_ListView> {
  @override
  ScrollController? get scrollController => widget.listView.controller;

  @override
  SliverChildDelegate get childrenDelegate => widget.listView.childrenDelegate;

  @override
  Clip get clipBehavior => widget.listView.clipBehavior;

  @override
  Widget buildCollectionView(BuildContext context) => ListView.custom(
        key: widget.listView.key,
        scrollDirection: widget.listView.scrollDirection,
        reverse: widget.listView.reverse,
        controller: _controller.scrollController,
        primary: widget.listView.primary,
        physics: widget.listView.physics,
        shrinkWrap: widget.listView.shrinkWrap,
        padding: widget.listView.padding,
        itemExtent: widget.listView.itemExtent,
        prototypeItem: widget.listView.prototypeItem,
        childrenDelegate:
            _controller.overrideChildrenDelegate(childrenDelegate),
        cacheExtent: widget.listView.cacheExtent,
        semanticChildCount: widget.listView.semanticChildCount,
        dragStartBehavior: widget.listView.dragStartBehavior,
        keyboardDismissBehavior: widget.listView.keyboardDismissBehavior,
        restorationId: widget.listView.restorationId,
        clipBehavior: clipBehavior,
      );
}

class _GridView extends AnimatedReorderable {
  const _GridView({
    super.key,
    required super.keyGetter,
    super.motionAnimationDuration,
    super.motionAnimationCurve,
    super.autoScrollerVelocityScalar,
    super.draggableGetter,
    super.reorderableGetter,
    super.onReorder,
    super.swipeToRemoveDirectionGetter,
    super.swipeToRemoveExtent,
    super.swipeToRemoveVelocity,
    super.swipeToRemoveSpringDescription,
    super.onSwipeToRemove,
    super.draggedItemDecorator,
    super.draggedItemDecorationAnimationDuration,
    super.swipedItemDecorator,
    super.swipedItemDecorationAnimationDuration,
    required this.gridView,
  });

  final GridView gridView;

  @override
  State<AnimatedReorderable> createState() => _GridViewState();
}

class _GridViewState extends AnimatedReorderableState<_GridView> {
  @override
  ScrollController? get scrollController => widget.gridView.controller;

  @override
  SliverChildDelegate get childrenDelegate => widget.gridView.childrenDelegate;

  @override
  Clip get clipBehavior => widget.gridView.clipBehavior;

  @override
  Widget buildCollectionView(BuildContext context) => GridView.custom(
        key: widget.gridView.key,
        scrollDirection: widget.gridView.scrollDirection,
        reverse: widget.gridView.reverse,
        controller: _controller.scrollController,
        primary: widget.gridView.primary,
        physics: widget.gridView.physics,
        shrinkWrap: widget.gridView.shrinkWrap,
        padding: widget.gridView.padding,
        gridDelegate: SliverGridLayoutNotifier(
          gridDelegate: widget.gridView.gridDelegate,
          onLayout: _controller.handleSliverGridLayoutChange,
        ),
        childrenDelegate:
            _controller.overrideChildrenDelegate(childrenDelegate),
        cacheExtent: widget.gridView.cacheExtent,
        semanticChildCount: widget.gridView.semanticChildCount,
        dragStartBehavior: widget.gridView.dragStartBehavior,
        keyboardDismissBehavior: widget.gridView.keyboardDismissBehavior,
        restorationId: widget.gridView.restorationId,
        clipBehavior: clipBehavior,
      );
}
