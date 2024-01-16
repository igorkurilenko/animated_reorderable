### List Example 
```dart
import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/material.dart';

import 'dart:math';

/// Flutter code sample of [AnimatedReorderable] wrapping [ListView].

void main() {
  runApp(const AnimatedReorderableListSample());
}

class AnimatedReorderableListSample extends StatefulWidget {
  const AnimatedReorderableListSample({super.key});

  @override
  State<AnimatedReorderableListSample> createState() =>
      _AnimatedReorderableListSampleState();
}

class _AnimatedReorderableListSampleState
    extends State<AnimatedReorderableListSample> {
  final _animatedReorderableKey = GlobalKey<AnimatedReorderableState>();
  late final ListModel<Item> _list;
  Item? _selectedItem;
  late int
      _nextItemId; // The next item id inserted when the user presses the '+' button.

  @override
  void initState() {
    super.initState();
    _list = ListModel<Item>(
      animatedReorderableKey: _animatedReorderableKey,
      initialItems: List.generate(4, (i) => _createItem(i)),
      insertedItemBuilder: _buildInsertedItem,
      removedItemBuilder: _buildRemovedItem,
    );
    _nextItemId = 4;
  }

  Item _createItem(int id) => Item.withRandomHeight(
        id,
        minHeight: 80.0,
        maxHeight: 200.0,
      );

  // Used to build list items.
  Widget _buildItem(Item item) => CardItem(
        item: item,
        selected: _selectedItem == item,
        onTap: () {
          setState(() {
            _selectedItem = _selectedItem == item ? null : item;
          });
        },
      );

  // Used to build list items that have been inserted.
  ///
  /// Used to build an item after it has been inserted into the list.
  /// The widget will be used by the [AnimatedReorderableState.insertItem] method's
  /// [AnimatedItemBuilder] parameter.
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

  /// The builder function used to build grid items that have been removed.
  ///
  /// Used to build an item after it has been removed from the list. This method
  /// is needed because a removed item remains visible until its animation has
  /// completed (even though it's gone as far as this ListModel is concerned).
  /// The widget will be used by the [AnimatedReorderableState.removeItem] method's
  /// [AnimatedRemovedItemBuilder] parameter.
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

  // Insert the "next item" into the list model.
  void _insert() {
    final int index =
        _selectedItem == null ? _list.length : _list.indexOf(_selectedItem!);
    _list.insert(index, _createItem(_nextItemId++));
  }

  // Reorder the selected or random item in the list model.
  void _reorder() {
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

    _list.reorder(index, destIndex);
  }

  // Remove the selected or last item from the list model.
  void _remove() {
    final int index = _selectedItem == null
        ? _list.length - 1
        : _list.indexOf(_selectedItem!);
    final item = _list.removeAt(index);
    if (item == _selectedItem) {
      setState(() => _selectedItem = null);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('AnimatedReorderable'),
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.add_circle),
                onPressed: _insert,
                tooltip: 'insert a new item',
              ),
              IconButton(
                icon: const Icon(Icons.swap_calls),
                onPressed: _reorder,
                tooltip: 'reorder randomly',
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle),
                onPressed: _remove,
                tooltip: 'remove the selected or last item',
              ),
            ],
          ),
          body: AnimatedReorderable.list(
            key: _animatedReorderableKey,
            keyGetter: (index) => ValueKey(_list[index]),
            onReorder: (permutations) => _list.onReorder(permutations),
            onSwipeToRemove: (index) {
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
          ),
        ),
      );
}

typedef RemovedItemBuilder<T> = Widget Function(
    T item, BuildContext context, Animation<double> animation);

/// Keeps a Dart [List] in sync with an [AnimatedReorderable].
///
/// The [insert], [removeAt] and [reorder] methods apply to both the internal list and
/// the [AnimatedReorderable] that belongs to [animatedReorderableKey].
class ListModel<E> {
  ListModel({
    required this.animatedReorderableKey,
    required this.insertedItemBuilder,
    required this.removedItemBuilder,
    Iterable<E>? initialItems,
  }) : _items = List<E>.from(initialItems ?? <E>[]);

  final GlobalKey<AnimatedReorderableState> animatedReorderableKey;
  final AnimatedItemBuilder insertedItemBuilder;
  final RemovedItemBuilder<E> removedItemBuilder;
  final List<E> _items;

  AnimatedReorderableState? get _animatedReorderableList =>
      animatedReorderableKey.currentState;

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

  void reorder(int index, int destIndex) =>
      _animatedReorderableList!.reorderItem(index, destIndex: destIndex);

  void onReorder(Permutations permutations) => permutations.apply(_items);

  int get length => _items.length;

  E operator [](int index) => _items[index];

  int indexOf(E item) => _items.indexOf(item);
}

/// Displays its integer item as 'Item N' on a Card whose color is based on
/// the item's value. Item's heigth is random and varies from 80 to 200.
///
/// The text is displayed in bright green if [selected] is true. 
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

class Item {
  final int id;
  final double? height;

  Item(
    this.id, {
    this.height,
  });

  Item.withRandomHeight(
    this.id, {
    required double minHeight,
    required double maxHeight,
  }) : height = Random().nextDoubleInRange(minHeight, maxHeight);

  @override
  String toString() => 'Item $id';
}

extension _RandomExtension on Random {
  double nextDoubleInRange(double min, double max) =>
      min + nextDouble() * (max - min);
}
```
### Grid Example
```dart
import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/material.dart';

/// Flutter code sample of [AnimatedReorderable] wrapping [GridView].

void main() {
  runApp(const AnimatedReorderableGridSample());
}

class AnimatedReorderableGridSample extends StatefulWidget {
  const AnimatedReorderableGridSample({super.key});

  @override
  State<AnimatedReorderableGridSample> createState() =>
      _AnimatedReorderableGridSampleState();
}

class _AnimatedReorderableGridSampleState
    extends State<AnimatedReorderableGridSample> {
  final _animatedReorderableKey = GlobalKey<AnimatedReorderableState>();
  late final ListModel<Item> _list;
  Item? _selectedItem;
  late int _nextItemId; // The next item id inserted when the user presses the '+' button.

  @override
  void initState() {
    super.initState();
    _list = ListModel<Item>(
      animatedReorderableKey: _animatedReorderableKey,
      initialItems: List.generate(6, (i) => Item(i)),
      insertedItemBuilder: _buildInsertedItem,
      removedItemBuilder: _buildRemovedItem,
    );
    _nextItemId = 6;
  }

  // Used to build list items.
  Widget _buildItem(Item item) => CardItem(
        item: item,
        selected: _selectedItem == item,
        onTap: () {
          setState(() {
            _selectedItem = _selectedItem == item ? null : item;
          });
        },
      );

  // Used to build list items that have been inserted.
  ///
  /// Used to build an item after it has been inserted into the list.
  /// The widget will be used by the [AnimatedReorderableState.insertItem] method's
  /// [AnimatedItemBuilder] parameter.
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

  /// The builder function used to build list items that have been removed.
  ///
  /// Used to build an item after it has been removed from the list. This method
  /// is needed because a removed item remains visible until its animation has
  /// completed (even though it's gone as far as this ListModel is concerned).
  /// The widget will be used by the [AnimatedReorderableState.removeItem] method's
  /// [AnimatedRemovedItemBuilder] parameter.
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

  // Insert the "next item" into the list model.
  void _insert() {
    final int index =
        _selectedItem == null ? _list.length : _list.indexOf(_selectedItem!);
    _list.insert(index, Item(_nextItemId++));
  }

  // Reorder the selected or random item in the list model.
  void _reorder() {
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

    _list.reorder(index, destIndex);
  }

  // Remove the selected or last item from the list model.
  void _remove() {
    final int index = _selectedItem == null
        ? _list.length - 1
        : _list.indexOf(_selectedItem!);
    final item = _list.removeAt(index);
    if (item == _selectedItem) {
      setState(() => _selectedItem = null);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('AnimatedReorderable'),
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.add_circle),
                onPressed: _insert,
                tooltip: 'insert a new item',
              ),
              IconButton(
                icon: const Icon(Icons.swap_calls),
                onPressed: _reorder,
                tooltip: 'reorder randomly',
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle),
                onPressed: _remove,
                tooltip: 'remove the selected or last item',
              ),
            ],
          ),
          body: AnimatedReorderable.grid(
            key: _animatedReorderableKey,
            keyGetter: (index) => ValueKey(_list[index]),
            onReorder: (permutations) => _list.onReorder(permutations),
            onSwipeToRemove: (index) {
              final item = _list.removeAt(index);
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
              itemCount: _list.length,
              itemBuilder: ((context, index) => _buildItem(_list[index])),
            ),
          ),
        ),
      );
}

typedef RemovedItemBuilder<T> = Widget Function(
    T item, BuildContext context, Animation<double> animation);

/// Keeps a Dart [List] in sync with an [AnimatedReorderable].
///
/// The [insert], [removeAt] and [reorder] methods apply to both the internal list and
/// the [AnimatedReorderable] that belongs to [animatedReorderableKey].
class ListModel<E> {
  ListModel({
    required this.animatedReorderableKey,
    required this.insertedItemBuilder,
    required this.removedItemBuilder,
    Iterable<E>? initialItems,
  }) : _items = List<E>.from(initialItems ?? <E>[]);

  final GlobalKey<AnimatedReorderableState> animatedReorderableKey;
  final AnimatedItemBuilder insertedItemBuilder;
  final RemovedItemBuilder<E> removedItemBuilder;
  final List<E> _items;

  AnimatedReorderableState? get _animatedReorderableGrid =>
      animatedReorderableKey.currentState;

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

  void reorder(int index, int destIndex) =>
      _animatedReorderableGrid!.reorderItem(index, destIndex: destIndex);

  void onReorder(Permutations permutations) => permutations.apply(_items);

  int get length => _items.length;

  E operator [](int index) => _items[index];

  int indexOf(E item) => _items.indexOf(item);
}

/// Displays its integer item as 'Item N' on a Card whose color is based on
/// the item's value. 
///
/// The text is displayed in bright green if [selected] is true. 
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

class Item {
  final int id;

  Item(this.id);

  @override
  String toString() => 'Item $id';
}
```