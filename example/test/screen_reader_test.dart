import 'package:example/animated_reorderable_board/animated_reorderable_board.0.dart'
    as board;
import 'package:example/animated_reorderable_grid/animated_reorderable_grid.0.dart'
    as grid;
import 'package:example/animated_reorderable_list/animated_reorderable_list.0.dart'
    as list;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A screen reader picks what a finger touches by a rule of its own, which
/// these tests follow, so a touch on an item finds the moves it can make.
void main() {
  testWidgets("a touch on a list's item finds its moves", (tester) async {
    await tester.pumpWidget(const list.AnimatedReorderableListSample());

    final moves = _movesAt(tester, tester.getCenter(find.text('Item 1')));

    expect(moves, [
      'Move to the start',
      'Move up',
      'Move down',
      'Move to the end',
    ]);
  });

  testWidgets("a touch on a grid's cell finds its moves, a row down too", (
    tester,
  ) async {
    await tester.pumpWidget(const grid.AnimatedReorderableGridSample());

    final moves = _movesAt(tester, tester.getCenter(find.text('Item 1')));

    expect(moves, [
      'Move to the start',
      'Move left',
      'Move right',
      'Move down',
      'Move to the end',
    ]);
  });

  testWidgets("a touch on a board's card finds its moves to the other "
      'columns', (tester) async {
    await tester.pumpWidget(const board.AnimatedReorderableBoardSample());

    final moves = _movesAt(
      tester,
      tester.getCenter(find.text('Show typing indicators in group chats')),
    );

    expect(moves, [
      'Move down',
      'Move to the end',
      'Move to In progress',
      'Move to Done',
    ]);
  });

  testWidgets('a card a screen reader moves to a column out of sight takes '
      'the focus there, in sight', (tester) async {
    // An iPhone 17 Pro's screen, on which Done is out of sight.
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const title = 'Show typing indicators in group chats';
    // The node each focus goes to, and whether it was out of sight then.
    final focused = <(int, bool)>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        if (message case {'type': 'focus', 'nodeId': final int id}) {
          final card = tester.getSemantics(find.text(title));
          focused.add((id, card.getSemanticsData().flagsCollection.isHidden));
        }
        return null;
      },
    );
    addTearDown(
      () => messenger.setMockDecodedMessageHandler<Object?>(
        SystemChannels.accessibility,
        null,
      ),
    );
    await tester.pumpWidget(const board.AnimatedReorderableBoardSample());

    final node = tester.getSemantics(find.text(title));
    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      CustomSemanticsAction.getIdentifier(
        const CustomSemanticsAction(label: 'Move to Done'),
      ),
    );
    await tester.pumpAndSettle();

    expect(focused, [(tester.getSemantics(find.text(title)).id, false)]);
    final rect = tester.getRect(find.text(title));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(402));
  });
}

/// The labels of the moves of what a screen reader picks as a finger
/// touches [point], in the order it lists them.
List<String> _movesAt(WidgetTester tester, Offset point) => [
  for (final id
      in _touched(tester, point)?.getSemanticsData().customSemanticsActionIds ??
          const <int>[])
    CustomSemanticsAction.getAction(id)!.label!,
];

/// The node VoiceOver picks as a finger touches [point], as Flutter's iOS
/// embedder finds it: the deepest node there, in hit test order, that has a
/// label, a value, a hint or an action other than scrolling.
SemanticsNode? _touched(WidgetTester tester, Offset point) {
  // The nodes' rects come to the platform in pixels.
  final pixel = point * tester.view.devicePixelRatio;
  SemanticsNode? search(SemanticsNode node, Matrix4 transform) {
    for (final child in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.inverseHitTest,
    )) {
      final childTransform = switch (child.transform) {
        final own? => transform.multiplied(own),
        null => transform,
      };
      if (MatrixUtils.transformRect(
        childTransform,
        child.rect,
      ).contains(pixel)) {
        if (search(child, childTransform) case final found?) return found;
      }
    }
    return MatrixUtils.transformRect(transform, node.rect).contains(pixel) &&
            _focusable(node.getSemanticsData())
        ? node
        : null;
  }

  final view = tester.binding.renderViews.single;
  final root = view.owner!.semanticsOwner!.rootSemanticsNode!;
  return search(root, Matrix4.identity());
}

bool _focusable(SemanticsData data) {
  final scrolling = [
    SemanticsAction.scrollUp,
    SemanticsAction.scrollDown,
    SemanticsAction.scrollLeft,
    SemanticsAction.scrollRight,
  ].fold(0, (all, action) => all | action.index);
  return data.label.isNotEmpty ||
      data.value.isNotEmpty ||
      data.hint.isNotEmpty ||
      data.actions & ~scrolling != 0 ||
      (data.flagsCollection.hasImplicitScrolling &&
          data.flagsCollection.isHidden);
}
