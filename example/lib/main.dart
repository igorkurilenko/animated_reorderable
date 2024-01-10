import 'package:flutter/material.dart';

import 'model.dart';
import 'list_view_sample.dart';
import 'grid_view_sample.dart';

void main() {
  runApp(const AnimatedReorderableDemo());
}

final tabControllerKey = GlobalKey();
final gridViewSampleKey = GlobalKey<GridViewSampleState>();
final listViewSampleKey = GlobalKey<ListViewSampleState>();
class AnimatedReorderableDemo extends StatelessWidget {
  const AnimatedReorderableDemo({super.key});

  Sample? _currentSampleOf(BuildContext context) {
    final index = DefaultTabController.of(context).index;
    if (index == 0) return listViewSampleKey.currentState!;
    if (index == 1) return gridViewSampleKey.currentState!;
    return null;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AnimatedReorderable',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.grey.shade100,
            primary: Colors.grey.shade100,
          ),
        ),
        home: DefaultTabController(
          key: tabControllerKey,
          length: 2,
          child: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('AnimatedReorderable'),
                actions: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    onPressed: () => _currentSampleOf(context)?.insert(),
                    tooltip: 'insert a new item',
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_calls),
                    onPressed: () => _currentSampleOf(context)?.moveRandom(),
                    tooltip: 'insert a new item',
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle),
                    onPressed: () => _currentSampleOf(context)?.remove(),
                    tooltip: 'remove the selected item',
                  ),
                ],
                bottom: TabBar(
                  labelColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  indicatorColor:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                  tabs: const [
                    Tab(text: 'List'),
                    Tab(text: 'Grid'),
                  ],
                ),
              ),
              body: TabBarView(children: [
                ListViewSample(key: listViewSampleKey),
                GridViewSample(key: gridViewSampleKey),
              ]),
            ),
          ),
        ),
      );
}
