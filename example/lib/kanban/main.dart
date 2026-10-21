import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/material.dart';

import '../style/style.dart';
import 'board.dart';

void main() => runApp(const KanbanExample());

class KanbanExample extends StatelessWidget {
  const KanbanExample({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AnimatedReorderable Kanban Example',
    debugShowCheckedModeBanner: false,
    theme: exampleTheme,
    home: Scaffold(
      appBar: AppBar(title: const Text('Messenger · Sprint 14')),
      body: const KanbanBoard(),
    ),
  );
}

/// A kanban board of a team's tasks: cards are dragged within and between
/// the columns, at once with a mouse and after a long press with a finger:
///
/// 1. An [AnimatedReorderableGroup] wraps the columns.
/// 2. Each column is an [AnimatedReorderable.list], with its status as its
///    [ReorderOptions.groupId].
/// 3. [AnimatedReorderableGroup.onMove] moves a task to the column it's
///    dragged to.
/// 4. Done builds done cards, so a task flies from its card to a done card as
///    it goes into Done, and back as it leaves.
/// 5. [AnimatedReorderableGroup.moveToListLabel] lets screen readers move a
///    task to another column.
class KanbanBoard extends StatefulWidget {
  const KanbanBoard({super.key});

  @override
  State<KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> {
  final _board = initialBoard();

  @override
  Widget build(BuildContext context) => AnimatedReorderableGroup(
    // 3. Moves a task to the column it's dragged to. The headers count the
    // tasks again.
    onMove: (from, to) => setState(() {
      final task = _board[from.list]!.removeAt(from.index);
      _board[to.list]!.insert(to.index, task);
    }),
    // 5. Screen readers move a task to another column too.
    moveToListLabel: (status) => 'Move to ${(status as Status).title}',
    // 1. The group, around the columns.
    child: BoardLayout(
      columns: [
        for (final status in Status.values)
          BoardColumn(
            status: status,
            count: _board[status]!.length,
            tasks: _tasks(status),
          ),
      ],
    ),
  );

  /// 2. A column's tasks, dragged within it and to the other columns.
  Widget _tasks(Status status) {
    final tasks = _board[status]!;
    return AnimatedReorderable.list(
      keyGetter: (index) => ValueKey(tasks[index].number),
      reorder: ReorderOptions(
        // The column's id in the group, which onMove gets.
        groupId: status,
        onReorder: (moves) => moves.apply(tasks),
        // A mouse drags a card at once, and a finger after a long press.
        gestureRecognizerFactory: dragRecognizer,
        decoration: const ItemDecoration(decorator: liftTask),
      ),
      listView: ListView.builder(
        padding: const EdgeInsets.fromLTRB(S.s2, 0, S.s2, S.s2),
        itemCount: tasks.length,
        // 4. Cards, or done cards in Done.
        itemBuilder: (context, index) => status == Status.done
            ? DoneTaskCard(task: tasks[index])
            : TaskCard(task: tasks[index]),
      ),
    );
  }
}
