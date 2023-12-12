import 'package:flutter/material.dart';

import 'list_view_sample.dart';
import 'grid_view_sample.dart';

void main() {
  runApp(const AnimatedReorderableDemo());
}

final tabControllerKey = GlobalKey();
final gridViewSampleKey = GlobalKey<GridViewSampleState>();
final listViewSampleKey = GlobalKey<ListViewSampleState>();

abstract class Sample {
  void insertFirstItem();
  void insertLastItem();
  void removeFirstItem();
  void removeLastItem();
  void moveRandomItem();
}

class AnimatedReorderableDemo extends StatelessWidget {
  const AnimatedReorderableDemo({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
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
              extendBodyBehindAppBar: true,
              extendBody: true,
              appBar: AppBar(
                title: const Text('AnimatedReorderable'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                bottom: TabBar(
                  labelColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  indicatorColor:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                  tabs: const [
                    Tab(text: 'ListView'),
                    Tab(text: 'GridView'),
                  ],
                ),
              ),
              body: TabBarView(children: [
                ListViewSample(key: listViewSampleKey),
                GridViewSample(key: gridViewSampleKey),
              ]),
              bottomNavigationBar: BottomAppBar(
                color: Theme.of(context).colorScheme.primary,
                child: IconTheme(
                  data: IconTheme.of(context).copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Add first',
                        icon: const Icon(Icons.add),
                        onPressed: () =>
                            curSampleOf(context)?.insertFirstItem(),
                      ),
                      IconButton(
                        tooltip: 'Remove first',
                        icon: const Icon(Icons.remove),
                        onPressed: () =>
                            curSampleOf(context)?.removeFirstItem(),
                      ),
                      IconButton(
                        tooltip: 'Reorder random',
                        icon: const Icon(Icons.swap_calls),
                        onPressed: () => curSampleOf(context)?.moveRandomItem(),
                      ),
                      IconButton(
                        tooltip: 'Add last',
                        icon: const Icon(Icons.add),
                        onPressed: () => curSampleOf(context)?.insertLastItem(),
                      ),
                      IconButton(
                        tooltip: 'Remove last',
                        icon: const Icon(Icons.remove),
                        onPressed: () => curSampleOf(context)?.removeLastItem(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Sample? curSampleOf(BuildContext context) {
    final index = DefaultTabController.of(context).index;
    if (index == 0) return listViewSampleKey.currentState!;
    if (index == 1) return gridViewSampleKey.currentState!;
    return null;
  }
}
