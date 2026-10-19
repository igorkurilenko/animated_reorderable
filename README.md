A convenient wrapper that makes `ListView` or `GridView` animated and reorderable.

<p>
  <img src="https://github.com/igorkurilenko/animated_reorderable/blob/main/assets/animated_reorderable_list.gif?raw=true"
    alt="An animated image of the animated and reorderable ListView" width="160"/>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="https://github.com/igorkurilenko/animated_reorderable/blob/main/assets/animated_reorderable_grid.gif?raw=true"
   alt="An animated image of the animated and reorderable GridView" width="160"/>
</p>

## Features

The `AnimatedReorderable` wrapper for `ListView` and `GridView` incorporates all the features present in standard `AnimatedList`, `AnimatedGrid` and `ReorderableList`, while introducing the following enhancements:

- Introduces the capability to reorder `GridView` items.
- Upgrades `ListView` or `GridView` to be animated and reorderable simultaneously.
- Animates the repositioning of all grid items during addition or removal.
- Enables deletion through a swipe gesture.
- Certain items can be configured as non-reorderable.
- Callbacks for tracking item drag and swipe events.
- Lets screen readers move items, as `ReorderableList` does: to the start, one place back or forward, or to the end.
- Lets items be dragged between lists and grids, as between the columns of a board, and flies an item from one list's look to another's.
- In addition to programmatically initiating animated additions and removals, reordering can also be programmatically triggered.

## Usage

Utilize `AnimatedReorderable.list()` or `AnimatedReorderable.grid()` to wrap `ListView` or `GridView` accordingly. Configure the following parameters:

- **keyGetter:** Required parameter to configure keys for uniquely identifying the items.
- **reorder:** To let users reorder the items, give `ReorderOptions` an `onReorder` callback in which you apply the permutations to your items. It also takes the decoration of dragged items and drag callbacks. After a reorder, an insert or a remove, the package builds again only the items it moves; an item that keeps its index keeps what it shows. If something else about your items changes, build the view again as usual, such as with `setState`.
- **swipeToRemove:** To let users swipe items away, give `SwipeToRemoveOptions` an `onSwipeToRemove` callback in which you remove the item.
- **motion:** `MotionOptions` sets how items move to their new places.
- **insertTransition:** The transition items enter with, like the animation `AnimatedList` passes to its item builder. Insert an item with `insertItem(index)`, and it enters through the transition. Every item is built through it, so an item keeps its state when it has entered.

In 1.x these settings were parameters of their own, such as `onReorder` and `onSwipeToRemove`, and `insertItem` took a builder for the inserted item. 2.0 removed them: the [changelog](CHANGELOG.md) says what replaces each one.

Here's an example of how to wrap a `ListView`:

```dart
import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(
    home: Scaffold(
      body: ListViewExample(),
    ),
  ));
}

class ListViewExample extends StatefulWidget {
  const ListViewExample({super.key});

  @override
  State<ListViewExample> createState() => _ListViewExampleState();
}

class _ListViewExampleState extends State<ListViewExample> {
  final items = [1, 2, 3, 4, 5];

  @override
  Widget build(BuildContext context) => AnimatedReorderable.list(
        // Configure the keyGetter using a function that
        // takes the index of the item and must return its unique key.
        keyGetter: (index) => ValueKey(items[index]),

        // Define the onReorder callback to synchronize the order
        // of items. The callback takes permutations that need to be
        // applied to the collection of items.
        reorder: ReorderOptions(
          onReorder: (permutations) => permutations.apply(items),
        ),

        listView: ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Item: ${items[index]}'),
            ),
          ),
        ),
      );
}
```

`AnimatedReorderableState` can be used to dynamically insert, remove or reorder items. To refer to the `AnimatedReorderableState` either provide a GlobalKey or use the static `of` method from an item's input callback. There are showcases on the [Example](https://pub.dev/packages/animated_reorderable/example) page.

## Dragging between lists

Put lists and grids under an `AnimatedReorderableGroup`, and give each a `ReorderOptions.groupId`. An item dragged over another of them goes into it: the group's `onMove` moves the item's data, and the items of both lists move in place, out of its way and into its old place. Let go, the item lands there.

```dart
AnimatedReorderableGroup(
  onMove: (from, to) {
    final task = board[from.list]!.removeAt(from.index);
    board[to.list]!.insert(to.index, task);
  },
  child: Row(
    children: [
      for (final id in board.keys)
        Expanded(
          child: AnimatedReorderable.list(
            keyGetter: (index) => ValueKey(board[id]![index].id),
            reorder: ReorderOptions(
              groupId: id,
              onReorder: (permutations) => permutations.apply(board[id]!),
            ),
            listView: ListView.builder(
              itemCount: board[id]!.length,
              itemBuilder: (context, index) => TaskCard(board[id]![index]),
            ),
          ),
        ),
    ],
  ),
)
```

- **canMove:** Refuses a move before any data changes, such as into a full column.
- **flight:** When the lists build their items differently, such as cards in a list and thumbnails in a grid, an item flies from one look to the other as it goes over, as a [hero_here](https://pub.dev/packages/hero_here) flight does. `FlightOptions` sets the flight's duration, curve and shuttle builder, and `FlightOptions.none` turns flights off.
- **Boards that scroll:** A view around the lists that scrolls across them, such as a board that scrolls sideways, scrolls while an item is held at its edge.
- The items' keys must be unique across the group's lists.

The example's board, `example/lib/animated_reorderable_board/animated_reorderable_board.0.dart`, is a kanban board, as on GitHub. A mouse drags its cards at once, with an `ImmediateMultiDragGestureRecognizer` from `ReorderOptions.gestureRecognizerFactory`, and a finger after a long press. A task flies from its card to a done card, its title struck through, as it goes into Done.
