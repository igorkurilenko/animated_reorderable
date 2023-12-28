import 'dart:math';

import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/material.dart';

import 'model.dart';

const initialItemCount = 5;
const minHeight = 80.0;
const maxHeight = 200.0;

double randomHeight(double minHeight, double maxHeight) =>
    minHeight + Random().nextDouble() * (maxHeight - minHeight);

class ListViewSample extends StatefulWidget {
  const ListViewSample({super.key});

  @override
  State<ListViewSample> createState() => ListViewSampleState();
}

class ListViewSampleState extends State<ListViewSample> implements Sample {
  final _listKey = GlobalKey<AnimatedReorderableState>();
  late final ListModel<Item> _list;
  Item? _selectedItem;
  late int _nextItemId;

  @override
  void initState() {
    super.initState();
    _list = ListModel<Item>(
      listKey: _listKey,
      initialItems: List.generate(initialItemCount, _createItem),
      insertedItemBuilder: _buildInsertedItem,
      removedItemBuilder: _buildRemovedItem,
    );
    _nextItemId = initialItemCount;
  }

  Item _createItem(int id) =>
      Item(id: id, height: randomHeight(minHeight, maxHeight));

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
          child: _buildItem(_list[index]),
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
        _selectedItem == null ? _list.length : _list.indexOf(_selectedItem!);
    _list.insert(index, _createItem(_nextItemId++));
  }

  @override
  void moveRandom() {
    if (_list.length < 2) return;

    final int index, destIndex;
    final indexes = List.generate(_list.length, (i) => i);

    if (_selectedItem == null) {
      indexes.shuffle();
      index = indexes.removeAt(0);
      destIndex = indexes.removeAt(0);
    } else {
      index = _list.indexOf(_selectedItem!);
      indexes.removeAt(index);
      indexes.shuffle();
      destIndex = indexes.removeAt(0);
    }

    _list.move(index, destIndex);
  }

  @override
  void remove() {
    final int index = _selectedItem == null
        ? _list.length - 1
        : _list.indexOf(_selectedItem!);
    final item = _list.removeAt(index);
    if (item == _selectedItem) {
      setState(() => _selectedItem = null);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedReorderable.list(
        key: _listKey,
        idGetter: (index) => _list[index].id,
        draggableGetter: (index) => true,
        reorderableGetter: (index) => true,
        onReorder: (permutations) => _list.onReorder(permutations),
        swipeAwayDirectionGetter: (index) => AxisDirection.left,
        onSwipeAway: (index) {
          final item = _list.removeAt(index);
          if (item == _selectedItem) {
            setState(() => _selectedItem = null);
          }
        },
        listView: ListView.builder(
          shrinkWrap: true,
          itemCount: _list.length,
          itemBuilder: ((context, index) => _buildItem(_list[index])),
        ),
      );
}

typedef RemovedItemBuilder<T> = Widget Function(
    T item, BuildContext context, Animation<double> animation);

class ListModel<E extends HasId> {
  ListModel({
    required this.listKey,
    required this.insertedItemBuilder,
    required this.removedItemBuilder,
    Iterable<E>? initialItems,
  }) : _items = List<E>.from(initialItems ?? <E>[]);

  final GlobalKey<AnimatedReorderableState> listKey;
  final AnimatedItemBuilder insertedItemBuilder;
  final RemovedItemBuilder<E> removedItemBuilder;
  final List<E> _items;

  AnimatedReorderableState? get _animatedReorderableList =>
      listKey.currentState;

  void insert(int index, E item) {
    _items.insert(index, item);
    _animatedReorderableList!.insertItem(index, insertedItemBuilder);
  }

  E removeAt(int index) {
    final E removedItem = _items.removeAt(index);
    _animatedReorderableList!.removeItem(
      index,
      (BuildContext context, Animation<double> animation) =>
          removedItemBuilder(removedItem, context, animation),
    );
    return removedItem;
  }

  void move(int index, int destIndex) =>
      _animatedReorderableList!.moveItem(index, destIndex: destIndex);

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
        child: SizedBox(
          height: item.height,
          child: Card(
            color: Colors.primaries[item.id % Colors.primaries.length],
            child: Center(
              child: Text('$item', style: textStyle),
            ),
          ),
        ),
      ),
    );
  }
}
