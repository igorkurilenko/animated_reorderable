import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;

void main() {
  // TODO: remove timeDilation before release
  timeDilation = 9.0;
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
  late final controller = AnimatedReorderableController(
    idGetter: (index) => items[index],
    didReorder: (permutations) => permutations.apply(items),
    swipeAwayDirectionGetter: (_) => AxisDirection.left,
    didSwipeAway: (index) {
      final item = items.removeAt(index);
      return (context, animation) => buildItem(item);
    },
    vsync: this,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('GridView Example'),
      ),
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

  Widget buildItem(int data) => Card(
        margin: const EdgeInsets.all(4),
        color: Colors.white,
        elevation: 1,
        child: Center(
          child: Text('$data'),
        ),
      );

  void insertRandomItem() {
    // TODO: randomize index
    const randomIndex = 0;
    final item = items.length;

    items.insert(randomIndex, item);

    controller.insertItem(
      randomIndex,
      builder: (context, index, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(
          opacity: animation,
          child: buildItem(items[index]),
        ),
      ),
    );
  }

  void removeRandomItem() {
    // TODO: randomize index
    const randomIndex = 0;

    final item = items.removeAt(randomIndex);

    controller.removeItem(
      randomIndex,
      builder: (context, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(
          opacity: animation,
          child: buildItem(item),
        ),
      ),
    );
  }

  void moveRandomItem() {
    // TODO: randomize indexes
    const randomIndex = 0;
    const randomDestinationIndex = 4;

    controller.moveItem(0, destinationIndex: randomDestinationIndex);
  }
}
