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
    extends State<AnimatedReorderableGridSample> {
  final items = List.generate(200, (index) => index);
  final controller = AnimatedReorderableController();

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
          clipBehavior: Clip.none,
        ),
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
}
