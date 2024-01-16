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
- In addition to programmatically initiating animated additions and removals, reordering can also be programmatically triggered.

## Usage

Utilize `AnimatedReorderable.list()` or `AnimatedReorderable.grid()` to wrap `ListView` or `GridView` accordingly. Configure the following settings:

1. **keyGetter:** Required parameter to configure keys for uniquely identifying the items.
3. **onReorder:** If you want to enable the reordering feature, specify a callback in which you should apply permutations on the items collection.

Here's an example of how to wrap a `ListView`:

```dart
import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const Example());
}

class Example extends MaterialApp {
  const Example({super.key})
      : super(
          home: const Scaffold(
            body: ListViewExample(),
          ),
        );
}

class ListViewExample extends StatefulWidget {
  const ListViewExample({super.key});

  @override
  State<ListViewExample> createState() => _ListViewExampleState();
}

class _ListViewExampleState extends State<ListViewExample> {
  final items = [1, 2, 3, 4, 5];

  @override
  Widget build(BuildContext context) {
    // To wrap the ListView, invoke the factory
    // constructor AnimatedReorderable.list
    return AnimatedReorderable.list(
      // 1. Configure the keyGetter using a function that
      // takes the index of the item and must return its unique key.
      keyGetter: (index) => ValueKey(items[index]),

      // 2. Define the onReorder callback to synchronize the order
      // of items. The callback takes permutations that need to be
      // applied to the collection of items.
      onReorder: (permutations) => permutations.apply(items),

      // The main wrapped hero of this example: basic ListView
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
}
```

`AnimatedReorderableState` can be used to dynamically insert, remove or reorder items. To refer to the `AnimatedReorderableState` either provide a GlobalKey or use the static `of` method from an item's input callback. There are showcases on the [Example](https://pub.dev/packages/animated_reorderable/example) page.