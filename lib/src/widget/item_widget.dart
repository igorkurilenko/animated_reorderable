import 'package:flutter/widgets.dart';

import '../../animated_reorderable.dart';
import '../util/misc.dart';

typedef RenderedItem = _ItemWidgetState;
typedef RenderedItemLifecycleCallback = void Function(RenderedItem item);
typedef ItemGestureRecognizer = void Function(
  RenderedItem item,
  PointerDownEvent event,
);

class ItemWidget extends StatefulWidget {
  const ItemWidget({
    required super.key,
    required this.index,
    required this.reorderableGetter,
    required this.draggableGetter,
    required this.overlayedSizeGetter,
    required this.childKey,
    required this.swipeToRemoveDirectionGetter,
    required this.builder,
    this.onInit,
    this.didUpdate,
    this.onDispose,
    this.onDeactivate,
    this.didBuild,
    required this.recognizeReorderDrag,
    required this.recognizeSwipeDrag,
  });

  final int index;
  final NullableIndexedWidgetBuilder builder;
  final BoolGetter reorderableGetter;
  final BoolGetter draggableGetter;

  /// The size of the item while the overlay shows it, or null.
  final Size? Function(Key key) overlayedSizeGetter;
  final GlobalKey childKey;
  final AxisDirectionGetter? swipeToRemoveDirectionGetter;
  final RenderedItemLifecycleCallback? onInit;
  final RenderedItemLifecycleCallback? didUpdate;
  final RenderedItemLifecycleCallback? onDispose;
  final RenderedItemLifecycleCallback? onDeactivate;
  final RenderedItemLifecycleCallback? didBuild;
  final ItemGestureRecognizer recognizeReorderDrag;
  final ItemGestureRecognizer recognizeSwipeDrag;

  @override
  State<ItemWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<ItemWidget> {
  int get index => widget.index;
  Key get key => widget.key!;
  NullableIndexedWidgetBuilder get builder => widget.builder;
  bool get reorderable => widget.reorderableGetter(index);
  bool get draggable => widget.draggableGetter(index);
  Size? get overlayedSize => widget.overlayedSizeGetter(key);
  bool get isOverlayed => overlayedSize != null;
  AxisDirection? get swipeToRemoveDirection =>
      widget.swipeToRemoveDirectionGetter?.call(index);
  bool get swipeable => swipeToRemoveDirection != null;
  Offset? get globalPosition => findRenderBox()?.localToGlobal(Offset.zero);
  Size? get size => findRenderBox()?.size;

  /// The constraints the list lays the item out with.
  BoxConstraints? get constraints {
    final renderBox = findRenderBox();
    return renderBox != null && renderBox.hasSize
        ? renderBox.constraints
        : null;
  }

  @override
  void initState() {
    super.initState();
    widget.onInit?.call(this);
  }

  @override
  void didUpdateWidget(covariant ItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      widget.didUpdate?.call(this);
    }
  }

  @override
  void dispose() {
    widget.onDispose?.call(this);
    super.dispose();
  }

  @override
  void deactivate() {
    widget.onDeactivate?.call(this);
    super.deactivate();
  }

  void rebuild() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    addPostFrame(() => widget.didBuild?.call(this));

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
      widget.recognizeSwipeDrag(this, event);

  void _recognizeDrag(PointerDownEvent event) =>
      widget.recognizeReorderDrag(this, event);
}
