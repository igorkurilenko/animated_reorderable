import 'package:flutter/widgets.dart';

import '../../animated_reorderable.dart';
import '../model/model.dart';
import '../util/misc.dart';

typedef RenderedItem = _IdleItemWidgetState;
typedef RenderedItemLifecycleCallback = void Function(RenderedItem item);

class IdleItemWidget extends StatefulWidget {
  const IdleItemWidget({
    super.key,
    required this.index,
    required this.item,
    required this.controller,
    required this.reorderGestureRecognizerFactory,
    required this.swipeAwayGestureRecognizerFactory,
    this.onInit,
    this.didUpdate,
    this.onDispose,
    this.onDeactivate,
    this.didBuild,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onSwipeStart,
    this.onSwipeUpdate,
    this.onSwipeEnd,
  });

  final int index;
  final IdleItem item;
  final AnimatedReorderableController controller;
  final RenderedItemLifecycleCallback? onInit;
  final RenderedItemLifecycleCallback? didUpdate;
  final RenderedItemLifecycleCallback? onDispose;
  final RenderedItemLifecycleCallback? onDeactivate;
  final RenderedItemLifecycleCallback? didBuild;
  final OverlayedItemCallback? onDragStart;
  final OverlayedItemCallback? onDragUpdate;
  final OverlayedItemCallback? onDragEnd;
  final OverlayedItemCallback? onSwipeStart;
  final OverlayedItemCallback? onSwipeUpdate;
  final OverlayedItemCallback? onSwipeEnd;
  final RecognizerFactory reorderGestureRecognizerFactory;
  final RecognizerFactory swipeAwayGestureRecognizerFactory;

  @override
  State<IdleItemWidget> createState() => _IdleItemWidgetState();
}

class _IdleItemWidgetState extends State<IdleItemWidget> {
  int get index => widget.index;
  int get id => item.id;
  IdleItem get item => widget.item;
  AnimatedReorderableController get controller => widget.controller;
  Offset get location => findRenderBox()!.localToGlobal(Offset.zero);
  Size get size => findRenderBox()!.size;

  @override
  void initState() {
    super.initState();
    widget.onInit?.call(this);
  }

  @override
  void didUpdateWidget(covariant IdleItemWidget oldWidget) {
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
      opacity: item.overlayed ? 0 : 1,
      child: Listener(
        onPointerDown: item.swipeable ? _startSwipe : null,
        child: Listener(
          onPointerDown: item.draggable ? _startDrag : null,
          child: item.builder.build(context, widget.index),
        ),
      ),
    );
  }

  void _startSwipe(PointerDownEvent event) {
    if (item.overlayed) return;

    OverlayedItem(
      index: index,
      id: item.id,
      location: location,
      size: size,
      draggable: true,
      reorderable: false,
      builder: ItemBuilder.adaptOtherItemBuilder(item),
      recognizerFactory: widget.swipeAwayGestureRecognizerFactory,
    ).startSwipe(
      event,
      context: context,
      swipeDirection: item.swipeDirection!,
      onSwipeStart: widget.onSwipeStart,
      onSwipeUpdate: widget.onSwipeUpdate,
      onSwipeEnd: widget.onSwipeEnd,
    );
  }

  void _startDrag(PointerDownEvent event) {
    if (item.overlayed) return;

    OverlayedItem(
      index: index,
      id: item.id,
      location: location,
      size: size,
      draggable: true,
      reorderable: item.reorderable,
      builder: ItemBuilder.adaptOtherItemBuilder(item),
      recognizerFactory: widget.reorderGestureRecognizerFactory,
    ).startDrag(
      event,
      context: context,
      onDragStart: (item) {
        item.recognizerFactory = createImmediateGestureRecognizer;
        widget.onDragStart?.call(item);
      },
      onDragUpdate: widget.onDragUpdate,
      onDragEnd: widget.onDragEnd,
    );
  }
}
