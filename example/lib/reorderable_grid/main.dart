import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/material.dart';

import '../style/style.dart';
import 'shortcuts.dart';

void main() => runApp(
  MaterialApp(
    title: 'AnimatedReorderable Grid Example',
    debugShowCheckedModeBanner: false,
    theme: exampleTheme,
    home: const ReorderableGridExample(),
  ),
);

/// A grid of shortcuts: a long press drags one to a new place, across rows,
/// a swipe removes one, and Add shortcut adds one:
///
/// 1. [AnimatedReorderable.grid] wraps the [GridView], with a key for each
///    shortcut.
/// 2. [ReorderOptions.onReorder] puts the shortcuts in their new order as a
///    drag goes, and the others slide from cell to cell, across rows.
/// 3. [SwipeToRemoveOptions.onSwipeToRemove] removes a swiped shortcut, and
///    the ones after it slide back a cell.
/// 4. Add shortcut inserts one at the start, and the others slide along a
///    cell.
class ReorderableGridExample extends StatefulWidget {
  const ReorderableGridExample({super.key});

  @override
  State<ReorderableGridExample> createState() => _ReorderableGridExampleState();
}

class _ReorderableGridExampleState extends State<ReorderableGridExample> {
  final _gridKey = GlobalKey<AnimatedReorderableState>();
  final _shortcuts = [...kShortcuts];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Shortcuts')),
    // 4. A tap inserts the new shortcut at the start, once.
    bottomNavigationBar: AddShortcutBar(
      onPressed: () {
        if (_shortcuts.contains(kNewShortcut)) return;
        _shortcuts.insert(0, kNewShortcut);
        _gridKey.currentState!.insertItem(0);
      },
    ),
    // 1. The grid, wrapped.
    body: AnimatedReorderable.grid(
      key: _gridKey,
      keyGetter: (index) => ValueKey(_shortcuts[index].name),
      // 2. A long press drags a shortcut, and the others follow it.
      reorder: ReorderOptions(
        onReorder: (permutations) => permutations.apply(_shortcuts),
        decoration: const ItemDecoration(decorator: liftTile),
      ),
      // 3. A swipe removes the shortcut.
      swipeToRemove: SwipeToRemoveOptions(
        onSwipeToRemove: (index) {
          final shortcut = _shortcuts.removeAt(index);
          _gridKey.currentState!.removeItem(
            index,
            (context, animation) => FadeTransition(
              opacity: animation,
              child: ShortcutTile(shortcut),
            ),
          );
        },
      ),
      insertTransition: popIn,
      gridView: GridView.builder(
        padding: const EdgeInsets.all(S.s4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: S.s3,
          crossAxisSpacing: S.s3,
        ),
        itemCount: _shortcuts.length,
        itemBuilder: (context, index) => ShortcutTile(_shortcuts[index]),
      ),
    ),
  );
}
