import 'package:flutter/widgets.dart';

import '../animated_reorderable_controller.dart';
import '../controller/overlay_coordinator.dart';
import '../util/geometry.dart';
import 'overlayed_item_widget.dart';

class OverlayedItemsLayer extends StatefulWidget {
  const OverlayedItemsLayer({
    super.key,
    required this.controller,
    required this.clipBehavior,
  });

  final AnimatedReorderableController controller;
  final Clip clipBehavior;

  @override
  State<OverlayedItemsLayer> createState() => OverlayedItemsLayerState();
}

class OverlayedItemsLayerState extends State<OverlayedItemsLayer>
    implements OverlaySpace {
  AnimatedReorderableController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.attachOverlayedItemsLayer(this);
    controller.overlayChanges.addListener(_rebuild);
  }

  @override
  void dispose() {
    controller.overlayChanges.removeListener(_rebuild);
    controller.detachOverlayedItemsLayer(this);
    super.dispose();
  }

  /// The overlay's box. The controller places items in it from the frame
  /// that mounted the layer on, once the frame has laid it out.
  RenderBox get _box => context.findRenderBox()!;

  @override
  Offset globalToLocal(Offset point) => _box.globalToLocal(point);

  @override
  Offset localToGlobal(Offset point) => _box.localToGlobal(point);

  @override
  Size get size => _box.size;

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: widget.clipBehavior,
    children: [
      for (var item in controller.overlayedItemsOrderedByZIndex)
        OverlayedItemWidget(
          key: ObjectKey(item),
          item: item,
          onDragStart: controller.handleItemDragStart,
          onDragUpdate: controller.handleItemDragUpdate,
          onDragEnd: controller.handleItemDragEnd,
          onSwipeStart: controller.handleItemSwipeStart,
          onSwipeUpdate: controller.handleItemSwipeUpdate,
          onSwipeEnd: controller.handleItemSwipeEnd,
          onSizeChange: controller.handleOverlayedItemSizeChange,
        ),
    ],
  );
}
