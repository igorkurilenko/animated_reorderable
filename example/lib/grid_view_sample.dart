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
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin
    implements Sample {
  final items = List.generate(initialNumberOfItems, (index) => index);
  int nextItem = initialNumberOfItems;

  late final controller = AnimatedReorderableController(
    vsync: this,
    idGetter: (index) => items[index],
    didReorder: (permutations) => permutations.apply(items),
    swipeAwayDirectionGetter: (index) => AxisDirection.left,
    didSwipeAway: (index) {
      final item = items.removeAt(index);
      return createRemovedItemBuilder(item);
    },
  );

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return AnimatedReorderable.grid(
      controller: controller,
      gridView: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          childAspectRatio: 1 / 1.618,
        ),
        itemCount: items.length,
        itemBuilder: ((context, index) => buildItem(items[index])),
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
          child: buildItem(items[index]),
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
  void insertLastItem() => insertItemAt(items.length);

  void insertItemAt(int index) {
    items.insert(index, nextItem++);
    controller.insertItem(index, insertedItemBuilder);
  }

  @override
  void removeFirstItem() => removeItemAt(0);

  @override
  void removeLastItem() => removeItemAt(items.length - 1);

  void removeItemAt(int index) {
    final item = items.removeAt(index);
    controller.removeItem(index, createRemovedItemBuilder(item));
  }

  @override
  void moveRandomItem() {
    if (items.length < 2) return;

    final indexes = List.generate(items.length, (i) => i)..shuffle();
    final index = indexes[0];
    final destIndex = indexes[1];

    log('move item at $index to $destIndex');

    controller.moveItem(index, destIndex: destIndex);
  }
}
