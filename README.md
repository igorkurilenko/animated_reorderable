The best way to make `ListView` or `GridView` animated and reorderable.

## Features

This plugin provides the `AnimatedReorderable` wrapper for `ListView` and `GridView` that incorporates all the features present in standard `AnimatedList`, `AnimatedGrid` and `ReorderableListView`, while introducing the following enhancements:

* Introduces the capability to reorder `GridView` items
* Upgrades `ListView` or `GridView` to be animated and reorderable simultaneously
* Animates the repositioning of all grid items during addition or removal
* Enables deletion through a swipe gesture
* Certain items can be configured as non-reorderable
* In addition to programmatically initiating animated additions and removals, reordering can also be triggered programmatically on the `AnimatedReorderableState`

## Usage

Utilize `AnimatedReorderable.list()` or `AnimatedReorderable.grid()` to wrap `ListView` or `GridView` accordingly. Configure the following settings:

1. **keyGetter:** Configure keys to uniquely identify the items.
2. **reorderableGetter:** Specify the items that can be reordered; by default, all items are non-reorderable.
3. **onReorder:** Specify a callback in which you should update the order of items.
4. **draggableGetter:** Configure which items can be dragged to enable interactive reordering.

Here's an example of how to wrap a `ListView`:

```dart
import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/material.dart';

class ListViewExample extends StatefulWidget {
  const ListViewExample({super.key});

  @override
  State<ListViewExample> createState() => _ListViewExampleState();
}

class _ListViewExampleState extends State<ListViewExample> {
  // The jokes are borrowed from the good old ChatGPT 3.5
  // (do not remain in uneasy silence)
  final jokes = [
    Joke("Why do programmers prefer dark mode?\n"
        "Because light attracts bugs!"),
    Joke("Why do programmers always mix up Christmas and Halloween?\n"
        "Because Oct 31 == Dec 25."),
    Joke("How many programmers does it take to change a light bulb?\n"
        "None, that's a hardware problem!"),
  ];

  @override
  Widget build(BuildContext context) {
    // To wrap the ListView, invoke the factory 
    // constructor AnimatedReorderable.list
    return AnimatedReorderable.list(

      // 1. Configure the keyGetter using a function that
      // takes the index of the item and returns its key.
      keyGetter: (index) => ValueKey(jokes[index]),

      // 2. Configure the reorderableGetter with a function that 
      // takes the item's index and returns whether the item 
      // can be reordered.
      reorderableGetter: (index) => true,

      // 3. Define the onReorder callback to synchronize the order
      // of items. The callback takes permutations that need to be
      // applied to the collection of items.
      onReorder: (permutations) => permutations.apply(jokes),

      // 4. Configure the draggableGetter using a function that
      // takes the item's index and returns whether the item 
      // can be dragged (interactive reorder by dragging will 
      // commence after a long press on the item).
      draggableGetter: (index) => true,

      // The main wrapped hero of this example: basic ListView
      listView: ListView.builder(
        itemCount: jokes.length,
        itemBuilder: (context, index) {
          final joke = jokes[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(joke.text),
            ),
          );
        },
      ),
    );
  }
}

class Joke {
  final String text;

  Joke(this.text);
}
```

`AnimatedReorderableState` can be used to dynamically insert, remove or move (reorder) items. To refer to the `AnimatedReorderableState` either provide a GlobalKey or use the static of method from an item's input callback. There are showcases in the `/example` folder.