import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/material.dart';

import 'model.dart';

const initialItemCount = 6;

class GridViewSample extends StatefulWidget {
  const GridViewSample({super.key});

  @override
  State<GridViewSample> createState() => GridViewSampleState();
}

class GridViewSampleState extends State<GridViewSample> implements Sample {
  final _gridKey = GlobalKey<AnimatedReorderableState>();
  late final GridModel<Item> _grid;
  Item? _selectedItem;
  late int _nextItemId;

  @override
  void initState() {
    super.initState();
    _grid = GridModel<Item>(
      gridKey: _gridKey,
      initialItems: List.generate(initialItemCount, (id) => Item(id: id)),
      insertedItemBuilder: _buildInsertedItem,
      removedItemBuilder: _buildRemovedItem,
    );
    _nextItemId = initialItemCount;
  }

  Widget _buildItem(Item item) => CardItem(
        item: item,
        selected: _selectedItem == item,
        onTap: () {
          setState(() {
            _selectedItem = _selectedItem == item ? null : item;
          });
        },
      );

  Widget _buildInsertedItem(
    BuildContext context,
    int index,
    Animation<double> animation,
  ) =>
      ScaleTransition(
        scale: animation,
        child: FadeTransition(
          opacity: animation,
          child: _buildItem(_grid[index]),
        ),
      );

  Widget _buildRemovedItem(
    Item item,
    BuildContext context,
    Animation<double> animation,
  ) =>
      ScaleTransition(
        scale: animation,
        child: FadeTransition(
          opacity: animation,
          child: _buildItem(item),
        ),
      );

  @override
  void insert() {
    final int index =
        _selectedItem == null ? _grid.length : _grid.indexOf(_selectedItem!);
    _grid.insert(index, Item(id: _nextItemId++));
  }

  @override
  void moveRandom() {
    if (_grid.length < 2) return;

    final int index, destIndex;
    final indexes = List.generate(_grid.length, (i) => i);

    if (_selectedItem == null) {
      indexes.shuffle();
      index = indexes.removeAt(0);
      destIndex = indexes.removeAt(0);
    } else {
      index = _grid.indexOf(_selectedItem!);
      indexes.removeAt(index);
      indexes.shuffle();
      destIndex = indexes.removeAt(0);
    }

    _grid.move(index, destIndex);
  }

  @override
  void remove() {
    final int index = _selectedItem == null
        ? _grid.length - 1
        : _grid.indexOf(_selectedItem!);
    final item = _grid.removeAt(index);
    if (item == _selectedItem) {
      setState(() => _selectedItem = null);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedReorderable.grid(
        key: _gridKey,
        keyGetter: (index) => ValueKey(_grid[index]),
        draggableGetter: (index) => true,
        reorderableGetter: (index) => true,
        onReorder: (permutations) => _grid.onReorder(permutations),
        swipeToRemoveDirectionGetter: (index) => AxisDirection.left,
        onSwipeToRemove: (index) {
          final item = _grid.removeAt(index);
          if (item == _selectedItem) {
            setState(() => _selectedItem = null);
          }
        },
        gridView: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1 / 1.618,
          ),
          itemCount: _grid.length,
          itemBuilder: ((context, index) => _buildItem(_grid[index])),
        ),
      );
}

typedef RemovedItemBuilder<T> = Widget Function(
    T item, BuildContext context, Animation<double> animation);

class GridModel<E extends HasId> {
  GridModel({
    required this.gridKey,
    required this.insertedItemBuilder,
    required this.removedItemBuilder,
    Iterable<E>? initialItems,
  }) : _items = List<E>.from(initialItems ?? <E>[]);

  final GlobalKey<AnimatedReorderableState> gridKey;
  final AnimatedItemBuilder insertedItemBuilder;
  final RemovedItemBuilder<E> removedItemBuilder;
  final List<E> _items;

  AnimatedReorderableState? get _animatedReorderableGrid =>
      gridKey.currentState;

  void insert(int index, E item) {
    _items.insert(index, item);
    _animatedReorderableGrid!.insertItem(index, insertedItemBuilder);
  }

  E removeAt(int index) {
    final E removedItem = _items.removeAt(index);
    _animatedReorderableGrid!.removeItem(
      index,
      (BuildContext context, Animation<double> animation) =>
          removedItemBuilder(removedItem, context, animation),
    );
    return removedItem;
  }

  void move(int index, int destIndex) =>
      _animatedReorderableGrid!.moveItem(index, destIndex: destIndex);

  void onReorder(Permutations permutations) => permutations.apply(_items);

  int get length => _items.length;

  E operator [](int index) => _items[index];

  int indexOf(E item) => _items.indexOf(item);
}

class CardItem extends StatelessWidget {
  const CardItem({
    super.key,
    this.onTap,
    this.selected = false,
    required this.item,
  });

  final VoidCallback? onTap;
  final Item item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    TextStyle textStyle = Theme.of(context).textTheme.headlineMedium!;
    if (selected) {
      textStyle = textStyle.copyWith(color: Colors.lightGreenAccent[400]);
    }
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Card(
          color: Colors.primaries[item.id % Colors.primaries.length],
          child: Center(
            child: Text('$item', style: textStyle),
          ),
        ),
      ),
    );
  }
}
