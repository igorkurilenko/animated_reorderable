import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../const.dart';
import '../model/model.dart'
    show GlobalOffset, ItemMotion, OverlayOffset, RenderedItem;
import '../model/swipe_direction.dart';
import '../util/geometry.dart';

/// An edge of the view along its scroll axis: the leading one, where the
/// list starts, or the trailing one.
enum ViewEdge { leading, trailing }

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

  /// The edge of the view that the item with [key] comes in through, once,
  /// if a change brought it into sight from out of it.
  ViewEdge? takeEntry(Key key);

  /// The semantic index of [child], the item at [index], as the view's
  /// delegate gives it, or null for none.
  int? semanticIndexOf(Widget child, int index);
}

class ItemWidget extends StatefulWidget {
  const ItemWidget({
    required super.key,
    required this.index,
    required this.childKey,
    required this.builder,
    required this.placeholderSize,
    required this.entrance,
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

  /// Where [box] is laid out, in the coordinates of the view's content.
  Offset _contentPosition(RenderBox box) {
    final global = box.localToGlobal(Offset.zero);
    final scroll = _scrollPosition;
    if (scroll == null || !scroll.hasPixels) return global;
    return global +
        switch (scroll.axisDirection) {
          AxisDirection.down => Offset(0, scroll.pixels),
          AxisDirection.up => Offset(0, -scroll.pixels),
          AxisDirection.right => Offset(scroll.pixels, 0),
          AxisDirection.left => Offset(-scroll.pixels, 0),
        };
  }

  /// How far the item shows from its slot once the frame has laid it out.
  /// It moves from where it showed before its slot moved, and heads anew
  /// for a slot that moves under it on the way, as on a resize.
  Offset _translationAfterLayout(RenderBox box) {
    final slot = _contentPosition(box);
    final motion = _motion;
    final from =
        _shownBeforeMove ??
        (motion != null &&
                motion.isMoving &&
                (motion.target - slot).distance >= retargetTolerance
            ? motion.position
            : null) ??
        _enteringFrom(box, slot);
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
    final item = Listener(
      onPointerDown: swipeable ? _recognizeSwipe : null,
      child: Listener(
        onPointerDown: draggable ? _recognizeDrag : null,
        child: child != null
            ? host.buildEntrance(
                KeyedSubtree(key: widget.childKey, child: child),
                index,
                widget.entrance,
              )
            : null,
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
