import 'package:flutter/widgets.dart';

import '../model/model.dart';

class OverlayedItemWidget extends StatefulWidget {
  const OverlayedItemWidget({
    super.key,
    required this.item,
    this.offset = Offset.zero,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onSwipeStart,
    this.onSwipeUpdate,
    this.onSwipeEnd,
  });

  final OverlayedItem item;
  final Offset offset;
  final OverlayedItemCallback? onDragStart;
  final OverlayedItemCallback? onDragUpdate;
  final OverlayedItemCallback? onDragEnd;
  final OverlayedItemCallback? onSwipeStart;
  final OverlayedItemCallback? onSwipeUpdate;
  final OverlayedItemCallback? onSwipeEnd;

  @override
  State<OverlayedItemWidget> createState() => _OverlayedItemWidgetState();
}

class _OverlayedItemWidgetState extends State<OverlayedItemWidget> {
  OverlayedItem get item => widget.item;
  Offset get offset => widget.offset;

  @override
  void initState() {
    super.initState();
    item.addListener(rebuild);
  }

  @override
  void dispose() {
    item.removeListener(rebuild);
    super.dispose();
  }

  void rebuild() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Positioned(
        left: item.geometry.left + offset.dx,
        top: item.geometry.top + offset.dy,
        child: Listener(
          onPointerDown: item.draggable ? _handlePointerDown : null,
          child: SizedBox(
            width: item.geometry.width,
            height: item.geometry.height,
            child: item.build(context),
          ),
        ),
      );

  void _handlePointerDown(PointerDownEvent event) => item.swiped
      ? item.startSwipe(
          event,
          context: context,
          swipeDirection: item.swipeDirection!,
          onSwipeStart: widget.onSwipeStart,
          onSwipeUpdate: widget.onSwipeUpdate,
          onSwipeEnd: widget.onSwipeEnd,
        )
      : item.startDrag(
          event,
          context: context,
          onDragStart: widget.onDragStart,
          onDragUpdate: widget.onDragUpdate,
          onDragEnd: widget.onDragEnd,
        );
}
