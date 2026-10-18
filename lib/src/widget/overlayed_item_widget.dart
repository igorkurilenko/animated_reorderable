import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../model/model.dart';
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
  });

  final OverlayedItem item;

  /// Lets a pointer down on the item start a drag or a swipe of it.
  final OverlayedItemPointerDownCallback? onPointerDown;
  final OverlayedItemSizeCallback? onSizeChange;

  /// Puts the item in the transition it enters with, as the list does.
  final ItemEntranceBuilder? entranceBuilder;

  /// It builds again when its item changes, without the other items. As
  /// its item moves, only its layer does.
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: item, builder: _build);

  Widget _build(BuildContext context, Widget? child) => Positioned.fill(
    child: _AtItemPosition(
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
            ),
          ),
        ),
      ),
    ),
  );
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
