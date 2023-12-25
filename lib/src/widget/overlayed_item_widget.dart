import 'package:flutter/widgets.dart';

import '../model/model.dart';

class OverlayedItemWidget extends StatefulWidget {
  const OverlayedItemWidget({
    super.key,
    required this.item,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onSwipeStart,
    this.onSwipeUpdate,
    this.onSwipeEnd,
  });

  final OverlayedItem item;
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
        left: item.position.dx,
        top: item.position.dy,
        child: IgnorePointer(
          ignoring: !item.interactive,
          child: Listener(
            onPointerDown: _handlePointerDown,
            child: ConstrainedBox(
              constraints: item.constraints,
              child: item.build(context),
            ),
          ),
        ),
      );

  void _handlePointerDown(PointerDownEvent event) => item.swiped
      ? item.recognizeSwipe(
          event,
          context: context,
          swipeDirection: item.swipeToRemoveDirection!,
          onSwipeStart: widget.onSwipeStart,
          onSwipeUpdate: widget.onSwipeUpdate,
          onSwipeEnd: widget.onSwipeEnd,
        )
      : item.recognizeDrag(
          event,
          context: context,
          onDragStart: widget.onDragStart,
          onDragUpdate: widget.onDragUpdate,
          onDragEnd: widget.onDragEnd,
        );
}
