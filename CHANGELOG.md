## Unreleased

### Performance

- Build a dense grid's items faster after a change. The package looks up each item it builds by its key. A `ValueKey` hashes its `runtimeType` with its value, and a generic class's `runtimeType`, such as `ValueKey<int>`'s, is slow to get in release builds: in a drag across a 12-column grid, it took a third of each rebuild. The package now hashes value keys by their values. On an iPhone 17 Pro, the slowest frame of that drag builds in 5.2 ms rather than 6.9.

### Fixes

- List an item's screen-reader moves in the same order on every item: the moves within its list first, in `ReorderableList`'s order, then the moves to the group's other lists, in the order of the board. The platform lists an item's actions in the order Flutter first numbered their labels anywhere in the app, so the order depended on which items were built first: on the example's board, "Move to Done" came before "Move to In progress".
- Keep a screen reader's focus on an item it moves to another list. Lifting the item took away the node that had the focus, and VoiceOver's cursor went to the top of the screen. The item now takes the focus where it lands, or back in its own list if the app doesn't let it move. It scrolls into sight first, as into a column of a board that scrolls sideways: a screen reader focuses only what shows.

## 2.5.0

### Features

- Set the spring a dragged item flies back to its place with: `ReorderOptions.springDescription`, as swipes have `SwipeToRemoveOptions.springDescription`. 2.4.0's faster default spring had no option for drags. `SpringDescription(mass: 1, stiffness: 500, damping: 75)` restores the old one.
- Let screen readers move an item to another list of a group. Give `AnimatedReorderableGroup.moveToListLabel`, which names the move to each list in the app's language, such as "Move to Done". Each item that can be dragged and reordered can then move to each other list that the group's `canMove` lets it go to, in the order of the tree. It goes to the same index there, or to the end of a shorter list, and flies there through the group's layer, to the new list's look, as a drag that lets it go there does. `onMove` moves its data. Without the labels, screen readers move items only within their lists.
- Let screen readers move an item a row up or down in a grid, as well as along its row: Move up and Move down in a grid that scrolls down, and Move left and Move right in one that scrolls sideways. A row move takes the item to the slot a row away, or past items that can't be reordered to the nearest one beyond. A grid of one column, or with rows that aren't all alike, has none. The moves follow the grid as a resize changes its columns.

### Docs

- List screen-reader moves and drags between lists among the features in the API docs of the library and of `AnimatedReorderable`, as the README does.
- Correct 2.2.0's note on the raster thread in dense grids. The 0.9 ms a frame that building only the items a change moves seemed to cost it isn't more work. With less to build, the phone's power management runs the CPU slower, so the same work takes longer. On an iPhone 17 Pro, every step of a frame on the raster thread takes about twice as long, even those that don't depend on what's drawn, and so do the UI thread's paint and compositing, with the same layers and the same repaints. Building only the moved items keeps every frame of a drag across a 12-column grid within the 8.3 ms budget; building them all puts 22 to 28 over it.

### Example

- Sign the example apps with each checkout's own team. The iOS project carried a personal development team, which broke signing for anyone else. Each checkout can now put its team in `Signing.xcconfig`, which git ignores, and the example's README says how.
- Let screen readers move the kanban board's cards between its columns, with moves named after them, such as Move to Done.
- Lift a held card off the kanban board, as GitHub's boards do: it grows a little and casts a shadow, and stays opaque. It faded to 70% before, so the cards under it showed through.

## 2.4.0

### Behavior changes

- Animate faster by default, at the pace of Flutter's own lists. Items move to their new places in 250 ms rather than 500, as a `ReorderableListView`'s do, and a held item's decoration comes and goes as fast. Inserted and removed items enter and leave in 300 ms rather than 500, as an `AnimatedList`'s do. The spring that flings an item back to its place, or out of the list, is four times as stiff and twice as damped, so it gets there in half the time with the same feel. To keep the old pace, pass `MotionOptions(duration: Duration(milliseconds: 500))`, `ItemDecoration(duration: Duration(milliseconds: 500))`, a `duration` to `insertItem` and `removeItem`, and `SwipeToRemoveOptions(springDescription: SpringDescription(mass: 1, stiffness: 500, damping: 75))`. An item let go after a drag has no option for its spring.

### Features

- Drag items between lists and grids, as between the columns of a board. Put the lists under an `AnimatedReorderableGroup` and give each a `ReorderOptions.groupId`. An item dragged over another of the lists goes into it, as the group's `onMove(from, to)` moves its data, and the items of both lists move in place out of its way and into its old place. Let go, it lands there, with its state kept and the size of the new list's slots. `canMove` can refuse a move before any data changes. The drag callbacks come from the list the item is in at the time, and an item dragged over no list stays in the last one it was over.
- Scroll a board of lists to the ones out of sight. Held at an edge of a view that scrolls across the lists, such as a board that scrolls sideways, a dragged item scrolls it, and goes into each list the view brings under it. The group can be inside such a view or around it, and an item let go lands on its slot as the view scrolls.
- Fly a dragged item from one list's look to another's, as hero_here flies a hero, when the lists of a group build their items differently, such as cards in a list and thumbnails in a grid. As the item goes into the other list, its old look, as it last showed, fades out and the new list's look fades in, while it grows or shrinks to the new list's slots around the point the pointer holds. Its old look isn't built again: the old list builds another item at its index by then. `AnimatedReorderableGroup.flight` sets the duration, the curve and the shuttle builder, which has hero_here's shape, and `FlightOptions.none` turns flights off. An item let go mid-flight lands once it has flown.

### Fixes

- Keep the items of a list or grid scrolled to its end where they show as an item leaves it, removed, swiped away or dragged into another list. The view shrank under its scroll offset, which came back within its range at once: the items before the gap jumped down into it, and those after it jumped down and slid back up. A grid that lost its last row, as its last item went, jumped down a row. Now the items before the gap slide down into it, and those after it stay put. It broke in 2.0.1, which left the items a change doesn't move in the list. A view that resizes still moves its items with its content, as any view does.
- Take an item that moves to its new slot through the overlay to where the slot is when the slot moves again on the way, as when a held item before it resizes, such as a card that goes into a list of smaller thumbnails. It went on to where the slot had been, then jumped back to it as it landed.
- Keep an item let go in its place on its way back to its own look as the list builds again, as when the app sets state as a drag ends. It landed at once, and jumped from its held look, by default scaled up and faded, to its own.

### Example

- Add a kanban board, whose cards are dragged within and between its three columns, to the example app and to its page on pub.dev. A mouse drags a card at once and a finger after a long press, and a task that goes into Done flies to a done card with its title struck through.

## 2.3.0

### Features

- Let screen readers move items, as Flutter's `ReorderableList` does: each item that can be dragged and reordered gets the actions Move to the start, Move up, Move down and Move to the end. They take their names from the app's `WidgetsLocalizations`, and sit on a semantics node of each item's own, under its index, as in `ReorderableList`. A move goes as `reorderItem` does, in place, and calls `onReorder`. It takes the item past items that can't be reordered. Each move is named after the way it goes on screen: Move left and Move right in a horizontal list and along a grid's row, and in a reversed list Move up goes up the screen, where `ReorderableList`'s would go down.

### Fixes

- Show a screen reader an item that moves in place in its new slot once it gets there. The frames of a move change only the item's layer, so since 2.1.0 a screen reader found each item a change moved where its move started: its focus outline stayed in the old slot, and touching that slot found it, while touching the item where it showed found another.

## 2.2.1

### Fixes

- Lift an item that a long press takes on its way in place from where it shows. The lift showed it where it was as the pointer went down, half a second before, so it jumped back by as far as it had moved since: 38 px in a test's grid.

### Example

- Ship the example's page, `example/example.md`, in the package, so pub.dev shows it on the package's Example tab and counts it. `.pubignore` left out the whole example folder, so pub.dev found no example, which cost 10 of the 160 points.

## 2.2.0

### Behavior changes

- Fling an item on at the speed it is let go. Its fling started at a part of the screen per second, so an item let go at 30 px a frame went on at about 18. It now goes on at the speed along its way, and as a spring would: let go fast enough, a bouncy spring takes it past its place and back, and let go moving away, it goes on away before it heads back, rather than stopping at either end.
- Let a pointer take an item moving in place where it shows, as on other platforms: a drag or a swipe can start on it on its way, from where it shows, and a swiped one goes on to its slot as it's swiped. It ignored pointers until it got to its slot. Items moving through the overlay on their way out of sight still do.
- Bring an item a reorder moves into sight from out of it in place, in the list: it comes in from just outside the view, at its own size, rather than through the overlay. 2.0.1's note that an item bigger than the others starts its way in that much closer no longer applies. In a grid, it comes in along its own column rather than from the middle of the grid.

### Docs

- Correct 2.1.0's note on the raster thread in dense grids, which put its extra work down to each moving cell's own layer alone. Measured since, building only the items a change moves accounts for most of it, about 0.9 ms of the 1.3 ms a frame, with the same layers; why is yet to be found.

## 2.1.0

### Performance

- Move an item through the overlay on a layer of its own. A frame of its move changes only the layer's transform: neither the item nor the overlay lays out or paints again. Each frame used to paint every moving item's content again, 250 paints a frame for 8 moving cards. On an iPhone 17 Pro, a frame of a reorder now takes 0.34 ms on the UI thread instead of 0.62 on average, and 0.31 ms instead of 0.80 at the 90th percentile.
- Build only the items a reorder, an insert or a remove moves. After each change the package built every item the view showed again: 422 item builder calls per reorder in a 12-column grid, now 28. On an iPhone 17 Pro, a drag across such a grid no longer goes over 8.3 ms a frame, and its slowest frame went from 15.6 ms to 7.1. An item that keeps its index keeps what it shows until the app builds the view again, as with `setState`, which builds every item again.
- Move an item in place, in the list, when its new slot shows. Only the dragged or swiped item, removed items and items that go out of sight move through the overlay. An item no longer leaves the list and comes back for a move, so a change builds each item it moves once: 14 item builder calls per reorder in a 12-column grid, 28 before. On an iPhone 17 Pro, the slowest 1% of a reorder's frames take 1.8 ms on the UI thread instead of 4.5, and of a swipe's 1.3 ms instead of 5.4.
- In a dense grid, the raster thread does more while many cells move at once, since each moving cell paints on a layer of its own. On an iPhone 17 Pro, a drag across a 12-column grid takes 2.9 ms a frame on it instead of 1.6, a third of the 8.3 ms budget. Lists are as before.

### Behavior changes

- Items whose new slots show move in the list itself. As before, a dragged item shows above them and a removed item under them, and an item on its way ignores pointers until it gets to its slot.
- An item that shows neither before a change nor after it doesn't move: the list lays it out in its new slot.
- Show a removed item under the list's own items, not only under the items that move into its place. At a z-index of 0 or more it still shows above them.

## 2.0.1

### Performance

- Leave the items that a reorder, an insert or a remove doesn't move in the list. Each change lifted every item the list showed into the overlay, and the next frame put back the ones that stayed. On an iPhone 17 Pro at 120 Hz, a drag across a 12-column grid of about 400 cells took 49 of 489 frames over budget, and now takes 6 of 508; its slowest frame went from 31 ms to 16 ms.

### Fixes

- Build an item that a reorder brings in from out of sight under the list's ancestors. The package measured it in a tree of its own, without the app's `Material`, `MediaQuery`, theme or inherited widgets. So items such as a `ListTile` or a `CircleAvatar` threw, and an item that the theme sizes slid in at the wrong size. Now the overlay lays the item out at its own size. Until it does, the package takes the item to be as big as one the list built, so an item bigger than the others starts its way in that much closer.
- Fling an item on the way it moves as it is let go. Its fling started as if it moved away from where it flies to, so an item let go moving back to its place, or swiped out, slowed down first. Let go fast, it stood still for a frame or two before it moved.

## 2.0.0

2.0 removes what 1.6.0 deprecated. Upgrade to 1.6.0 first and fix its deprecation warnings. Three changes are left after that: drop the `null` from `insertItem(index, null)`, rename `ReorderCallback` to `PermutationsCallback`, and drop the type argument from `AnimatedReorderableState<…>`.

### Breaking changes

- `AnimatedReorderable.list` and `.grid` take only `keyGetter`, `motion`, `reorder`, `swipeToRemove`, `insertTransition` and the view. Each flat parameter moved to an option object:

  | 1.x | 2.0 |
  |---|---|
  | `motionAnimationDuration`, `motionAnimationCurve` | `motion: MotionOptions(duration:, curve:)` |
  | `onReorder`, `draggableGetter`, `reorderableGetter`, `autoScrollerVelocityScalar`, `reorderGestureRecognizerFactory` | `reorder: ReorderOptions(onReorder:, draggableGetter:, reorderableGetter:, autoScrollerVelocityScalar:, gestureRecognizerFactory:)` |
  | `draggedItemDecorator`, `draggedItemDecorationAnimationDuration` | `reorder: ReorderOptions(decoration: ItemDecoration(decorator:, duration:))` |
  | `onItemDragStart`, `onItemDragUpdate`, `onItemDragEnd` | `reorder: ReorderOptions(callbacks: ItemDragCallbacks(onStart:, onUpdate:, onEnd:))` |
  | `onSwipeToRemove`, `swipeToRemoveDirectionGetter`, `swipeToRemoveExtent`, `swipeToRemoveVelocity`, `swipeToRemoveSpringDescription` | `swipeToRemove: SwipeToRemoveOptions(onSwipeToRemove:, directionGetter:, extent:, velocity:, springDescription:)` |
  | `swipedItemDecorator`, `swipedItemDecorationAnimationDuration` | `swipeToRemove: SwipeToRemoveOptions(decoration: ItemDecoration(decorator:, duration:))` |
  | `onItemSwipeStart`, `onItemSwipeUpdate`, `onItemSwipeEnd` | `swipeToRemove: SwipeToRemoveOptions(callbacks: ItemDragCallbacks(onStart:, onUpdate:, onEnd:))` |

- The getters of the same names on `AnimatedReorderable` are gone. Read the options instead, such as `widget.reorder.onReorder`.
- `insertItem(index, builder)` is `insertItem(index)`. Move the builder's transition to `insertTransition`, which gets the item as its `child`:

  ```dart
  // 1.x
  state.insertItem(index, (context, index, animation) =>
      FadeTransition(opacity: animation, child: buildItem(index)));

  // 2.0
  AnimatedReorderable.list(
    insertTransition: (child, index, animation) =>
        FadeTransition(opacity: animation, child: child),
    // …
  );
  state.insertItem(index);
  ```

- The `AnimatedReorderable` constructor and `AnimatedReorderableState.buildCollectionView` are gone. Use `AnimatedReorderable.list` and `.grid`.
- `AnimatedReorderable` and `AnimatedReorderableState` are `final` classes, and `AnimatedReorderableState<T>` is `AnimatedReorderableState`.
- `ReorderCallback` is `PermutationsCallback`, so that it no longer clashes with Flutter's `ReorderCallback`.

### Behavior changes

- An item moving to its new place whose place moves again heads for the new place at the speed it has, instead of stopping and starting over from rest. Items no longer stutter when items are inserted or removed one after another, or when a drag turns back. Each move still takes `MotionOptions.duration` along `MotionOptions.curve`, so an item comes to rest one duration after its place last moved, as before. An item flung back to its place after a drag or a swipe still starts over when its place moves.

### Performance

- Build a moving item only when it changes, not on every frame of its move, nor when other items come and go. The item builder runs for a moving item when it enters the overlay, when its index or the list's configuration changes, and when it lands. One reorder in a list of five items ran the item builder 138 times, and now runs it 10 times; a drag across five items, 250 times and now 66.

### Fixes

- Lift an item that is held again while it flies back to its slot above the other items flying back. It could stay under an item let go after it.
- Keep moving items on course while the list scrolls by fractions of a pixel. Rounding left them a hair off their slots, so they started their move over at every rebuild, from rest.

## 1.6.1

### Fixes

- Move an item on when its place moves just as it gets where it was moving, as a drag back and forth can make it. It jumped to its new place in one frame.

## 1.6.0

### Features

- Configure `AnimatedReorderable.list` and `.grid` with option objects: `motion: MotionOptions(…)`, `reorder: ReorderOptions(…)` and `swipeToRemove: SwipeToRemoveOptions(…)`. `ItemDecoration` and `ItemDragCallbacks` group a held item's decoration and its callbacks.
- Enter inserted items through `insertTransition`, the way `AnimatedList` gives its item builder an animation. Insert with `insertItem(index, null)`. Every item is built through the transition, so an item keeps its state when it has entered. An item inserted with a builder that wraps it, such as a `FadeTransition`, lost its state at the first rebuild after it entered.

### Fixes

- Stop leaking an animation on every frame while an item is dragged with the default decorator.
- Fling swiped items with `swipeToRemoveSpringDescription`, which had no effect.
- Use the `PrimaryScrollController` like a plain list or grid. Tapping the iOS status bar scrolls a wrapped list to the top again, and wrapping a view with `primary: true` no longer throws.
- Move items to and from indexes the list doesn't show along the list, not the screen. They drifted when the list didn't start at the screen's left edge.
- Keep moving items with the scroll after a clamp of the scroll offset, as after removing the last item of a list scrolled to its end.
- Keep a fling going when the list rebuilds.
- Keep the first visible item in place when the list resizes, instead of rescaling the scroll offset.
- Lay out moving, removed and held items as the list would after a resize, instead of scaling them. Held items stay under the pointer.
- Check `destIndex` in `reorderItem`. A reorder past the end corrupted the list's state.
- Move items in from off-screen at their size, in line with the list's items.
- Take a grid delegate of another type, instead of throwing a `TypeError`.
- Show an item that is inserted again while it animates out, as an undo does.
- Keep items in place across two inserts or removes in one frame. Two removes threw a `RangeError`.
- Throw `StateError`, `ArgumentError`, `RangeError` and `UnsupportedError` instead of strings.

### Deprecations

These still work, and go in 2.0:

- The flat parameters of `AnimatedReorderable.list` and `.grid`, such as `onReorder` and `onSwipeToRemove`, and the getters of the same names. Use the option objects.
- The `AnimatedReorderable` constructor and `AnimatedReorderableState.buildCollectionView`. Use `AnimatedReorderable.list` and `.grid`.
- The `builder` of `insertItem`. Use `insertTransition` and `insertItem(index, null)`.

### Behavior changes

- Item widgets use the latest settings rather than the ones they were built with.
- A dragged item's placeholder follows the item's size.
- `Permutation` compares by value.
- The deprecated `AnimatedReorderable` constructor is no longer `const`.

## 1.5.0

### Fixes

- Keep item state while items move. Items were built a second time in the overlay during an insert, remove, reorder, drag or swipe, so their state was created again ([#4](https://github.com/igorkurilenko/animated_reorderable/issues/4)).
  Now each item moves between the list and the overlay instead, so while it moves, it lives outside the scroll view: `Scrollable.of` and `PrimaryScrollController` don't find the list's scroll view during those 500 ms.
- Dispose the animations of items that stop moving. Every move leaked tickers, and disposing the list while an item moved could fail with "disposed with an active Ticker" ([#5](https://github.com/igorkurilenko/animated_reorderable/issues/5)).
- Move item elements along with their items: unless the wrapped delegate has a `findChildIndexCallback`, the list now finds items by key.
- Use the latest `keyGetter`, item builder, callbacks and scroll controller after a rebuild, instead of the ones from the first build.

### Maintenance

- Require Dart 3.13 and Flutter 3.47.
- Forward `scrollCacheExtent`, `itemExtentBuilder` and `hitTestBehavior` to the wrapped list or grid.
- Update the example to the current Flutter templates.

## 1.4.2

### Fixes

- Fix typo in `reorderGestureRecognizerFactory` name.

## 1.4.1

### Fixes

- Updated `part of` directives to use string-based file paths instead of library names for improved compatibility and compliance with current Dart best practices.

## 1.4.0

### Features

- Added `reorderGestureRecognizerFactory` property to allow overriding the default drag gesture recognizer, enabling customizations like modifying the drag delay or supporting specific input devices.

## 1.3.3

### Features

- Added `getRenderedItemBuildContext` method to retrieve the `BuildContext` of a rendered item.

## 1.3.2

### Documentation

- Clarified index updates during item reordering in drag callbacks and specified that in ItemDragEndCallback, the index indicates where the item was dropped.

## 1.3.1

### Fixes

- Enabled disabling swipeToRemove for specific items.

## 1.3.0

### Enhancements

- Made the Permutation class public and Permutations iterable.

## 1.2.0

### Features

- Added method to check if an item is rendered in the viewport or cache extent.

## 1.1.0

### Features

- Implemented API documentation.

### Enhancements

- Items are draggable and reorderable by default.
- Added callbacks for drag and swipe events.

## 1.0.0 

- Initial stable release.