import 'package:flutter/widgets.dart';

import '../model/model.dart';

class ActiveItemWidget extends StatefulWidget {
  const ActiveItemWidget({
    super.key,
    required this.item,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onSwipeStart,
    this.onSwipeUpdate,
    this.onSwipeEnd,
  });

  final ActiveItem item;
  final ActiveItemCallback? onDragStart;
  final ActiveItemCallback? onDragUpdate;
  final ActiveItemCallback? onDragEnd;
  final ActiveItemCallback? onSwipeStart;
  final ActiveItemCallback? onSwipeUpdate;
  final ActiveItemCallback? onSwipeEnd;

  @override
  State<ActiveItemWidget> createState() => _ActiveItemWidgetState();
}

class _ActiveItemWidgetState extends State<ActiveItemWidget> {
  ActiveItem get item => widget.item;

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
        left: item.geometry.left,
        top: item.geometry.top,
        child: IgnorePointer(
          ignoring: !item.interactive,
          child: Listener(
            onPointerDown: _handlePointerDown,
            child: SizedBox(
              width: item.geometry.width,
              height: item.geometry.height,
              child: item.build(context),
            ),
          ),
        ),
      );

  void _handlePointerDown(PointerDownEvent event) => item.swiped
      ? item.recognizeSwipe(
          event,
          context: context,
          swipeDirection: item.swipeDirection!,
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
