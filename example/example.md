<h1 align="center">Flutter reorderable list example</h1>

<p align="center">This Flutter reorderable list example is the card sample from the docs of Flutter's ReorderableListView, animated:<sup>1</sup> drag and drop a card to reorder the list, swipe it away to delete it, or tap + to insert one. The other cards slide out of its way, and close the gap it leaves, as in an animated list.</p>

<p align="center">
  <a href="#take-a-closer-look">See the code ›</a>&emsp;<a href="https://pub.dev/packages/animated_reorderable/install">Install animated_reorderable ›</a>
</p>

<p align="center">
  <img src="https://github.com/igorkurilenko/animated_reorderable/blob/main/assets/animated_reorderable_list.webp?raw=true"
    alt="Flutter reorderable list example: + inserts a card, a long press drags it down the list, and a swipe deletes it" width="300"/>
</p>

## Get the highlights.

- **Drag and drop.** A long press lifts a card, as in Flutter's sample, and the reorder animation slides the cards it passes in the list out of its way.
- **Swipe to delete.** A swipe flies the card off the screen, and the cards below close the gap.
- **Insert and remove animations.** + inserts a card at the top: the cards below slide down, and it fades in.
- **Your own ListView.** `AnimatedReorderable.list` makes the `ListView.builder` you have a reorderable, animated list, with a key for each item.

## Take a closer look.

Three steps, all in one `build` method:

1. **The wrapper.** `AnimatedReorderable.list` wraps the `ListView.builder`, and `keyGetter` gives each card a key.
2. **The gestures.** `ReorderOptions.onReorder` puts the cards in their new order as a drag goes, and `SwipeToRemoveOptions.onSwipeToRemove` deletes a swiped card from the items and from the list, with `removeItem`.
3. **The insert.** A tap on + inserts a card into the items and into the list, with `insertItem`, and it fades in as the cards below slide down.

```dart
import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/material.dart';

import 'item_card.dart';

void main() => runApp(
  const MaterialApp(
    title: 'AnimatedReorderable Example',
    debugShowCheckedModeBanner: false,
    home: ReorderableListExample(),
  ),
);

/// Flutter's ReorderableListView sample of cards, animated: a long press
/// drags a card to a new place, a swipe deletes it, and + inserts one:
///
/// 1. [AnimatedReorderable.list] wraps the [ListView], with a key for each
///    card.
/// 2. [ReorderOptions.onReorder] puts the cards in their new order as a drag
///    goes, and [SwipeToRemoveOptions.onSwipeToRemove] deletes a swiped card,
///    from the items and from the list.
/// 3. A tap on + inserts a card, which fades in as the others slide down.
class ReorderableListExample extends StatefulWidget {
  const ReorderableListExample({super.key});

  @override
  State<ReorderableListExample> createState() => _ReorderableListExampleState();
}

class _ReorderableListExampleState extends State<ReorderableListExample> {
  final _listKey = GlobalKey<AnimatedReorderableState>();
  final _items = List<int>.generate(50, (index) => index);
  var _next = 50;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Animated reorderable list')),
    floatingActionButton: FloatingActionButton(
      // 3. A tap inserts a card at the top.
      onPressed: () {
        _items.insert(0, _next++);
        _listKey.currentState!.insertItem(0);
      },
      shape: const CircleBorder(),
      backgroundColor: const Color(0xFFCC0120),
      foregroundColor: Colors.white,
      child: const Icon(Icons.add),
    ),
    // 1. The list, wrapped.
    body: AnimatedReorderable.list(
      key: _listKey,
      keyGetter: (index) => ValueKey(_items[index]),
      // 2. A long press drags a card, and the cards follow it.
      reorder: ReorderOptions(
        onReorder: (permutations) => permutations.apply(_items),
        decoration: const ItemDecoration(decorator: liftCard),
      ),
      // 2. A swipe deletes the card.
      swipeToRemove: SwipeToRemoveOptions(
        onSwipeToRemove: (index) {
          final item = _items.removeAt(index);
          _listKey.currentState!.removeItem(
            index,
            (context, animation) =>
                FadeTransition(opacity: animation, child: ItemCard(item)),
          );
        },
      ),
      // It fades in once the cards below have made room.
      insertTransition: (child, index, animation) => FadeTransition(
        opacity: animation.drive(CurveTween(curve: const Interval(.5, 1))),
        child: child,
      ),
      listView: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        itemCount: _items.length,
        itemBuilder: (context, index) => ItemCard(_items[index]),
      ),
    ),
  );
}
```

## More ways to use animated_reorderable.

Two more Flutter examples, each a pattern apps often need, and each recorded as it runs.<sup>2</sup> They're code to learn from and copy, not widgets to import. Run one from the repository's [example folder](https://github.com/igorkurilenko/animated_reorderable/tree/main/example/lib), such as with `flutter run -t lib/kanban/main.dart`. In each, `main.dart` builds the package's widgets, and a file beside it draws the rest.

### Reorderable GridView

A reorderable grid of shortcuts: long press a tile, and drag and drop it anywhere in the grid, and the other tiles slide from cell to cell, across the rows, to make room. Add shortcut inserts a tile at the start, and every tile after it slides along a cell; a swipe removes a tile, and they slide back. `AnimatedReorderable.grid` wraps the `GridView.builder`, as the list example wraps its `ListView`. [See the reorderable grid code ›](https://github.com/igorkurilenko/animated_reorderable/tree/main/example/lib/reorderable_grid)

<p align="center">
  <img src="https://github.com/igorkurilenko/animated_reorderable/blob/main/assets/animated_reorderable_grid.webp?raw=true"
    alt="Reorderable GridView in Flutter: a tile is added, dragged three rows down across the grid, and swiped away" width="240"/>
</p>

### Kanban board: drag and drop between lists

A Flutter kanban board, as on GitHub: drag and drop a task between the columns, To do, In progress and Done, and the tasks of each column move out of its way. Each column is an `AnimatedReorderable.list`, and an `AnimatedReorderableGroup` around them moves a task's data from one list to another, with `onMove`. As a task goes into Done, it flies from its card to a done card, its title struck through. A mouse drags a card at once, and a finger after a long press. [See the kanban board code ›](https://github.com/igorkurilenko/animated_reorderable/tree/main/example/lib/kanban)

<p align="center">
  <img src="https://github.com/igorkurilenko/animated_reorderable/blob/main/assets/animated_reorderable_kanban.webp?raw=true"
    alt="Flutter kanban board: a task is dragged from To do to In progress, then into Done, where it becomes a done card, and back" width="600"/>
</p>

## Questions? Answers.

<details>
<summary><b>How do I reorder a list in Flutter with drag and drop?</b></summary>

Wrap your `ListView.builder` in `AnimatedReorderable.list`, give each item a key with `keyGetter`, and apply the permutations to your items in `ReorderOptions.onReorder`, as the [example above](#take-a-closer-look) does. Each item is then draggable after a long press, as in a `ReorderableListView`, and the list is sortable with no `setState`: it moves the other items aside itself.

</details>

<details>
<summary><b>How do I reorder a GridView?</b></summary>

Wrap it in `AnimatedReorderable.grid`, with the same options as a list. An item dragged over the others moves them from cell to cell, across the rows, as in the [reorderable grid example](https://github.com/igorkurilenko/animated_reorderable/tree/main/example/lib/reorderable_grid). Flutter's own `ReorderableListView` has no grid version.

</details>

<details>
<summary><b>How do I drag and drop items between lists?</b></summary>

Put the lists, or grids, under an `AnimatedReorderableGroup`, and give each a `ReorderOptions.groupId`. The group's `onMove` moves an item's data from one list to another as the item is dragged there, as in the [kanban board example](https://github.com/igorkurilenko/animated_reorderable/tree/main/example/lib/kanban). An item goes from a list to a grid too, and flies from one look to the other.

</details>

<details>
<summary><b>How do I animate inserting and removing items, as in an AnimatedList?</b></summary>

As with an `AnimatedList`: insert an item into your data and call `insertItem` with its index, or remove one from your data and call `removeItem`, on the list's state, which a `GlobalKey<AnimatedReorderableState>` gets. The insert or remove animation slides the other items to their new places, in a list or a grid.

</details>

<details>
<summary><b>How do I swipe to delete an item?</b></summary>

Give `SwipeToRemoveOptions` an `onSwipeToRemove` callback that removes the item from your data and calls `removeItem`, as the example above does. The item flies off, and the others close the gap, with no `Dismissible`.

</details>

<details>
<summary><b>Can screen readers reorder the items?</b></summary>

Yes. Each item that can be dragged gets the moves of a `ReorderableListView`'s items: to the start, one place up or down, and to the end, and in a grid a row up or down. Under an `AnimatedReorderableGroup` with a `moveToListLabel`, it also gets a move to each other list.

</details>

<p><small>1. The cards are those of the card sample in the docs of Flutter's ReorderableListView, in the flutter/flutter repository, under its BSD license, here in two grays.<br>
2. Recorded from the examples frame by frame, at 60 fps: the list and the grid in an iPhone 15 frame, and the kanban board on a wide screen, with a mouse.</small></p>
