<h1 align="center">animated_reorderable: Reorderable list and grid for Flutter</h1>

<p align="center">Like Flutter's <code>ReorderableListView</code> and <code>AnimatedList</code> at once, for the <code>ListView</code> or <code>GridView</code> you have.</p>

<p align="center">
  <a href="#quick-start">Get started ›</a>&emsp;<a href="https://pub.dev/packages/animated_reorderable/example">See the examples ›</a>
</p>

animated_reorderable is a Flutter package for a reorderable list or grid: drag and drop to reorder the items of a `ListView` or a `GridView`, or to move them between lists, swipe to delete, and animate each insert, remove and move. Flutter's `ReorderableListView` reorders a list, but animates no insert or remove, and has no grid. Its `AnimatedList` and `AnimatedGrid` animate inserts and removals, but can't reorder. animated_reorderable wraps the `ListView` or `GridView` you have and does both: an animated, sortable list or grid, whose items are draggable after a long press.

## Flutter reorderable list and grid examples

<table>
  <tr>
    <td align="center" valign="top" width="50%">
      <img src="https://github.com/igorkurilenko/animated_reorderable/blob/main/assets/animated_reorderable_list.webp?raw=true"
        alt="Reorderable list in Flutter: + inserts a card, a long press drags it down the list, and a swipe deletes it" width="220"/>
      <p><b>Reorderable list</b></p>
      <p>Flutter's ReorderableListView sample of cards, animated: drag and drop a card to reorder the list, swipe it away to delete it, or tap + to insert one, and the other cards slide out of its way. <a href="https://github.com/igorkurilenko/animated_reorderable/blob/main/example/lib/main.dart">See the code ›</a></p>
    </td>
    <td align="center" valign="top" width="50%">
      <img src="https://github.com/igorkurilenko/animated_reorderable/blob/main/assets/animated_reorderable_grid.webp?raw=true"
        alt="Reorderable GridView in Flutter: a tile is added, dragged three rows down across the grid, and swiped away" width="220"/>
      <p><b>Reorderable grid</b></p>
      <p>A reorderable GridView of shortcuts: drag and drop a tile across the rows, add one, or swipe one away, and the other tiles slide from cell to cell. <a href="https://github.com/igorkurilenko/animated_reorderable/tree/main/example/lib/reorderable_grid">See the code ›</a></p>
    </td>
  </tr>
  <tr>
    <td align="center" valign="top" colspan="2">
      <img src="https://github.com/igorkurilenko/animated_reorderable/blob/main/assets/animated_reorderable_kanban.webp?raw=true"
        alt="Flutter kanban board: a task is dragged from To do to In progress, then into Done, where it becomes a done card, and back" width="460"/>
      <p><b>Kanban board</b></p>
      <p>Drag and drop tasks between the columns of a kanban board, as on GitHub: each column is a list under an AnimatedReorderableGroup, and a task flies to a done card as it goes into Done. A mouse drags a card at once, a finger after a long press. <a href="https://github.com/igorkurilenko/animated_reorderable/tree/main/example/lib/kanban">See the code ›</a></p>
    </td>
  </tr>
</table>

## Get the highlights.

- **Your ListView or GridView.** Wrap the one you have: its builder, padding and scroll physics stay as they are.
- **Drag and drop.** Reorder a list or a grid, with auto-scroll at its edges, and items that can't be dragged or that stay in place.
- **Between lists.** Drag and drop items between lists and grids under an `AnimatedReorderableGroup`, as between the columns of a kanban board.
- **Animated changes.** `insertItem`, `removeItem` and `reorderItem` animate inserts, removals and moves, as `AnimatedList` animates inserts and removals.
- **Swipe to delete.** Built in, in a direction you set for each item.
- **Screen readers.** Moves to the start, one place up or down, and to the end, a row up or down in a grid, and to another list.
- **Every platform.** Android, iOS, web, macOS, Windows and Linux, with no dependencies beyond Flutter.

## Quick start

**1. Install.** Add animated_reorderable to your `pubspec.yaml`:

```yaml
dependencies:
  animated_reorderable: ^2.8.2
```

**2. Wrap your list.** Wrap your `ListView.builder` in `AnimatedReorderable.list`, give each item a key, and apply each reorder to your items. A long press then drags an item to a new place, and the others slide out of its way:

```dart
AnimatedReorderable.list(
  key: listKey, // A GlobalKey<AnimatedReorderableState>, for step 3.
  keyGetter: (index) => ValueKey(items[index]),
  reorder: ReorderOptions(
    onReorder: (permutations) => permutations.apply(items),
  ),
  listView: ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) => ListTile(title: Text(items[index])),
  ),
)
```

**3. Change it, animated.** Change your items, then tell the list, as you'd tell an `AnimatedList`, and the other items slide to their new places:

```dart
items.insert(0, 'New task');
listKey.currentState!.insertItem(0);

final removed = items.removeAt(2);
listKey.currentState!.removeItem(
  2,
  (context, animation) => FadeTransition(
    opacity: animation,
    child: ListTile(title: Text(removed)),
  ),
);
```

A `GridView` goes in `AnimatedReorderable.grid` the same way. The [Example tab](https://pub.dev/packages/animated_reorderable/example) has a whole Flutter reorderable list example, and the repository's [example folder](https://github.com/igorkurilenko/animated_reorderable/tree/main/example/lib) has the [examples above](#flutter-reorderable-list-and-grid-examples).

## animated_reorderable, ReorderableListView, AnimatedList and AnimatedGrid

| | animated_reorderable | `ReorderableListView` | `AnimatedList`, `AnimatedGrid` |
|---|---|---|---|
| Reorder by drag and drop | list and grid | list | no |
| Animated inserts and removals | yes | no | yes |
| Other items slide on an insert or a remove | yes | – | list: with a `SizeTransition`; grid: no |
| Animated reorder in code | yes | no | no |
| Drag between lists and grids | yes, with `AnimatedReorderableGroup` | no | – |
| Swipe to delete | built in | with `Dismissible` | with `Dismissible` |
| Items that can't be dragged | yes | with your own drag listeners | – |
| Items that stay in place | yes | no | – |
| Auto-scroll as you drag | yes | yes | – |
| Screen-reader moves | in lists, grids and between lists | in lists | – |
| Drag handles | no | yes | – |
| Header and footer | no | yes | no |
| Sliver version | no | `SliverReorderableList` | `SliverAnimatedList`, `SliverAnimatedGrid` |
| Items built per drag | only those it passes | the others in sight, every frame | – |
| Items built per removal | only those that move, once | – | all in sight, twice |

- For drag handles, a header or a footer, or a list in a `CustomScrollView`, use `ReorderableListView` or `SliverReorderableList`.
- To only animate inserts and removals, `AnimatedList` and `AnimatedGrid` need no package.

Other packages reorder or animate lists too. By what their READMEs say they do:

- [reorderables](https://pub.dev/packages/reorderables): drag and drop in its own table, row, column, wrap and sliver list.
- [flutter_reorderable_grid_view](https://pub.dev/packages/flutter_reorderable_grid_view): drag and drop in a `GridView`, and animations as its children are added, removed or updated.
- [great_list_view](https://pub.dev/packages/great_list_view): a list view that animates the changes it finds by comparing the items, and reorders them.
- [animated_reorderable_list](https://pub.dev/packages/animated_reorderable_list): list and grid views that animate inserts and removals as the list changes, and reorder by drag and drop.
- [drag_and_drop_lists](https://pub.dev/packages/drag_and_drop_lists): two-level lists, whose items move within and between the lists, and whose lists reorder.
- [appflowy_board](https://pub.dev/packages/appflowy_board): a board of groups, whose cards are dragged between the groups.

animated_reorderable animates the changes you make, with `insertItem`, `removeItem` and `reorderItem`, as `AnimatedList` does, rather than finding them by comparing the items.

## Questions? Answers.

### How do I add drag and drop to reorder a ListView?

Wrap it in `AnimatedReorderable.list`, give each item a key with `keyGetter`, and apply the permutations to your items in `ReorderOptions.onReorder`, as in the [quick start](#quick-start). A long press then drags an item, and the list moves the others aside, with no `setState`.

### Why doesn't ReorderableListView animate inserting and removing items?

`ReorderableListView` has no `insertItem` or `removeItem`, as `AnimatedList` has, so a rebuild shows its items in their new places at once. With animated_reorderable, change your items, then call `insertItem` or `removeItem` on the list's state, as in step 3 of the [quick start](#quick-start), and the other items slide.

### How do I reorder a GridView in Flutter?

Flutter has no reorderable grid. Wrap your `GridView` in `AnimatedReorderable.grid`, with the same options as a list: a dragged item moves the others from cell to cell, across the rows.

### How do I drag and drop items between lists, as on a kanban board?

Put the lists, or grids, under an `AnimatedReorderableGroup`, give each a `ReorderOptions.groupId`, and move the item's data in the group's `onMove`. See [Dragging between lists and grids](#dragging-between-lists-and-grids), and the [kanban board example](https://github.com/igorkurilenko/animated_reorderable/tree/main/example/lib/kanban).

### How do I stop some items from being dragged?

`ReorderOptions.draggableGetter` says whether the item at an index can be dragged, and `reorderableGetter` whether it can take another's place, or be taken, so it stays where it is as the others move past.

### Can a drag start at once, without a long press?

Yes. Pass `gestureRecognizerFactory: (context) => ImmediateMultiDragGestureRecognizer()` to `ReorderOptions`; it comes from `package:flutter/gestures.dart`. The kanban board example does it for a mouse.

## Usage

Wrap a `ListView` in `AnimatedReorderable.list`, or a `GridView` in `AnimatedReorderable.grid`, and set:

- **keyGetter:** Required parameter to configure keys for uniquely identifying the items.
- **reorder:** To let users reorder the items, give `ReorderOptions` an `onReorder` callback in which you apply the permutations to your items. It also takes the decoration of dragged items and drag callbacks. After a reorder, an insert or a remove, the package builds again only the items it moves; an item that keeps its index keeps what it shows. If something else about your items changes, build the view again as usual, such as with `setState`. To keep heavy items from building again as they move, see [Rebuilds](#rebuilds).
- **swipeToRemove:** To let users swipe items away, give `SwipeToRemoveOptions` an `onSwipeToRemove` callback. It removes the swiped item from your data and calls `removeItem` with its index, as you remove an `AnimatedList`'s items: the list closes the gap as the item flies off, at the speed it's let go at. The item flies off as it is, with its state: the builder you give `removeItem` builds only the items you remove otherwise. Such an item keeps its state if the builder returns widgets of the same types as your item builder, down to the item's own widget. Otherwise it's built anew.
- **motion:** `MotionOptions` sets how items move to their new places.
- **insertTransition:** The transition items enter with, like the animation `AnimatedList` passes to its item builder. Insert an item with `insertItem(index)`, and it enters through the transition. Every item is built through it, so an item keeps its state when it has entered.

In 1.x these settings were parameters of their own, such as `onReorder` and `onSwipeToRemove`, and `insertItem` took a builder for the inserted item. 2.0 removed them: the [changelog](CHANGELOG.md) says what replaces each one.

`AnimatedReorderableState` inserts, removes and reorders items with an animation. Refer to it with a `GlobalKey`, or with `AnimatedReorderable.of` from an item's context. The examples are on the [Example tab](https://pub.dev/packages/animated_reorderable/example).

## Performance

With heavy items, the package's frames build in 51–76% less time than Flutter's, as it removes an item from a list or a grid and as an item is dragged. With light items, removing an item from a list is slower: 1.9 ms against `AnimatedList`'s 1.4 ms, 36% more. From a grid it takes the same 2.3 ms, and a drag still takes 44% less.

A reorder, an insert or a remove builds again only the items whose index changes, and only once: a removal builds nothing on the frames of its animation, and a drag nothing between the frames where it passes an item. Flutter's `AnimatedList` and `AnimatedGrid` build every item in sight twice for each removal, as it starts and as it ends, and `ReorderableListView` builds the other items in sight again on every frame of a drag. In a widget test that drags an item 3 rows down a list of 30, the items built 8 times in all, against 170 in a `ReorderableListView`.

In the package's measurements on an iPhone 17 Pro, in profile mode, with 60 items that each build a page of 24 rows:

**Removing the first item:** the build time of the frame that removes it, at the median of 6 removals.

| | animated_reorderable | `AnimatedList` or `AnimatedGrid` |
|---|---|---|
| list | 18.2 ms | 36.9 ms |
| grid | 21.9 ms | 51.3 ms |
| list, widgets cached by id | 13.2 ms | 35.8 ms |
| grid, widgets cached by id | 13.2 ms | 51.7 ms |
| list, light items | 1.9 ms | 1.4 ms |
| grid, light items | 2.3 ms | 2.3 ms |

**Dragging an item 3 rows down a list, 6 times:** a drag has many frames, so this is the build time of its slowest, and the number of frames that missed the 8.3 ms budget of the phone's 120 Hz screen.

| | animated_reorderable | `ReorderableListView` |
|---|---|---|
| heavy items | 3.1 ms, 1 frame missed | 12.7 ms, 23 frames missed |
| widgets cached by id | 2.9 ms, none missed | 7.7 ms, none missed |
| light items | 0.9 ms, none missed | 1.6 ms, none missed |

The same drags in a grid of these items, which Flutter can't reorder, built no frame slower than 4.6 ms and missed none. To keep heavy items from building again as they move, see [Rebuilds](#rebuilds).

## Rebuilds

As items are reordered, inserted or removed, the package builds again only the items whose index changes. Your item builder takes the index, so it runs again for each of them. For light items, such as a `ListTile`, that costs little. If your items are heavy, such as a page of content each, return the same widget for the same item, and Flutter doesn't build it again. Cache it by the item's id:

```dart
final _cells = <int, Widget>{};

Widget _cell(Item item) => _cells.putIfAbsent(item.id, () => ItemCard(item));

// In the view:
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => _cell(items[index]),
)
```

When an item changes, take its widget out of the cache, with `_cells.remove(item.id)`, and build the view again, such as with `setState`. Only that item builds again. With widgets cached by id, the items around one you remove, swipe away or drag don't build again, apart from one that comes into sight, and a `setState` above the list builds none of your items' widgets.

An item you remove with `removeItem` keeps its state as it leaves if the builder you give `removeItem` returns widgets of the same types as your item builder, down to the item's own widget. Otherwise it's built anew. Give both the same transition, and the removed item its cached widget:

```dart
itemBuilder: (context, index) => FadeTransition(
  opacity: kAlwaysCompleteAnimation,
  child: _cell(items[index]),
),

// Removing the item at index:
final item = items.removeAt(index);
final cell = _cells.remove(item.id) ?? ItemCard(item);
listKey.currentState!.removeItem(
  index,
  (context, animation) => FadeTransition(opacity: animation, child: cell),
);
```

An item swiped away needs none of this: it flies off as it is, and the builder you give `removeItem` doesn't build it.

## Dragging between lists and grids

Put lists and grids under an `AnimatedReorderableGroup`, and give each a `ReorderOptions.groupId`. An item dragged over another of them goes into it, from a list to a list, a list to a grid, a grid to a list or a grid to a grid: the group's `onMove` moves the item's data, and the items of both move in place, out of its way and into its old place. Let go, the item lands there.

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
- **Screen readers:** With `moveToListLabel`, which names each list's move in the app's language, such as "Move to Done", screen readers can move each item to the group's other lists too.
- The items' keys must be unique across the group's lists.

The example's board, `example/lib/kanban/main.dart`, is a kanban board, as on GitHub. A mouse drags its cards at once, with an `ImmediateMultiDragGestureRecognizer` from `ReorderOptions.gestureRecognizerFactory`, and a finger after a long press. A task flies from its card to a done card, its title struck through, as it goes into Done.

## Screen readers

Each item that can be dragged and reordered gets the moves a screen reader can make, named in the app's language as `ReorderableList` names them: to the start, one place up or down, and to the end. In a grid they go along the item's row, and a row up or down too. With `moveToListLabel`, an item also gets a move to each of the group's other lists, and it keeps the screen reader's focus as it goes there.

The moves are on the item's own node, which also holds what the item's widgets say, such as its text. A widget in the item that makes a node of its own gets a finger's touch instead, without the moves. A `Card` does: it puts its content on a node of its own. Label the item on its own node, and leave the card's semantics out:

```dart
itemBuilder: (context, index) => Semantics(
  label: 'Item ${items[index]}',
  child: ExcludeSemantics(
    child: Card(child: Text('Item ${items[index]}')),
  ),
),
```

Items of plain widgets, such as `Text` or a `ListTile`, buttons and all, need nothing more.
