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

enum Label {
  bug(Color(0xFFF5DCE4)),
  feature(Color(0xFFD6E6F5)),
  design(Color(0xFFFFE6C7)),
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

class Task {
  Task(this.number, this.title, this.assignee, this.labels);

  /// The number of the task's issue.
  final int number;
  final String title;
  final Teammate assignee;
  final List<Label> labels;
}

/// The tasks the board starts with, by column.
Map<Status, List<Task>> initialBoard() => {
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
    Task(128, 'Search the messages of a chat', Teammate.mike, [Label.feature]),
    Task(
      136,
      'Read receipts stop while the app is in the background',
      Teammate.omar,
      [Label.bug],
    ),
    Task(144, 'Redesign the attachment picker', Teammate.lena, [Label.design]),
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

/// The board's [columns], side by side: they share a wide window, and the
/// board scrolls sideways in a narrow one, also while a card is held at its
/// edge.
class BoardLayout extends StatelessWidget {
  const BoardLayout({super.key, required this.columns});

  final List<Widget> columns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.max(
        240.0,
        (constraints.maxWidth - (columns.length + 1) * S.s3) / columns.length,
      );
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(S.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: S.s3,
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(R.xl),
      child: ColoredBox(
        color: theme.colorScheme.surfaceContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
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
            ),
            Expanded(child: tasks),
          ],
        ),
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
          Text(
            '#${task.number}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
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
