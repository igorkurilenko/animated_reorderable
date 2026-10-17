import 'package:flutter/widgets.dart';

import '../model/model.dart' show RenderedItem;
import '../model/swipe_direction.dart';
import '../util/geometry.dart';

/// What an item widget asks of the controller, and what it tells it.
abstract interface class ItemHost {
  bool isReorderable(int index);
  bool isDraggable(int index);
  SwipeDirection? swipeToRemoveDirectionAt(int index);

  /// The size of the item while the overlay shows it, or null.
  Size? overlayedSizeOf(Key key);

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
    required this.host,
  });

  final int index;
  final GlobalKey childKey;
  final NullableIndexedWidgetBuilder builder;
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
  Size? get overlayedSize => host.overlayedSizeOf(key);
  @override
  SwipeDirection? get swipeToRemoveDirection =>
      host.swipeToRemoveDirectionAt(index);
  bool get swipeable => swipeToRemoveDirection != null;
  @override
  Offset? get globalPosition => findRenderBox()?.localToGlobal(Offset.zero);
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
  bool contains(Offset point) =>
      findRenderBox()?.getGeometry().contains(point) ?? false;

  @override
  void initState() {
    super.initState();
    host.didInitItem(this);
  }

  @override
  void didUpdateWidget(covariant ItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) host.didChangeItemIndex(this);
  }

  @override
  void deactivate() {
    host.didDeactivateItem(this);
    super.deactivate();
  }

  @override
  void rebuild() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    host.didBuildItem(this);

    // While the overlay shows the item, its subtree lives there and a
    // placeholder keeps its place in the list.
    final overlayedSize = this.overlayedSize;
    if (overlayedSize != null) return SizedBox.fromSize(size: overlayedSize);

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
