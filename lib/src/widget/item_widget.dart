import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../const.dart';
import '../model/model.dart'
    show GlobalOffset, ItemMotion, OverlayOffset, RenderedItem;
import '../model/swipe_direction.dart';
import '../util/geometry.dart';
import 'ink_surface.dart';

/// An edge of the view along its scroll axis: the leading one, where the
/// list starts, or the trailing one.
enum ViewEdge { leading, trailing }

/// A move a screen reader can make with an item: to the start, one place
/// back or forward, or to the end, and in a grid one row back or forward.
enum SemanticMove { toStart, back, forward, toEnd, rowBack, rowForward }

/// Whether a screen reader can move an item back, towards the start, and
/// forward, towards the end, by a place, and in a grid by a row.
typedef SemanticMoves = ({
  bool back,
  bool forward,
  bool rowBack,
  bool rowForward,
  ListMoves toLists,
});

/// The moves a screen reader can make with an item to the other lists of
/// its group: the id of each list, and the label of the move to it. Two
/// are equal when they hold the same moves, so an item that keeps its
/// moves doesn't build again.
@immutable
class ListMoves {
  const ListMoves(this.moves, {this.labels = const []});

  static const none = ListMoves([]);

  final List<({Object list, String label})> moves;

  /// The labels of the moves to all the lists of the group, the item's own
  /// among them, in the order of the tree, which [moves] follow.
  final List<String> labels;

  @override
  bool operator ==(Object other) =>
      other is ListMoves &&
      listEquals(moves, other.moves) &&
      listEquals(labels, other.labels);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(moves), Object.hashAll(labels));
}

/// What an item widget asks of the controller, and what it tells it.
abstract interface class ItemHost {
  bool isReorderable(int index);
  bool isDraggable(int index);
  SwipeDirection? swipeToRemoveDirectionAt(int index);

  /// Puts [child], the subtree of the item at [index], in the transition
  /// the item enters with, at [entrance].
  Widget buildEntrance(Widget child, int index, Animation<double> entrance);

  void didInitItem(RenderedItem item);
  void didChangeItemIndex(RenderedItem item);

  /// Called while [item] builds. The host waits for the frame to lay it
  /// out before it looks at it.
  void didBuildItem(RenderedItem item);
  void didDeactivateItem(RenderedItem item);
  void recognizeReorderDrag(RenderedItem item, PointerDownEvent event);
  void recognizeSwipe(RenderedItem item, PointerDownEvent event);

  /// How an item moves to its new slot.
  Duration get motionDuration;
  Curve get motionCurve;

  /// How far, in pixels, the frame moves the view's scroll offset as it
  /// lays out a change, like one that shrinks the list under its offset,
  /// or zero.
  double get scrollAdjustment;

  /// The edge of the view that the item with [key] comes in through, once,
  /// if a change brought it into sight from out of it.
  ViewEdge? takeEntry(Key key);

  /// The semantic index of [child], the item at [index], as the view's
  /// delegate gives it, or null for none.
  int? semanticIndexOf(Widget child, int index);

  /// Whether the items are a grid's, where the next item is along the row
  /// rather than along the scroll axis.
  bool get isGrid;

  /// The moves a screen reader can make with the item at [index].
  SemanticMoves semanticMovesAt(int index);

  /// Makes [move] with the item at [index], if the item can still make it.
  void makeSemanticMove(int index, SemanticMove move);

  /// Moves the item at [index] to the list of its group with the id
  /// [list], as a screen reader does, if the item can still go there.
  void moveToList(int index, Object list);
}

class ItemWidget extends StatefulWidget {
  const ItemWidget({
    required super.key,
    required this.index,
    required this.childKey,
    required this.builder,
    required this.placeholderSize,
    required this.entrance,
    required this.semanticMoves,
    required this.host,
  });

  final int index;
  final GlobalKey childKey;
  final NullableIndexedWidgetBuilder builder;

  /// The size of the placeholder that stands in for the item while the
  /// overlay shows it, or null.
  final ValueListenable<Size?> placeholderSize;

  /// How far the item has entered.
  final Animation<double> entrance;

  /// The moves a screen reader can make with the item.
  final SemanticMoves semanticMoves;
  final ItemHost host;

  @override
  State<ItemWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<ItemWidget>
    with TickerProviderStateMixin
    implements RenderedItem {
  /// Where the item shows as it moves in place, in the coordinates of the
  /// view's content, which stay as it scrolls. It is created on the item's
  /// first move.
  ItemMotion? _motion;
  _RenderInPlace? _inPlace;
  ScrollPosition? _scrollPosition;

  /// Where the item showed before its slot moved, until the frame lays it
  /// out in its new slot.
  Offset? _shownBeforeMove;

  /// The node of the item's moves, which a screen reader can focus.
  final _semanticMovesKey = GlobalKey(debugLabel: 'semantic moves');

  /// How far the item shows from its slot.
  var _translation = Offset.zero;

  ItemHost get host => widget.host;
  @override
  int get index => widget.index;
  @override
  Key get key => widget.key!;
  @override
  bool get reorderable => host.isReorderable(index);
  bool get draggable => host.isDraggable(index);
  @override
  SwipeDirection? get swipeToRemoveDirection =>
      host.swipeToRemoveDirectionAt(index);
  bool get swipeable => swipeToRemoveDirection != null;
  @override
  GlobalOffset? get globalPosition => switch (findRenderBox()) {
    final box? => GlobalOffset(box.localToGlobal(Offset.zero)),
    null => null,
  };
  @override
  GlobalOffset? get shownPosition => switch (globalPosition) {
    final position? => GlobalOffset(position + _translation),
    null => null,
  };
  @override
  Size? get size => findRenderBox()?.size;

  @override
  BoxConstraints? get constraints {
    final renderBox = findRenderBox();
    return renderBox != null && renderBox.hasSize
        ? renderBox.constraints
        : null;
  }

  @override
  bool get keptAlive => switch (_inPlace?.parentData) {
    final SliverMultiBoxAdaptorParentData data => data.keptAlive,
    _ => false,
  };

  @override
  void focusSemanticMoves() {
    final moves = _semanticMovesKey.currentContext?.findRenderObject();
    if (moves == null) return;
    // A screen reader focuses only what shows, and the item may be out of
    // sight, as in a column of a board that scrolls sideways. It scrolls
    // into sight first, and takes the focus once the platform has it there.
    moves.showOnScreen();
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (moves.attached) {
          moves.sendSemanticsEvent(const FocusSemanticEvent());
        }
      })
      ..scheduleFrame();
  }

  @override
  bool contains(GlobalOffset point) =>
      findRenderBox()?.getGeometry().contains(point) ?? false;

  @override
  void initState() {
    super.initState();
    widget.placeholderSize.addListener(_rebuild);
    host.didInitItem(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollPosition = Scrollable.maybeOf(context)?.position;
  }

  @override
  void willMove() {
    final box = _inPlace;
    if (box == null || !box.attached || !box.hasSize) return;
    // Another change in the same frame finds it where the first did: the
    // list hasn't laid it out again in between.
    _shownBeforeMove ??= _contentPosition(box) + _translation;
    box.markNeedsCompositedLayerUpdate();
  }

  @override
  void willShift() {
    final box = _inPlace;
    // A placeholder shows nothing to move.
    if (box == null || !box.attached || widget.placeholderSize.value != null) {
      return;
    }
    box.markNeedsCompositedLayerUpdate();
  }

  /// Where [box] is laid out, in the coordinates of the view's content.
  Offset _contentPosition(RenderBox box) {
    final global = box.localToGlobal(Offset.zero);
    final scroll = _scrollPosition;
    if (scroll == null || !scroll.hasPixels) return global;
    return global + scroll.toRelativeOffset();
  }

  /// A scroll offset of [pixels], in the coordinates of the view's content.
  Offset _contentOffset(double pixels) =>
      _scrollPosition?.axisDirection.offsetOf(pixels) ?? Offset.zero;

  /// How far the item shows from its slot once the frame has laid it out.
  /// It moves from where it showed before its slot moved, and heads anew
  /// for a slot that moves under it on the way, as on a resize.
  ///
  /// A change that moves the view's scroll offset, as one that shrinks the
  /// list under it does, moves the content on the screen. The item goes on
  /// from where it showed rather than jump with the content.
  Offset _translationAfterLayout(RenderBox box) {
    final slot = _contentPosition(box);
    final shift = _contentOffset(host.scrollAdjustment);
    final shifted = shift != Offset.zero;
    final motion = _motion;
    if (shifted && motion != null && motion.isMoving) motion.shift(shift);
    final shown = _shownBeforeMove;
    final from =
        (shown != null ? shown + shift : null) ??
        (motion != null &&
                motion.isMoving &&
                (motion.target - slot).distance >= retargetTolerance
            ? motion.position
            : null) ??
        _enteringFrom(box, slot) ??
        (shifted && !(motion?.isMoving ?? false) ? slot + shift : null);
    _shownBeforeMove = null;
    if (from != null && (from - slot).distance >= retargetTolerance) {
      final motion = _motion ??= ItemMotion(
        vsync: this,
        onMove: (_) => _inPlace?.markNeedsCompositedLayerUpdate(),
      );
      motion
          .animate(
            from: OverlayOffset(from),
            to: OverlayOffset(slot),
            curve: host.motionCurve,
            duration: host.motionDuration,
          )
          .whenCompleteOrCancel(() => _didStop(motion));
    }
    final moving = _motion?.isMoving ?? false;
    return _translation = moving ? _motion!.position - slot : Offset.zero;
  }

  /// Where the item comes in from, if a change brought it into sight from
  /// out of it and its slot shows: just outside the edge of the view it
  /// comes in through, at its own size, in line with its slot.
  Offset? _enteringFrom(RenderBox box, Offset slot) {
    final edge = host.takeEntry(key);
    final scroll = _scrollPosition;
    final RenderObject? viewport = RenderAbstractViewport.maybeOf(box);
    if (edge == null || scroll == null || viewport is! RenderBox) return null;
    final view = _contentPosition(viewport) & viewport.size;
    final size = box.size;
    if (!(slot & size).overlaps(view)) return null;
    final leading = edge == ViewEdge.leading;
    return switch (scroll.axisDirection) {
      AxisDirection.down => Offset(
        slot.dx,
        leading ? view.top - size.height : view.bottom,
      ),
      AxisDirection.up => Offset(
        slot.dx,
        leading ? view.bottom : view.top - size.height,
      ),
      AxisDirection.right => Offset(
        leading ? view.left - size.width : view.right,
        slot.dy,
      ),
      AxisDirection.left => Offset(
        leading ? view.right : view.left - size.width,
        slot.dy,
      ),
    };
  }

  /// Lets go of [motion] once the item is in its slot.
  void _didStop(ItemMotion motion) {
    if (!identical(_motion, motion) || motion.isMoving) return;
    _motion = null;
    _translation = Offset.zero;
    motion.dispose();
    // The frames of the move changed only the item's layer, so a screen
    // reader still finds the item where its move started.
    if (_inPlace case final box? when box.attached) {
      box.markNeedsSemanticsUpdate();
    }
  }

  /// The overlay shows the item from now on, from where it showed.
  void _stopMovingInPlace() {
    _motion?.stop();
    _shownBeforeMove = null;
    _translation = Offset.zero;
  }

  @override
  void didUpdateWidget(covariant ItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeholderSize != widget.placeholderSize) {
      oldWidget.placeholderSize.removeListener(_rebuild);
      widget.placeholderSize.addListener(_rebuild);
    }
    if (oldWidget.index != widget.index) host.didChangeItemIndex(this);
  }

  @override
  void deactivate() {
    host.didDeactivateItem(this);
    super.deactivate();
  }

  /// Back in the tree, as an item is when a list around its list moves it,
  /// subtree and all, while one of the outer list's items is dragged.
  @override
  void activate() {
    super.activate();
    host.didInitItem(this);
  }

  @override
  void dispose() {
    widget.placeholderSize.removeListener(_rebuild);
    _motion?.dispose();
    _motion = null;
    super.dispose();
  }

  /// It builds again as a whole, so the host reconciles it.
  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    host.didBuildItem(this);

    // While the overlay shows the item, its subtree lives there and a
    // placeholder keeps its place in the list.
    // The item's layer stays the list's child whatever it shows: the list
    // takes a new child only as it builds its children itself.
    final placeholderSize = widget.placeholderSize.value;
    if (placeholderSize != null) {
      _stopMovingInPlace();
      return _InPlace(
        state: this,
        child: SizedBox.fromSize(size: placeholderSize),
      );
    }

    final child = widget.builder(context, index);
    final semanticIndex = child != null
        ? host.semanticIndexOf(child, index)
        : null;
    final item = _withSemanticMoves(
      context,
      Listener(
        onPointerDown: swipeable ? _recognizeSwipe : null,
        child: Listener(
          onPointerDown: draggable ? _recognizeDrag : null,
          child: child != null
              ? host.buildEntrance(
                  KeyedSubtree(
                    key: widget.childKey,
                    child: InkSurface(child: child),
                  ),
                  index,
                  widget.entrance,
                )
              : null,
        ),
      ),
    );
    // A pointer finds the item where it shows as it moves in place.
    return _InPlace(
      state: this,
      child: semanticIndex != null
          ? IndexedSemantics(index: semanticIndex, child: item)
          : item,
    );
  }

  /// [item] with the moves a screen reader can make with it, as
  /// [ReorderableList] gives them. Each is named after the way it takes the
  /// item on screen.
  Widget _withSemanticMoves(BuildContext context, Widget item) {
    final (:back, :forward, :rowBack, :rowForward, :toLists) =
        widget.semanticMoves;
    if (!back && !forward && !rowBack && !rowForward && toLists.moves.isEmpty) {
      return item;
    }
    // An app's own tests may build the list without localizations.
    final localizations =
        Localizations.of<WidgetsLocalizations>(context, WidgetsLocalizations) ??
        const DefaultWidgetsLocalizations();
    final axisDirection =
        Scrollable.maybeOf(context)?.axisDirection ?? AxisDirection.down;
    // Along a list, or along a grid's row, which runs across its scroll
    // axis. A grid's next row is on along its scroll axis.
    final onward = host.isGrid
        ? Viewport.getDefaultCrossAxisDirection(context, axisDirection)
        : axisDirection;
    String towards(AxisDirection direction) => switch (direction) {
      AxisDirection.up => localizations.reorderItemUp,
      AxisDirection.down => localizations.reorderItemDown,
      AxisDirection.left => localizations.reorderItemLeft,
      AxisDirection.right => localizations.reorderItemRight,
    };
    final moves = [
      if (back) (localizations.reorderItemToStart, SemanticMove.toStart),
      if (back) (towards(flipAxisDirection(onward)), SemanticMove.back),
      if (rowBack)
        (towards(flipAxisDirection(axisDirection)), SemanticMove.rowBack),
      if (forward) (towards(onward), SemanticMove.forward),
      if (rowForward) (towards(axisDirection), SemanticMove.rowForward),
      if (forward) (localizations.reorderItemToEnd, SemanticMove.toEnd),
    ];
    // The platform lists an item's actions in the order of the numbers
    // Flutter gives their labels, each the first time it sees it anywhere
    // in the app. So the item numbers the labels of all the moves an item
    // can have, in their order, before it labels any: the items then list
    // their moves in this order, whichever of them is built first.
    for (final label in [
      localizations.reorderItemToStart,
      towards(flipAxisDirection(onward)),
      if (host.isGrid) towards(flipAxisDirection(axisDirection)),
      towards(onward),
      if (host.isGrid) towards(axisDirection),
      localizations.reorderItemToEnd,
      ...toLists.labels,
    ]) {
      CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: label));
    }

    return Semantics(
      key: _semanticMovesKey,
      container: true,
      customSemanticsActions: {
        for (final (label, move) in moves)
          CustomSemanticsAction(label: label): () =>
              host.makeSemanticMove(index, move),
        for (final (:list, :label) in toLists.moves)
          CustomSemanticsAction(label: label): () =>
              host.moveToList(index, list),
      },
      child: item,
    );
  }

  void _recognizeSwipe(PointerDownEvent event) =>
      host.recognizeSwipe(this, event);

  void _recognizeDrag(PointerDownEvent event) =>
      host.recognizeReorderDrag(this, event);
}

class _InPlace extends SingleChildRenderObjectWidget {
  const _InPlace({required this.state, super.child});

  final _ItemWidgetState state;

  @override
  _RenderInPlace createRenderObject(BuildContext context) =>
      _RenderInPlace(state);

  @override
  void updateRenderObject(BuildContext context, _RenderInPlace renderObject) =>
      renderObject.state = state;
}

/// Shows an item away from its slot as it moves there, on a layer of its
/// own. A frame of the move changes only the layer's transform, which it
/// works out once the frame has laid the item out: neither the item nor
/// the list lays out or paints again.
class _RenderInPlace extends RenderProxyBox {
  _RenderInPlace(this.state);

  _ItemWidgetState state;

  Offset get _translation => state._translation;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    state._inPlace = this;
  }

  @override
  void detach() {
    if (state._inPlace == this) state._inPlace = null;
    super.detach();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  OffsetLayer updateCompositedLayer({
    required covariant TransformLayer? oldLayer,
  }) {
    final translation = state._translationAfterLayout(this);
    return (oldLayer ?? TransformLayer())
      ..transform = Matrix4.translationValues(
        translation.dx,
        translation.dy,
        0,
      );
  }

  /// Where the item shows, which may be away from its slot as it moves
  /// there.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!hitTestChildren(result, position: position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      child != null &&
      result.addWithPaintOffset(
        offset: _translation,
        position: position,
        hitTest: (result, position) =>
            child!.hitTest(result, position: position),
      );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.translateByDouble(_translation.dx, _translation.dy, 0, 1);
}
