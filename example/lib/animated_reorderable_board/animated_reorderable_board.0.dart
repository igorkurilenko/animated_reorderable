import 'dart:math' as math;

import 'package:animated_reorderable/animated_reorderable.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Flutter code sample of [AnimatedReorderableGroup]: a kanban board of a
/// team's tasks, as on GitHub. Cards are dragged within and between the
/// columns: at once with a mouse, and after a long press with a finger. A
/// task flies from its card to a done card, its title struck through, as it
/// goes into Done, and back as it leaves.

void main() {
  runApp(const AnimatedReorderableBoardSample());
}

class AnimatedReorderableBoardSample extends StatelessWidget {
  const AnimatedReorderableBoardSample({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0969DA),
        dynamicSchemeVariant: DynamicSchemeVariant.neutral,
      ),
    ),
    home: Scaffold(
      appBar: AppBar(title: const Text('Messenger · Sprint 14')),
      body: const KanbanBoard(),
    ),
  );
}

/// The board's columns, by the status of their tasks.
class KanbanBoard extends StatefulWidget {
  const KanbanBoard({super.key});

  @override
  State<KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> {
  final _board = {
    Status.todo: [
      Task(142, 'Show typing indicators in group chats', Teammate.anna, [
        Label.feature,
      ]),
      Task(
        155,
        'App crashes when opening a deleted voice message',
        Teammate.omar,
        [Label.bug],
      ),
      Task(151, 'Swipe right on a message to reply', Teammate.lena, [
        Label.feature,
        Label.design,
      ]),
      Task(147, 'Describe photos in chats for screen readers', Teammate.lena, [
        Label.accessibility,
      ]),
      Task(158, 'Link previews load twice on slow networks', Teammate.omar, [
        Label.bug,
        Label.performance,
      ]),
      Task(133, 'Mute a chat for 8 hours, a day or a week', Teammate.mike, [
        Label.feature,
      ]),
      Task(160, 'Archive a chat with a long press', Teammate.anna, [
        Label.feature,
      ]),
    ],
    Status.inProgress: [
      Task(128, 'Search the messages of a chat', Teammate.mike, [
        Label.feature,
      ]),
      Task(
        136,
        'Read receipts stop while the app is in the background',
        Teammate.omar,
        [Label.bug],
      ),
      Task(144, 'Redesign the attachment picker', Teammate.lena, [
        Label.design,
      ]),
    ],
    Status.done: [
      Task(117, 'Send photos in their original quality', Teammate.anna, [
        Label.feature,
      ]),
      Task(121, 'Pin up to three chats to the top', Teammate.mike, [
        Label.feature,
      ]),
      Task(
        125,
        'Unread badge stays after reading on another device',
        Teammate.omar,
        [Label.bug],
      ),
      Task(109, 'Dark theme for the chat list', Teammate.lena, [Label.design]),
    ],
  };

  @override
  Widget build(BuildContext context) => AnimatedReorderableGroup(
    // Moves a task from one column to another as it is dragged there. The
    // headers count the tasks again.
    onMove: (from, to) => setState(() {
      final task = _board[from.list]!.removeAt(from.index);
      _board[to.list]!.insert(to.index, task);
    }),
    // Screen readers move a task to another column too.
    moveToListLabel: (status) => 'Move to ${(status as Status).title}',
    child: LayoutBuilder(
      builder: (context, constraints) {
        // The columns share a wide window, and the board scrolls sideways
        // in a narrow one. It also scrolls while a card is held at its
        // edge.
        const padding = 12.0;
        final width = math.max(
          240.0,
          (constraints.maxWidth - (Status.values.length + 1) * padding) /
              Status.values.length,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(padding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: padding,
            children: [
              for (final status in Status.values)
                SizedBox(width: width, child: _column(status)),
            ],
          ),
        );
      },
    ),
  );

  Widget _column(Status status) {
    final colors = Theme.of(context).colorScheme;
    final border = Border.all(color: colors.outlineVariant);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: border,
      ),
      // Inside the border, so the cards scroll out of sight within it
      // rather than over it.
      child: Padding(
        padding: border.dimensions,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ColumnHeader(status: status, count: _board[status]!.length),
            Expanded(child: _tasks(status)),
          ],
        ),
      ),
    );
  }

  /// The column's tasks: cards, or done cards in Done.
  Widget _tasks(Status status) {
    final tasks = _board[status]!;
    return AnimatedReorderable.list(
      keyGetter: (index) => ValueKey(tasks[index].number),
      reorder: ReorderOptions(
        // The column's id in the group, which `onMove` gets.
        groupId: status,
        onReorder: (permutations) => permutations.apply(tasks),
        gestureRecognizerFactory: _dragRecognizer,
      ),
      listView: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        itemCount: tasks.length,
        itemBuilder: (context, index) => status == Status.done
            ? DoneTaskCard(task: tasks[index])
            : TaskCard(task: tasks[index]),
      ),
    );
  }
}

/// A card goes with the mouse at once, as on GitHub's boards. A finger
/// holds it a moment first, so that a swipe still scrolls its column.
MultiDragGestureRecognizer _dragRecognizer(BuildContext context) =>
    switch (Theme.of(context).platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => DelayedMultiDragGestureRecognizer(),
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => ImmediateMultiDragGestureRecognizer(),
    }..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);

enum Status {
  todo('To do', Color(0xFF1A7F37)),
  inProgress('In progress', Color(0xFFBF8700)),
  done('Done', Color(0xFF8250DF));

  const Status(this.title, this.color);

  final String title;
  final Color color;
}

enum Label {
  bug(Color(0xFFD1242F)),
  feature(Color(0xFF0969DA)),
  design(Color(0xFFBF3989)),
  accessibility(Color(0xFF1A7F37)),
  performance(Color(0xFFBC4C00));

  const Label(this.color);

  final Color color;
}

enum Teammate {
  anna('AK', Color(0xFF6E40C9)),
  mike('MS', Color(0xFF0969DA)),
  lena('LT', Color(0xFFBF3989)),
  omar('OH', Color(0xFF1A7F37));

  const Teammate(this.initials, this.color);

  final String initials;
  final Color color;
}

class Task {
  Task(this.number, this.title, this.assignee, this.labels);

  /// The number of the task's issue.
  final int number;
  final String title;
  final Teammate assignee;
  final List<Label> labels;
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.status, required this.count});

  final Status status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        spacing: 8,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: status.color.withValues(alpha: 0.15),
              border: Border.all(color: status.color, width: 2),
            ),
            child: const SizedBox.square(dimension: 12),
          ),
          Flexible(
            child: Text(
              status.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          _Pill(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Text('$count', style: theme.textTheme.labelMedium),
          ),
        ],
      ),
    );
  }
}

/// A task as a card, in the columns of tasks to do and in progress.
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Row(
                spacing: 6,
                children: [
                  // An open issue.
                  Icon(Icons.adjust, size: 16, color: Status.todo.color),
                  Expanded(
                    child: Text(
                      'messenger #${task.number}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _Avatar(task.assignee),
                ],
              ),
              Text(
                task.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [for (final label in task.labels) _LabelChip(label)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A task as a done card, its title struck through, in the column of tasks
/// done.
class DoneTaskCard extends StatelessWidget {
  const DoneTaskCard({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            spacing: 8,
            children: [
              // A completed issue.
              Icon(Icons.check_circle, size: 16, color: Status.done.color),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: muted,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: muted,
                  ),
                ),
              ),
              Text(
                '#${task.number}',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip(this.label);

  final Label label;

  @override
  Widget build(BuildContext context) => _Pill(
    color: label.color.withValues(alpha: 0.1),
    border: label.color.withValues(alpha: 0.4),
    child: Text(
      label.name,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: label.color, fontWeight: FontWeight.w600),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.teammate);

  final Teammate teammate;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 11,
    backgroundColor: teammate.color,
    foregroundColor: Colors.white,
    child: Text(
      teammate.initials,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, this.border, required this.child});

  final Color color;
  final Color? border;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
      border: border == null ? null : Border.all(color: border!),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      child: child,
    ),
  );
}
