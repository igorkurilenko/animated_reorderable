import 'dart:math';

import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/material.dart';

import 'main.dart';

const initialNumberOfItems = 10;

class ListViewSample extends StatefulWidget {
  const ListViewSample({super.key});

  @override
  State<ListViewSample> createState() => ListViewSampleState();
}

class ListViewSampleState extends State<ListViewSample>
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

    return AnimatedReorderable.list(
        controller: controller,
        listView: ListView.builder(
          itemCount: items.length,
          itemBuilder: ((context, index) => buildItem(items[index])),
        ),
      );
  }

  Widget buildItem(int item) => Card(
        color: Colors.grey.shade300,
        elevation: 0,
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        child: SizedBox(
          height: 80,
          child: Center(
            child: Text(
              '$item',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
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

  void insertRandomItem() => insertItemAt(Random().nextInt(items.length));

  @override
  void insertLastItem() => insertItemAt(items.length);

  void insertItemAt(int index) {
    items.insert(index, nextItem++);
    controller.insertItem(index, builder: insertedItemBuilder);
  }

  @override
  void removeFirstItem() => removeItemAt(0);

  void removeRandomItem() => removeItemAt(Random().nextInt(items.length));

  @override
  void removeLastItem() => removeItemAt(items.length - 1);

  void removeItemAt(int index) {
    final item = items.removeAt(index);
    controller.removeItem(index, builder: createRemovedItemBuilder(item));
  }

  @override
  void moveRandomItem() {
    // TODO: randomize indexes
    const randomIndex = 0;
    final randomDestinationIndex = 3;

    controller.moveItem(
      randomIndex,
      destIndex: randomDestinationIndex,
    );
  }
}
