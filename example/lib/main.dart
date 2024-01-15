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
