import 'dart:developer';

import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/material.dart';

import 'main.dart';

const initialNumberOfItems = 100;

class GridViewSample extends StatefulWidget {
  const GridViewSample({super.key});

  @override
  State<GridViewSample> createState() => GridViewSampleState();
}

class GridViewSampleState extends State<GridViewSample>
    with AutomaticKeepAliveClientMixin
    implements Sample {
  final _gridKey = GlobalKey<AnimatedReorderableState>();
  final _items = List.generate(initialNumberOfItems, (index) => index);
  int _nextItem = initialNumberOfItems;

  AnimatedReorderableState? get _grid => _gridKey.currentState;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return AnimatedReorderable.grid(
      key: _gridKey,
      idGetter: (index) => _items[index],
      didReorder: (permutations) => permutations.apply(_items),
      swipeAwayDirectionGetter: (index) => AxisDirection.left,
      didSwipeAway: (index) {
        final item = _items.removeAt(index);
        return createRemovedItemBuilder(item);
      },
      gridView: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          childAspectRatio: 1 / 1.618,
        ),
        itemCount: _items.length,
        itemBuilder: ((context, index) => buildItem(_items[index])),
      ),
    );
  }

  Widget buildItem(int item) => Card(
        color: Colors.grey.shade300,
        elevation: 0,
        child: Center(
          child: Text(
            '$item',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      );

  Widget insertedItemBuilder(
    BuildContext context,
    int index,
    Animation<double> animation,
  ) =>
      ScaleTransition(
        scale: animation,
        child: FadeTransition(
          opacity: animation,
          child: buildItem(_items[index]),
        ),
      );

  AnimatedRemovedItemBuilder createRemovedItemBuilder(int item) =>
      (context, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(
              opacity: animation,
              child: buildItem(item),
            ),
          );

  @override
  void insertFirstItem() => insertItemAt(0);

  @override
  void insertLastItem() => insertItemAt(_items.length);

  void insertItemAt(int index) {
    _items.insert(index, _nextItem++);
    _grid!.insertItem(index, insertedItemBuilder);
  }

  @override
  void removeFirstItem() => removeItemAt(0);

  @override
  void removeLastItem() => removeItemAt(_items.length - 1);

  void removeItemAt(int index) {
    final item = _items.removeAt(index);
    _grid!.removeItem(index, createRemovedItemBuilder(item));
  }

  @override
  void moveRandomItem() {
    if (_items.length < 2) return;

    final indexes = List.generate(_items.length, (i) => i)..shuffle();
    final index = indexes[0];
    final destIndex = indexes[1];

    log('move item at $index to $destIndex');

    _grid!.moveItem(index, destIndex: destIndex);
  }
}
