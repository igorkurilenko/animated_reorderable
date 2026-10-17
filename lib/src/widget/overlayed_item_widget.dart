import 'package:flutter/widgets.dart';

import '../model/model.dart';
import 'size_reporter.dart';

typedef OverlayedItemSizeCallback = void Function(
  Size size,
  OverlayedItem item,
);
typedef OverlayedItemPointerDownCallback = void Function(
  PointerDownEvent event,
  OverlayedItem item,
  BuildContext context,
);

class OverlayedItemWidget extends StatelessWidget {
  const OverlayedItemWidget({
    super.key,
    required this.item,
    this.onPointerDown,
    this.onSizeChange,
  });

  final OverlayedItem item;

  /// Lets a pointer down on the item start a drag or a swipe of it.
  final OverlayedItemPointerDownCallback? onPointerDown;
  final OverlayedItemSizeCallback? onSizeChange;

  /// It builds again when its item changes, without the other items.
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: item, builder: _build);

  Widget _build(BuildContext context, Widget? child) => Positioned(
    left: item.position.dx,
    top: item.position.dy,
    child: IgnorePointer(
      ignoring: !item.interactive,
      child: Listener(
        onPointerDown: (event) => onPointerDown?.call(event, item, context),
        child: ConstrainedBox(
          constraints: item.constraints,
          child: item.build(
            context,
            wrap: (item) => SizeReporter(
              onSizeChange: (size) => onSizeChange?.call(size, this.item),
              child: item,
            ),
          ),
        ),
      ),
    ),
  );
}
