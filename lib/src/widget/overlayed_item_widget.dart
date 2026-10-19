import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../model/model.dart';
import '../options.dart';
import 'item_flight_shuttle.dart';
import 'size_reporter.dart';

typedef OverlayedItemSizeCallback = void Function(
  Size size,
  OverlayedItem item,
);
typedef OverlayedItemPointerDownCallback = void Function(
  PointerDownEvent event,
  OverlayedItem item,
  BuildContext context,
);
typedef ItemEntranceBuilder = Widget Function(
  Widget child,
  int index,
  Animation<double> entrance,
);

class OverlayedItemWidget extends StatelessWidget {
  const OverlayedItemWidget({
    super.key,
    required this.item,
    this.onPointerDown,
    this.onSizeChange,
    this.entranceBuilder,
    this.shuttleBuilder,
    this.listBounds,
    this.listClipBehavior = Clip.hardEdge,
  });

  final OverlayedItem item;

  /// Lets a pointer down on the item start a drag or a swipe of it.
  final OverlayedItemPointerDownCallback? onPointerDown;
  final OverlayedItemSizeCallback? onSizeChange;

  /// Puts the item in the transition it enters with, as the list does.
  final ItemEntranceBuilder? entranceBuilder;

  /// Builds what the item shows as it flies from one list's look to
  /// another's, in a group's layer.
  final ItemFlightShuttleBuilder? shuttleBuilder;

  /// Where the item's list is in a group's layer, which clips the item to
  /// it by [listClipBehavior] once it is [OverlayedItem.clippedToList].
  /// Null in the list's own overlay, which clips its items itself.
  final ValueGetter<Rect?>? listBounds;
  final Clip listClipBehavior;

  /// It builds again when its item changes, without the other items. As
  /// its item moves, only its layer does.
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: item, builder: _build);

  Widget _build(BuildContext context, Widget? child) => Positioned.fill(
    child: _clippedToList(
      _AtItemPosition(
        item: item,
        child: IgnorePointer(
          ignoring: !item.interactive,
          child: Listener(
            onPointerDown: (event) => onPointerDown?.call(event, item, context),
            child: ConstrainedBox(
              constraints: item.constraints,
              child: item.build(
                context,
                wrap: (child) => SizeReporter(
                  onSizeChange: (size) => onSizeChange?.call(size, item),
                  child:
                      entranceBuilder?.call(
                        child,
                        item.index,
                        item.item.entrance,
                      ) ??
                      child,
                ),
                shuttle: switch (shuttleBuilder) {
                  final builder? => (flight, to) => buildFlightShuttle(
                    context,
                    flight: flight,
                    builder: builder,
                    lookKey: item.lookKey,
                    constraints: item.constraints,
                    to: to,
                  ),
                  null => null,
                },
                boundary: (look) =>
                    LookBoundary(key: item.lookKey, child: look),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

extension on OverlayedItemWidget {
  /// In a group's layer, which goes over all the group's lists, the item
  /// goes out of sight at its list's edges once it is its list's content,
  /// as the list's items do. It paints apart from the layer, so its clip
  /// follows the list on each frame without painting the layer.
  Widget _clippedToList(Widget child) => switch (listBounds) {
    null => child,
    final bounds => RepaintBoundary(
      child: ClipRect(
        clipBehavior: item.clippedToList ? listClipBehavior : Clip.none,
        clipper: item.clippedToList
            ? _ListClipper(bounds, reclip: item.positionChanges)
            : null,
        child: child,
      ),
    ),
  };
}

/// Places an item where it is in the overlay. The item is laid out and
/// painted on a layer of its own, and a move changes only the layer's
/// transform: neither the item nor the overlay lays out or paints again.
class _AtItemPosition extends SingleChildRenderObjectWidget {
  const _AtItemPosition({required this.item, super.child});

  final OverlayedItem item;

  @override
  _RenderAtItemPosition createRenderObject(BuildContext context) =>
      _RenderAtItemPosition(item);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderAtItemPosition renderObject,
  ) => renderObject.item = item;
}

class _RenderAtItemPosition extends RenderProxyBox {
  _RenderAtItemPosition(this._item);

  OverlayedItem _item;

  set item(OverlayedItem value) {
    if (_item == value) return;
    if (attached) {
      _item.positionChanges.removeListener(markNeedsCompositedLayerUpdate);
      value.positionChanges.addListener(markNeedsCompositedLayerUpdate);
    }
    _item = value;
    markNeedsCompositedLayerUpdate();
  }

  Offset get _position => _item.position;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _item.positionChanges.addListener(markNeedsCompositedLayerUpdate);
  }

  @override
  void detach() {
    _item.positionChanges.removeListener(markNeedsCompositedLayerUpdate);
    super.detach();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  /// As a stack lays out a child positioned by its top left corner.
  @override
  void performLayout() => child?.layout(const BoxConstraints());

  @override
  OffsetLayer updateCompositedLayer({
    required covariant TransformLayer? oldLayer,
  }) =>
      (oldLayer ?? TransformLayer())
        ..transform = Matrix4.translationValues(_position.dx, _position.dy, 0);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      child != null &&
      result.addWithPaintOffset(
        offset: _position,
        position: position,
        hitTest: (result, position) =>
            child!.hitTest(result, position: position),
      );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.translateByDouble(_position.dx, _position.dy, 0, 1);
}

/// Clips an item in a group's layer to its list's bounds, as it moves: the
/// list may move in the layer too, as a board around the layer scrolls.
class _ListClipper extends CustomClipper<Rect> {
  const _ListClipper(this.bounds, {super.reclip});

  final ValueGetter<Rect?> bounds;

  @override
  Rect getClip(Size size) => bounds() ?? Offset.zero & size;

  @override
  bool shouldReclip(_ListClipper oldClipper) => true;
}
