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

  /// It builds again when its item changes, without the other items, and
  /// lays out again as its item moves.
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: item, builder: _build);

  Widget _build(BuildContext context, Widget? child) => Positioned.fill(
    child: CustomSingleChildLayout(
      delegate: _AtItemPosition(item),
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
    ),
  );
}

/// Places an item where it is in the overlay, and again as it moves.
class _AtItemPosition extends SingleChildLayoutDelegate {
  _AtItemPosition(this.item) : super(relayout: item.positionChanges);

  final OverlayedItem item;

  /// As a stack lays out a child positioned by its top left corner.
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      const BoxConstraints();

  @override
  Offset getPositionForChild(Size size, Size childSize) => item.position;

  @override
  bool shouldRelayout(_AtItemPosition oldDelegate) => oldDelegate.item != item;
}
