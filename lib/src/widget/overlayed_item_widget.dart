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
typedef ItemEntranceBuilder = Widget Function(
  Widget child,
  int index,
  Animation<double> entrance,
);

class OverlayedItemWidget extends StatelessWidget {
  const OverlayedItemWidget({
    super.key,
    required this.item,
    this.onPointerDown,
    this.onSizeChange,
    this.entranceBuilder,
  });

  final OverlayedItem item;

  /// Lets a pointer down on the item start a drag or a swipe of it.
  final OverlayedItemPointerDownCallback? onPointerDown;
  final OverlayedItemSizeCallback? onSizeChange;

  /// Puts the item in the transition it enters with, as the list does.
  final ItemEntranceBuilder? entranceBuilder;

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
            wrap: (child) => SizeReporter(
              onSizeChange: (size) => onSizeChange?.call(size, item),
              child:
                  entranceBuilder?.call(
                    child,
                    item.index,
                    item.item.entrance,
                  ) ??
                  child,
            ),
          ),
        ),
      ),
    ),
  );
}
