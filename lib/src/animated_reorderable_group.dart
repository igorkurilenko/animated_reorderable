import 'package:flutter/widgets.dart';

import 'controller/reorderable_group.dart';
import 'options.dart';
import 'util/geometry.dart';
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
/// An item that goes to a list with another look flies to it, as [flight]
/// says, as a hero_here flight does: from its old look, as it last showed,
/// to its new list's look.
///
/// The group shows the dragged item in a layer above its child, so it can
/// go over all the lists. The item is built under the group's ancestors
/// then, not the list's. Let go, it lands there too, and once the list it
/// lands in scrolls it, it goes out of sight at the list's edges, as the
/// list's items do.
///
/// The keys of the items, as each list's `keyGetter` gives them, must be
/// unique across the group's lists. The lists must not overlap.
final class AnimatedReorderableGroup extends StatefulWidget {
  const AnimatedReorderableGroup({
    super.key,
    required this.onMove,
    this.canMove,
    this.flight = const FlightOptions(),
    this.moveToListLabel,
    required this.child,
  });

  /// Called when a dragged item goes from one list of the group to another.
  final ItemMoveCallback onMove;

  /// Whether a dragged item may go from one list to another. It may by
  /// default. Asked once each time the item is dragged over a list, and as
  /// the lists work out the moves screen readers can make.
  final ItemMovePredicate? canMove;

  /// How an item flies from one list's look to another's.
  final FlightOptions flight;

  /// The label of the move a screen reader can make with an item to the
  /// list with the id it's given, as [ReorderOptions.groupId] gives it, in
  /// the app's language: "Move to Done", say.
  ///
  /// With it, each item that can be dragged and reordered can move to each
  /// other list of the group that the app lets it go to, in the order of
  /// the tree. It goes to the same index there, or to the end of a shorter
  /// list, and flies there as a drag that lets it go there does. Without
  /// it, screen readers move items only within their lists.
  final String Function(Object list)? moveToListLabel;

  /// The lists, and whatever is around them.
  final Widget child;

  @override
  State<AnimatedReorderableGroup> createState() =>
      _AnimatedReorderableGroupState();
}

class _AnimatedReorderableGroupState extends State<AnimatedReorderableGroup> {
  late final group = ReorderableGroup(options: () => widget);

  /// The position of a view around the group that scrolls it, and how far
  /// it had scrolled.
  ScrollPosition? _scroll;
  double? _pixels;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll == _scroll) return;
    _scroll?.removeListener(_didScroll);
    _scroll = scroll?..addListener(_didScroll);
    _pixels = scroll != null && scroll.hasPixels ? scroll.pixels : null;
  }

  /// The group's layer moves with the view, so the items held in it move
  /// back by as much, and stay under the pointer.
  void _didScroll() {
    final scroll = _scroll!;
    final pixels = scroll.pixels;
    final delta = pixels - (_pixels ?? pixels);
    _pixels = pixels;
    if (delta == 0) return;
    group.shiftHeldItems(scroll.axisDirection.offsetOf(delta));
  }

  @override
  void dispose() {
    _scroll?.removeListener(_didScroll);
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
          shuttleBuilder: group.flightOptions.shuttleBuilder,
          listBounds: () => group.listBoundsOf(item),
          listClipBehavior: group.hostOf(item)?.clipBehavior ?? Clip.hardEdge,
        ),
    ],
  );
}
