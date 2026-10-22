// What the kanban example looks like, apart from the board's lists, which
// main.dart builds: the tasks, the columns and their cards.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../style/style.dart';

/// The board's columns, by the status of their tasks.
enum Status {
  todo('To do', Color(0xFF8C8C8C)),
  inProgress('In progress', Color(0xFFE0A100)),
  done('Done', Color(0xFF2DA44E));

  const Status(this.title, this.color);

  final String title;

  /// The color of the column's dot.
  final Color color;
}

/// What a task's feature is about, on a chip of its tint.
enum Label {
  gestures(Color(0xFFF5DCE4)),
  animation(Color(0xFFD6E6F5)),
  grid(Color(0xFFFFE6C7)),
  accessibility(Color(0xFFD9EED9)),
  performance(Color(0xFFE8E0F5));

  const Label(this.tint);

  final Color tint;
}

enum Teammate {
  anna('AK', Color(0xFFE8E0F5)),
  mike('MS', Color(0xFFD6E6F5)),
  lena('LT', Color(0xFFF5DCE4)),
  omar('OH', Color(0xFFD9EED9));

  const Teammate(this.initials, this.tint);

  final String initials;
  final Color tint;
}

/// A task of the board: one of animated_reorderable's features.
class Task {
  Task(this.number, this.title, this.api, this.assignee, this.labels);

  /// The task's number, which keys its card.
  final int number;
  final String title;

  /// The part of animated_reorderable's API that the feature is in.
  final String api;
  final Teammate assignee;
  final List<Label> labels;
}

/// The tasks the board starts with, by column.
Map<Status, List<Task>> initialBoard() => {
  Status.todo: [
    Task(
      1,
      'Drag and drop between lists and grids',
      'AnimatedReorderableGroup',
      Teammate.anna,
      [Label.gestures],
    ),
    Task(
      2,
      'Swipe an item away to delete it',
      'SwipeToRemoveOptions',
      Teammate.omar,
      [Label.gestures],
    ),
    Task(
      3,
      'Reorder a grid by drag and drop, across its rows',
      'AnimatedReorderable.grid',
      Teammate.lena,
      [Label.grid, Label.gestures],
    ),
    Task(
      4,
      'Move items with a screen reader',
      'ReorderOptions.onReorder',
      Teammate.lena,
      [Label.accessibility],
    ),
    Task(
      5,
      'Build only the items a drag passes',
      'AnimatedReorderable',
      Teammate.mike,
      [Label.performance],
    ),
    Task(
      6,
      'Keep some items from being dragged',
      'ReorderOptions.draggableGetter',
      Teammate.omar,
      [Label.gestures],
    ),
    Task(
      7,
      'Start a drag at once, or after a long press',
      'ReorderOptions.gestureRecognizerFactory',
      Teammate.anna,
      [Label.gestures],
    ),
  ],
  Status.inProgress: [
    Task(8, 'Animate an insert', 'insertItem', Teammate.mike, [
      Label.animation,
    ]),
    Task(9, 'Animate a removal', 'removeItem', Teammate.omar, [
      Label.animation,
    ]),
    Task(10, 'Animate a reorder made in code', 'reorderItem', Teammate.lena, [
      Label.animation,
    ]),
  ],
  Status.done: [
    Task(
      11,
      "Change an item's look as it flies to another list",
      'FlightOptions',
      Teammate.mike,
      [Label.animation],
    ),
    Task(
      12,
      'Lift a held item in a look of your own',
      'ItemDecoration',
      Teammate.omar,
      [Label.animation],
    ),
    Task(
      13,
      'Slide items out of the way, on your own curve',
      'MotionOptions',
      Teammate.anna,
      [Label.animation],
    ),
    Task(
      14,
      'Spring a dropped item back into its place',
      'ReorderOptions.springDescription',
      Teammate.lena,
      [Label.animation],
    ),
  ],
};

/// A column's narrowest width: in a window too narrow for every column at
/// it, the board scrolls.
const _minColumnWidth = 240.0;

/// The space between the columns, and around them.
const _columnGap = S.s3;

/// The board's [columns], side by side: they share a wide window, and the
/// board scrolls sideways in a narrow one, also while a card is held at its
/// edge.
class BoardLayout extends StatelessWidget {
  const BoardLayout({super.key, required this.columns});

  final List<Widget> columns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final gaps = (columns.length + 1) * _columnGap;
      final width = math.max(
        _minColumnWidth,
        (constraints.maxWidth - gaps) / columns.length,
      );
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(_columnGap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: _columnGap,
          children: [
            for (final column in columns) SizedBox(width: width, child: column),
          ],
        ),
      );
    },
  );
}

/// A column of the board: its title and how many tasks it has, over its
/// [tasks], which scroll within its corners.
class BoardColumn extends StatelessWidget {
  const BoardColumn({
    super.key,
    required this.status,
    required this.count,
    required this.tasks,
  });

  final Status status;
  final int count;
  final Widget tasks;

  @override
  Widget build(BuildContext context) => ClipRSuperellipse(
    borderRadius: BorderRadius.circular(R.xl),
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ColumnHeader(status: status, count: count),
          Expanded(child: tasks),
        ],
      ),
    ),
  );
}

/// A column's header: its status's dot and title, and how many tasks it
/// has.
class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.status, required this.count});

  final Status status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.s4, S.s4, S.s4, S.s2),
      child: Row(
        spacing: S.s2,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: status.color,
            ),
            child: const SizedBox.square(dimension: 10),
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
    return _CardSurface(
      color: colors.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: S.s2,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.api,
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
              height: 1.4,
            ),
          ),
          Wrap(
            spacing: S.s1,
            runSpacing: S.s1,
            children: [for (final label in task.labels) _LabelChip(label)],
          ),
        ],
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
    return _CardSurface(
      color: colors.surfaceContainerLow,
      child: Row(
        spacing: S.s2,
        children: [
          Unicon(UniconData.done, size: S.s4, color: Status.done.color),
          Expanded(
            child: Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: muted,
                height: 1.4,
                decoration: TextDecoration.lineThrough,
                decorationColor: muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The space between a column's cards, around each card.
const _cardMargin = EdgeInsets.symmetric(vertical: S.s1);

/// A card's surface, in [color], under its [child]: the cards' squircle,
/// with a hairline edge, inside [_cardMargin].
class _CardSurface extends StatelessWidget {
  const _CardSurface({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: _cardMargin,
    child: DecoratedBox(
      decoration: ShapeDecoration(
        color: color,
        shape: squircle(
          R.lg,
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(S.s3), child: child),
    ),
  );
}

/// A held card rises off the board: it grows a little and casts a shadow,
/// and stays opaque, so the cards under it don't show through it.
Widget liftTask(Widget child, int index, Animation<double> animation) => Lift(
  animation: animation,
  scale: 1.03,
  shadow: const BoxShadow(
    color: Color(0x29000000),
    blurRadius: 18,
    offset: Offset(0, 8),
  ),
  margin: _cardMargin,
  child: child,
);

/// A card goes with the mouse at once. A finger holds it a moment first, so
/// that a swipe still scrolls its column.
MultiDragGestureRecognizer dragRecognizer(BuildContext context) =>
    switch (Theme.of(context).platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => DelayedMultiDragGestureRecognizer(),
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => ImmediateMultiDragGestureRecognizer(),
    }..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);

class _LabelChip extends StatelessWidget {
  const _LabelChip(this.label);

  final Label label;

  @override
  Widget build(BuildContext context) => _Pill(
    color: label.tint,
    child: Text(label.name, style: Theme.of(context).textTheme.labelSmall),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.teammate);

  final Teammate teammate;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(shape: BoxShape.circle, color: teammate.tint),
    child: SizedBox.square(
      dimension: S.s6,
      child: Center(
        child: Text(
          teammate.initials,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(fontSize: 9, fontWeight: FontWeight.w600),
        ),
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: S.s2, vertical: 1),
      child: child,
    ),
  );
}
