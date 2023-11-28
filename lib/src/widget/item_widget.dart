import 'package:flutter/widgets.dart';

import '../../animated_reorderable.dart';
import '../util/misc.dart';

typedef RenderedItem = _ItemWidgetState;
typedef RenderedItemLifecycleCallback = void Function(RenderedItem item);
typedef ItemGestureRecognizer = void Function(
    BuildContext context, PointerDownEvent event);

class ItemWidget extends StatefulWidget {
  const ItemWidget({
    super.key,
    required this.index,
    required this.id,
    required this.reorderableGetter,
    required this.draggableGetter,
    required this.overlayedGetter,
    required this.swipeAwayDirectionGetter,
    required this.builder,
    this.onInit,
    this.didUpdate,
    this.onDispose,
    this.onDeactivate,
    this.didBuild,
    required this.recognizeDrag,
    required this.recognizeSwipe,
  });

  final int index;
  final int id;
  final NullableIndexedWidgetBuilder builder;
  final ReorderableGetter reorderableGetter;
  final DraggableGetter draggableGetter;
  final bool Function(int id) overlayedGetter;
  final SwipeAwayDirectionGetter? swipeAwayDirectionGetter;
  final RenderedItemLifecycleCallback? onInit;
  final RenderedItemLifecycleCallback? didUpdate;
  final RenderedItemLifecycleCallback? onDispose;
  final RenderedItemLifecycleCallback? onDeactivate;
  final RenderedItemLifecycleCallback? didBuild;
  final ItemGestureRecognizer recognizeDrag;
  final ItemGestureRecognizer recognizeSwipe;

  @override
  State<ItemWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<ItemWidget> {
  int get index => widget.index;
  int get id => widget.id;
  NullableIndexedWidgetBuilder get builder => widget.builder;
  bool get reorderable => widget.reorderableGetter(index);
  bool get draggable => widget.draggableGetter(index);
  bool get overlayed => widget.overlayedGetter(id);
  bool get swipeable => widget.swipeAwayDirectionGetter?.call(index) != null;
  Offset get globalPosition => findRenderBox()!.localToGlobal(Offset.zero);
  Size get size => findRenderBox()!.size;

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
    if (widget.didBuild != null) {
      addPostFrame(() => widget.didBuild!.call(this));
    }

    return Opacity(
      opacity: overlayed ? 0 : 1,
      child: Listener(
        onPointerDown: swipeable && !overlayed ? _recognizeSwipe : null,
        child: Listener(
          onPointerDown: draggable && !overlayed ? _recognizeDrag : null,
          child: widget.builder(context, index),
        ),
      ),
    );
  }

  void _recognizeSwipe(PointerDownEvent event) =>
      widget.recognizeSwipe(context, event);

  void _recognizeDrag(PointerDownEvent event) =>
      widget.recognizeDrag(context, event);
}
