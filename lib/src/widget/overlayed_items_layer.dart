import 'package:flutter/widgets.dart';

import '../animated_reorderable_controller.dart';
import '../const.dart';
import '../model/model.dart';
import '../util/geometry.dart';
import 'overlayed_item_widget.dart';

/// Shows overlayed items above the list, or with [underTheList] under it.
///
/// The list's own items are at the default z-index. The layer above the
/// list shows the overlayed items at it or above, and is the space the
/// controller places them in. The layer under the list shows the ones
/// below it, as removed items are by default, so the items that move into
/// a removed item's place pass over it.
class OverlayedItemsLayer extends StatefulWidget {
  const OverlayedItemsLayer({
    super.key,
    required this.controller,
    required this.clipBehavior,
    this.underTheList = false,
  });

  final AnimatedReorderableController controller;
  final Clip clipBehavior;
  final bool underTheList;

  @override
  State<OverlayedItemsLayer> createState() => OverlayedItemsLayerState();
}

class OverlayedItemsLayerState extends State<OverlayedItemsLayer>
    implements OverlaySpace {
  AnimatedReorderableController get controller => widget.controller;

  /// The widget of each item and the builder it builds with. The layer
  /// keeps it while it builds again for other items, so an item builds
  /// only when it changes itself.
  final _itemWidgets = <OverlayedItem, (ItemBuilder, Widget)>{};

  @override
  void initState() {
    super.initState();
    if (!widget.underTheList) controller.attachOverlayedItemsLayer(this);
    controller.overlayChanges.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant OverlayedItemsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The latest configuration builds every item again.
    _itemWidgets.clear();
  }

  @override
  void dispose() {
    controller.overlayChanges.removeListener(_rebuild);
    if (!widget.underTheList) controller.detachOverlayedItemsLayer(this);
    super.dispose();
  }

  /// The overlay's box. The controller places items in it from the frame
  /// that mounted the layer on, once the frame has laid it out.
  RenderBox get _box => context.findRenderBox()!;

  @override
  OverlayOffset globalToLocal(GlobalOffset point) =>
      OverlayOffset(_box.globalToLocal(point));

  @override
  GlobalOffset localToGlobal(OverlayOffset point) =>
      GlobalOffset(_box.localToGlobal(point));

  @override
  Size get size => _box.size;

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final items = controller.overlayedItemsOrderedByZIndex
        // A group's layer shows the items held in the group's lists.
        .where((x) => x.sharedSpace == null)
        .where((x) => (x.zIndex < defaultZIndex) == widget.underTheList)
        .toList();
    final shown = items.toSet();
    _itemWidgets.removeWhere((item, _) => !shown.contains(item));
    // The items place themselves, so the stack can't tell when they leave
    // it: the layer clips them as the view clips its own items.
    return ClipRect(
      clipBehavior: widget.clipBehavior,
      child: Stack(
        clipBehavior: Clip.none,
        children: [for (var item in items) _itemWidget(item)],
      ),
    );
  }

  /// The widget of [item]: the one the layer has, unless the item builds
  /// with another builder now, as a removed item does.
  Widget _itemWidget(OverlayedItem item) {
    final builder = item.item.builder;
    if (_itemWidgets[item] case (final kept, final widget)
        when identical(kept, builder)) {
      return widget;
    }
    final widget = OverlayedItemWidget(
      key: ObjectKey(item),
      item: item,
      onPointerDown: controller.recognizeOverlayedItem,
      onSizeChange: controller.handleOverlayedItemSizeChange,
      entranceBuilder: controller.buildEntrance,
    );
    _itemWidgets[item] = (builder, widget);
    return widget;
  }
}
