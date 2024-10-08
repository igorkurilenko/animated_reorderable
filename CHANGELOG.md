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