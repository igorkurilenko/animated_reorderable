/// A reorderable list and grid for Flutter: drag and drop to reorder the
/// items of a [ListView] or a [GridView], or to move them between lists,
/// swipe to delete, and animate each insert, remove and move.
///
/// Flutter's
/// [ReorderableListView](https://api.flutter.dev/flutter/material/ReorderableListView-class.html)
/// reorders a list, but animates no insert or remove, and has no grid. Its
/// [AnimatedList] and [AnimatedGrid] animate inserts and removals, but can't
/// reorder. [AnimatedReorderable] wraps the [ListView] or [GridView] you have
/// and does both:
///
/// - Drag and drop to reorder a list or a grid, with auto-scroll at its
///   edges, and items that can't be dragged or that stay in place, with
///   [ReorderOptions].
/// - Drag and drop items between lists and grids under an
///   [AnimatedReorderableGroup], as between the columns of a kanban board,
///   and fly an item from one list's look to another's.
/// - Animate inserts, removals and moves with
///   [AnimatedReorderableState.insertItem],
///   [AnimatedReorderableState.removeItem] and
///   [AnimatedReorderableState.reorderItem], as [AnimatedList] animates
///   inserts and removals.
/// - Swipe to delete, with [SwipeToRemoveOptions].
/// - Moves for screen readers: to the start, one place back or forward, and
///   to the end, a row back or forward in a grid, and to another list of a
///   group.
///
/// Wrap a [ListView] in [AnimatedReorderable.list], give each item a key, and
/// apply each reorder to your items:
///
/// ```dart
/// import 'package:animated_reorderable/animated_reorderable.dart';
/// import 'package:flutter/material.dart';
///
/// void main() {
///   runApp(const Example());
/// }
///
/// class Example extends MaterialApp {
///   const Example({super.key})
///       : super(
///           home: const Scaffold(
///             body: ListViewExample(),
///           ),
///         );
/// }
///
/// class ListViewExample extends StatefulWidget {
///   const ListViewExample({super.key});
///
///   @override
///   State<ListViewExample> createState() => _ListViewExampleState();
/// }
///
/// class _ListViewExampleState extends State<ListViewExample> {
///   final items = [1, 2, 3, 4, 5];
///
///   @override
///   Widget build(BuildContext context) {
///     return AnimatedReorderable.list(
///       keyGetter: (index) => ValueKey(items[index]),
///       reorder: ReorderOptions(
///         onReorder: (moves) => moves.apply(items),
///       ),
///       listView: ListView.builder(
///         itemCount: items.length,
///         itemBuilder: (context, index) =>
///             ListTile(title: Text('Item: ${items[index]}')),
///       ),
///     );
///   }
/// }
/// ```
library;

export 'src/animated_reorderable.dart';
export 'src/animated_reorderable_group.dart'
    show
        AnimatedReorderableGroup,
        ItemMoveCallback,
        ItemMovePredicate,
        ItemPlace;
export 'src/model/model.dart' show AnimatedItemDecorator;
export 'src/model/item_moves.dart';
export 'src/options.dart';
