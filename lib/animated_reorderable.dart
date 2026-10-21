/// A Flutter library that provides animating, reordering, and swiping capabilities
/// for both [ListView] and [GridView]. This library enhances the user experience
/// by allowing seamless and visually appealing interactions with list or grid items.
///
/// Features:
///
/// - Animates item insertions, removals, and reordering with customizable animations.
/// - Allows users to interactively reorder items with drag-and-drop gestures.
/// - Swipe-to-remove functionality for removing items with animated effects.
/// - Configurable decorators for the dragged and swiped items.
/// - Callbacks for tracking item drag and swipe events.
/// - Lets screen readers move items, as `ReorderableList` does: to the start,
///   one place back or forward, or to the end, and in a grid a row up or
///   down.
/// - Lets items be dragged between lists and grids under an
///   [AnimatedReorderableGroup], as between the columns of a board, and flies
///   an item from one list's look to another's.
///
/// Usage:
///
/// To use this library, import it into your Flutter project and wrap
/// your [ListView] or [GridView] with the [AnimatedReorderable] widget.
///
/// Example:
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
