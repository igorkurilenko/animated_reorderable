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
///    goes.
/// 3. [SwipeToRemoveOptions.onSwipeToRemove] deletes a swiped card, from the
///    items and from the list.
/// 4. A tap on + inserts a card, which fades in as the others slide down.
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
      // 4. A tap inserts a card at the top.
      onPressed: () {
        _items.insert(0, _next++);
        _listKey.currentState!.insertItem(0);
      },
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
      // 3. A swipe deletes the card.
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
