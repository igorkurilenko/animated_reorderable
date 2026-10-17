import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../model/model.dart' show GlobalOffset, RenderedItem;
import '../model/swipe_direction.dart';
import '../util/geometry.dart';

/// What an item widget asks of the controller, and what it tells it.
abstract interface class ItemHost {
  bool isReorderable(int index);
  bool isDraggable(int index);
  SwipeDirection? swipeToRemoveDirectionAt(int index);

  void didInitItem(RenderedItem item);
  void didChangeItemIndex(RenderedItem item);

  /// Called while [item] builds. The host waits for the frame to lay it
  /// out before it looks at it.
  void didBuildItem(RenderedItem item);
  void didDeactivateItem(RenderedItem item);
  void recognizeReorderDrag(RenderedItem item, PointerDownEvent event);
  void recognizeSwipe(RenderedItem item, PointerDownEvent event);
}

class ItemWidget extends StatefulWidget {
  const ItemWidget({
    required super.key,
    required this.index,
    required this.childKey,
    required this.builder,
    required this.placeholderSize,
    required this.host,
  });

  final int index;
  final GlobalKey childKey;
  final NullableIndexedWidgetBuilder builder;

  /// The size of the placeholder that stands in for the item while the
  /// overlay shows it, or null.
  final ValueListenable<Size?> placeholderSize;
  final ItemHost host;

  @override
  State<ItemWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<ItemWidget> implements RenderedItem {
  ItemHost get host => widget.host;
  @override
  int get index => widget.index;
  @override
  Key get key => widget.key!;
  @override
  bool get reorderable => host.isReorderable(index);
  bool get draggable => host.isDraggable(index);
  @override
  SwipeDirection? get swipeToRemoveDirection =>
      host.swipeToRemoveDirectionAt(index);
  bool get swipeable => swipeToRemoveDirection != null;
  @override
  GlobalOffset? get globalPosition => switch (findRenderBox()) {
    final box? => GlobalOffset(box.localToGlobal(Offset.zero)),
    null => null,
  };
  @override
  Size? get size => findRenderBox()?.size;

  @override
  BoxConstraints? get constraints {
    final renderBox = findRenderBox();
    return renderBox != null && renderBox.hasSize
        ? renderBox.constraints
        : null;
  }

  @override
  bool contains(GlobalOffset point) =>
      findRenderBox()?.getGeometry().contains(point) ?? false;

  @override
  void initState() {
    super.initState();
    widget.placeholderSize.addListener(_rebuild);
    host.didInitItem(this);
  }

  @override
  void didUpdateWidget(covariant ItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeholderSize != widget.placeholderSize) {
      oldWidget.placeholderSize.removeListener(_rebuild);
      widget.placeholderSize.addListener(_rebuild);
    }
    if (oldWidget.index != widget.index) host.didChangeItemIndex(this);
  }

  @override
  void deactivate() {
    host.didDeactivateItem(this);
    super.deactivate();
  }

  @override
  void dispose() {
    widget.placeholderSize.removeListener(_rebuild);
    super.dispose();
  }

  /// It builds again as a whole, so the host reconciles it.
  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    host.didBuildItem(this);

    // While the overlay shows the item, its subtree lives there and a
    // placeholder keeps its place in the list.
    final placeholderSize = widget.placeholderSize.value;
    if (placeholderSize != null) {
      return SizedBox.fromSize(size: placeholderSize);
    }

    final child = widget.builder(context, index);
    return Listener(
      onPointerDown: swipeable ? _recognizeSwipe : null,
      child: Listener(
        onPointerDown: draggable ? _recognizeDrag : null,
        child: child != null
            ? KeyedSubtree(key: widget.childKey, child: child)
            : null,
      ),
    );
  }

  void _recognizeSwipe(PointerDownEvent event) =>
      host.recognizeSwipe(this, event);

  void _recognizeDrag(PointerDownEvent event) =>
      host.recognizeReorderDrag(this, event);
}
