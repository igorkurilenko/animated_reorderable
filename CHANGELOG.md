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