## Unreleased

### Performance

- Move an item through the overlay on a layer of its own. A frame of its move changes only the layer's transform: neither the item nor the overlay lays out or paints again. Each frame used to paint every moving item's content again, 250 paints a frame for 8 moving cards. On an iPhone 17 Pro, a frame of a reorder now takes 0.34 ms on the UI thread instead of 0.62 on average, and 0.31 ms instead of 0.80 at the 90th percentile.
- Build only the items a reorder, an insert or a remove moves. After each change the package built every item the view showed again: 422 item builder calls per reorder in a 12-column grid, now 28. On an iPhone 17 Pro, a drag across such a grid no longer goes over 8.3 ms a frame, and its slowest frame went from 15.6 ms to 7.1. An item that keeps its index keeps what it shows until the app builds the view again, as with `setState`, which builds every item again.

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