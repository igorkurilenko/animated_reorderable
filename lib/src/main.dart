import 'package:animated_reorderable/src/util/misc.dart';
import 'package:flutter/widgets.dart';

import 'model/permutations.dart';

typedef IdGetter = int Function(int index);
typedef ReorderableGetter = bool Function(int index);
typedef DraggableGetter = bool Function(int index);
typedef SwipeAwayDirectionGetter = AxisDirection? Function(int index);
typedef ReorderCallback = void Function(Permutations permutations);
typedef SwipeAwayCallback = AnimatedRemovedItemBuilder Function(int index);

const Duration _k300ms = Duration(milliseconds: 300);

abstract class AnimatedReorderable extends StatelessWidget {
  const AnimatedReorderable({super.key, required this.controller});

  final AnimatedReorderableController controller;

  factory AnimatedReorderable.grid({
    required AnimatedReorderableController controller,
    required GridView gridView,
  }) =>
      _GridView(controller: controller, gridView: gridView);

  factory AnimatedReorderable.list({
    required AnimatedReorderableController controller,
    required ListView listView,
  }) =>
      _ListView(controller: controller, listView: listView);

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
        controller: gridView.controller,
        primary: gridView.primary,
        physics: gridView.physics,
        shrinkWrap: gridView.shrinkWrap,
        padding: gridView.padding,
        gridDelegate: gridView.gridDelegate,
        childrenDelegate: gridView.childrenDelegate,
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
        controller: listView.controller,
        primary: listView.primary,
        physics: listView.physics,
        shrinkWrap: listView.shrinkWrap,
        padding: listView.padding,
        itemExtent: listView.itemExtent,
        prototypeItem: listView.prototypeItem,
        childrenDelegate: listView.childrenDelegate,
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
  Widget build(BuildContext context) {
    return const Placeholder();
  }
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
  Widget build(BuildContext context) {
    return const Placeholder();
  }
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
    this.duration = _k300ms,
    this.curve = Curves.easeInOut,
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

  void insertItem(
    int index, {
    required AnimatedItemBuilder builder,
    Duration duration = _k300ms,
  }) {}

  void removeItem(
    int index, {
    required AnimatedRemovedItemBuilder builder,
    Duration duration = _k300ms,
  }) {}

  void moveItem(
    int index, {
    required int destinationIndex,
    Duration duration = _k300ms,
  }) {}
}
