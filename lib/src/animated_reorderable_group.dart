import 'package:flutter/widgets.dart';

import 'controller/reorderable_group.dart';
import 'widget/overlayed_item_widget.dart';

/// Where an item is in a group of lists: the id of its list, as
/// [ReorderOptions.groupId] gives it, and the item's index there.
typedef ItemPlace = ({Object list, int index});

/// Called when a dragged item goes from one list of a group to another.
///
/// Move the item's data from [from] to [to]. The lists show the item at
/// [to] from then on:
///
/// ```dart
/// onMove: (from, to) {
///   final card = board[from.list]!.removeAt(from.index);
///   board[to.list]!.insert(to.index, card);
/// },
/// ```
typedef ItemMoveCallback = void Function(ItemPlace from, ItemPlace to);

/// Whether a dragged item may go from [from] to [to].
typedef ItemMovePredicate = bool Function(ItemPlace from, ItemPlace to);

/// Lets items be dragged between the [AnimatedReorderable]s under it, as
/// between the columns of a board.
///
/// Give each list a [ReorderOptions.groupId] and an
/// [ReorderOptions.onReorder]. An item dragged over another of the lists
/// goes into it, where [onMove] moves its data, and lands there when let
/// go. An item dragged over no list stays in the last one it was over.
///
/// The group shows the dragged item in a layer above its child, so it can
/// go over all the lists. The item is built under the group's ancestors
/// then, not the list's.
///
/// The keys of the items, as each list's `keyGetter` gives them, must be
/// unique across the group's lists. The lists must not overlap.
final class AnimatedReorderableGroup extends StatefulWidget {
  const AnimatedReorderableGroup({
    super.key,
    required this.onMove,
    this.canMove,
    required this.child,
  });

  /// Called when a dragged item goes from one list of the group to another.
  final ItemMoveCallback onMove;

  /// Whether a dragged item may go from one list to another. It may by
  /// default. Asked once each time the item is dragged over a list.
  final ItemMovePredicate? canMove;

  /// The lists, and whatever is around them.
  final Widget child;

  @override
  State<AnimatedReorderableGroup> createState() =>
      _AnimatedReorderableGroupState();
}

class _AnimatedReorderableGroupState extends State<AnimatedReorderableGroup> {
  late final group = ReorderableGroup(options: () => widget);

  @override
  void dispose() {
    group.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GroupScope(
    group: group,
    child: Stack(
      // The lists lay out as they would without the group.
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(child: _GroupLayer(group: group)),
      ],
    ),
  );
}

/// Gives the lists under a group their group.
class GroupScope extends InheritedWidget {
  const GroupScope({super.key, required this.group, required super.child});

  final ReorderableGroup group;

  static ReorderableGroup? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GroupScope>()?.group;

  @override
  bool updateShouldNotify(GroupScope oldWidget) => group != oldWidget.group;
}

/// Shows the items held in the group's lists above them all.
class _GroupLayer extends StatefulWidget {
  const _GroupLayer({required this.group});

  final ReorderableGroup group;

  @override
  State<_GroupLayer> createState() => _GroupLayerState();
}

class _GroupLayerState extends State<_GroupLayer> {
  ReorderableGroup get group => widget.group;

  @override
  void initState() {
    super.initState();
    group
      ..attachLayer(() => context.findRenderObject() as RenderBox?)
      ..hostedChanges.addListener(_rebuild);
  }

  @override
  void dispose() {
    group
      ..hostedChanges.removeListener(_rebuild)
      ..detachLayer();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      // Each through the list it is held in, which changes as it goes to
      // another.
      for (final item in group.hostedItems)
        OverlayedItemWidget(
          key: ObjectKey(item),
          item: item,
          onPointerDown: (event, item, context) =>
              group.hostOf(item)?.recognizeOverlayedItem(event, item, context),
          onSizeChange: (size, item) =>
              group.hostOf(item)?.handleOverlayedItemSizeChange(size, item),
          entranceBuilder: (child, index, entrance) =>
              group.hostOf(item)?.buildEntrance(child, index, entrance) ??
              child,
        ),
    ],
  );
}
