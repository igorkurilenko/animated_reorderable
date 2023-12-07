import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const AnimatedReorderableDemoApp());
}

class AnimatedReorderableDemoApp extends StatelessWidget {
  const AnimatedReorderableDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnimatedReorderable Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AnimatedReorderableGridSample(),
    );
  }
}

class AnimatedReorderableGridSample extends StatefulWidget {
  const AnimatedReorderableGridSample({super.key});

  @override
  State<AnimatedReorderableGridSample> createState() =>
      _AnimatedReorderableGridSampleState();
}

class _AnimatedReorderableGridSampleState
    extends State<AnimatedReorderableGridSample> with TickerProviderStateMixin {
  final items = List.generate(200, (index) => index);
  int nextItem = 200;

  late final controller = AnimatedReorderableController(
    vsync: this,
    idGetter: (index) => items[index],
    didReorder: (permutations) => permutations.apply(items),
    swipeAwayDirectionGetter: (_) => AxisDirection.left,
    didSwipeAway: (index) {
      final item = items.removeAt(index);
      return createRemovedItemBuilder(item);
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('GridView Example'),
      ),
      extendBodyBehindAppBar: true,
      body: AnimatedReorderable.grid(
        controller: controller,
        gridView: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 1 / 1.618,
          ),
          itemCount: items.length,
          itemBuilder: ((context, index) => buildItem(items[index])),
        ),
      ),
      floatingActionButton: Wrap(
        direction: Axis.horizontal,
        children: [
          FloatingActionButton(
            onPressed: insertRandomItem,
            child: const Icon(Icons.add),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: removeRandomItem,
            child: const Icon(Icons.remove),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: moveRandomItem,
            child: const Icon(Icons.swap_calls),
          ),
        ],
      ),
    );
  }

  Widget buildItem(int item) => Card(
        margin: const EdgeInsets.all(4),
        color: Colors.white,
        elevation: 1,
        child: Center(
          child: Text('$item'),
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

  void insertRandomItem() {
    // TODO: randomize index
    const randomIndex = 0;

    items.insert(randomIndex, nextItem++);

    controller.insertItem(
      randomIndex,
      builder: insertedItemBuilder,
    );
  }

  void removeRandomItem() {
    // TODO: randomize index
    const randomIndex = 0;

    final item = items.removeAt(randomIndex);

    controller.removeItem(
      randomIndex,
      builder: createRemovedItemBuilder(item),
    );
  }

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
