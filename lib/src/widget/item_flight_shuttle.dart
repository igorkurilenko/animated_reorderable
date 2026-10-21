import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../model/model.dart';
import '../options.dart';

/// The shuttle of [flight], inside [decorate], which shows [look], an
/// item's new look, with the image of the look it leaves, as [builder] puts
/// them together. Each look shows at its own size, holding the point the
/// pointer holds, as the shuttle grows or shrinks around that point to the
/// new look's size. The shuttle paints into the boundary [lookKey] keys.
Widget buildFlightShuttle(
  BuildContext context, {
  required ItemFlight flight,
  required ItemFlightShuttleBuilder builder,
  required GlobalKey lookKey,
  required BoxConstraints constraints,
  required Widget look,
  required Widget Function(Widget shuttle) decorate,
}) => _FlightBox(
  flight: flight,
  // The decoration goes around the shuttle as it grows or shrinks.
  child: decorate(
    // Its look as it shows on each frame, which a flight that turns
    // elsewhere flies from, as a hero_here flight that diverts does.
    LookBoundary(
      key: lookKey,
      child: builder(
        context,
        flight.animation,
        _AtGrip(
          grip: flight.grip,
          size: flight.fromSize,
          child: RawImage(image: flight.from, fit: BoxFit.fill),
        ),
        _NewLook(
          constraints: constraints,
          grip: flight.grip,
          onLayout: (size) => flight.toSize = size,
          child: look,
        ),
      ),
    ),
  ),
);

/// Shows [child] at [size], holding the point [grip] of it, a part of its
/// size, at the same part of the shuttle, cut at the shuttle's edges.
class _AtGrip extends StatelessWidget {
  const _AtGrip({required this.grip, required this.size, required this.child});

  final Offset grip;
  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: OverflowBox(
      minWidth: size.width,
      maxWidth: size.width,
      minHeight: size.height,
      maxHeight: size.height,
      alignment: Alignment(2 * grip.dx - 1, 2 * grip.dy - 1),
      child: child,
    ),
  );
}

/// Paints an item's look into a layer of its own, which a flight takes as
/// an image to fly from.
class LookBoundary extends SingleChildRenderObjectWidget {
  const LookBoundary({super.key, super.child});

  /// The look in the boundary [key] keys as it last painted, as an image,
  /// and its size, or null if it hasn't painted yet.
  static (ui.Image, Size)? takeLook(GlobalKey key) {
    final context = key.currentContext;
    final boundary = context?.findRenderObject();
    if (context == null || boundary is! RenderLookBoundary) return null;
    final image = boundary.lastPainted(
      pixelRatio: View.of(context).devicePixelRatio,
    );
    return image == null ? null : (image, boundary.size);
  }

  @override
  RenderLookBoundary createRenderObject(BuildContext context) =>
      RenderLookBoundary();
}

class RenderLookBoundary extends RenderRepaintBoundary {
  /// The look as it last painted, as an image, or null if it hasn't
  /// painted yet. It is the last frame's even while the look waits to
  /// paint again.
  ui.Image? lastPainted({required double pixelRatio}) {
    final layer = this.layer;
    if (layer is! OffsetLayer || !hasSize || size.isEmpty) return null;
    return layer.toImageSync(Offset.zero & size, pixelRatio: pixelRatio);
  }
}

/// Takes the size of the look a flight flies to, and shows its shuttle at
/// the size of this frame, holding the same point of it under the pointer.
class _FlightBox extends SingleChildRenderObjectWidget {
  const _FlightBox({required this.flight, super.child});

  final ItemFlight flight;

  @override
  _RenderFlightBox createRenderObject(BuildContext context) =>
      _RenderFlightBox(flight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFlightBox renderObject,
  ) => renderObject.flight = flight;
}

class _RenderFlightBox extends RenderProxyBox {
  _RenderFlightBox(this._flight);

  ItemFlight _flight;
  var _childOffset = Offset.zero;

  set flight(ItemFlight value) {
    if (_flight == value) return;
    if (attached) {
      _flight.animation.removeListener(markNeedsLayout);
      value.animation.addListener(markNeedsLayout);
    }
    _flight = value;
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _flight.animation.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _flight.animation.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void performLayout() {
    final shown = _flight.shownSize;
    child?.layout(BoxConstraints.tight(shown));
    // As big as the look it flies to, which the list's placeholder takes.
    size = constraints.constrain(_flight.toSize ?? shown);
    final grip = _flight.grip;
    _childOffset = Offset(
      (size.width - shown.width) * grip.dx,
      (size.height - shown.height) * grip.dy,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child case final child?) {
      context.paintChild(child, offset + _childOffset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      child != null &&
      result.addWithPaintOffset(
        offset: _childOffset,
        position: position,
        hitTest: (result, position) =>
            child!.hitTest(result, position: position),
      );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.translateByDouble(_childOffset.dx, _childOffset.dy, 0, 1);
}

/// Lays the new look of a flying item out at its own size, by
/// [constraints], which the shuttle flies to, and again at least as big as
/// the shuttle, which it shows at, holding the point [grip] of it at the
/// same part of the shuttle. As the shuttle shrinks to it, the look lays
/// out at each size on the way, as a hero_here crossfade lays a hero out,
/// and covers the shuttle. As the shuttle grows to it, it shows at its own
/// size, cut at the shuttle's edges.
class _NewLook extends SingleChildRenderObjectWidget {
  const _NewLook({
    required this.constraints,
    required this.grip,
    this.onLayout,
    super.child,
  });

  final BoxConstraints constraints;
  final Offset grip;

  /// Called with the look's own size as it lays out.
  final ValueChanged<Size>? onLayout;

  @override
  _RenderNewLook createRenderObject(BuildContext context) =>
      _RenderNewLook(constraints, grip, onLayout);

  @override
  void updateRenderObject(BuildContext context, _RenderNewLook renderObject) =>
      renderObject
        ..lookConstraints = constraints
        ..grip = grip
        ..onLayout = onLayout;
}

class _RenderNewLook extends RenderProxyBox {
  _RenderNewLook(this._lookConstraints, this._grip, this.onLayout);

  BoxConstraints _lookConstraints;
  Offset _grip;
  ValueChanged<Size>? onLayout;
  var _childOffset = Offset.zero;
  final _clip = LayerHandle<ClipRectLayer>();

  set lookConstraints(BoxConstraints value) {
    if (_lookConstraints == value) return;
    _lookConstraints = value;
    markNeedsLayout();
  }

  set grip(Offset value) {
    if (_grip == value) return;
    _grip = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final child = this.child;
    if (child == null) return;
    child.layout(_lookConstraints, parentUsesSize: true);
    // The flight box lays this look out as it lays itself out, so it may
    // take its size: a copy, which the box owns.
    onLayout?.call(Size.copy(child.size));
    child.layout(
      BoxConstraints(
        minWidth: size.width,
        maxWidth: math.max(size.width, _lookConstraints.maxWidth),
        minHeight: size.height,
        maxHeight: math.max(size.height, _lookConstraints.maxHeight),
      ),
      parentUsesSize: true,
    );
    _childOffset = Offset(
      (size.width - child.size.width) * _grip.dx,
      (size.height - child.size.height) * _grip.dy,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final overflows =
        child.size.width > size.width || child.size.height > size.height;
    if (!overflows) {
      _clip.layer = null;
      context.paintChild(child, offset + _childOffset);
      return;
    }
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (context, offset) => context.paintChild(child, offset + _childOffset),
      oldLayer: _clip.layer,
    );
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      child != null &&
      size.contains(position) &&
      result.addWithPaintOffset(
        offset: _childOffset,
        position: position,
        hitTest: (result, position) =>
            child!.hitTest(result, position: position),
      );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.translateByDouble(_childOffset.dx, _childOffset.dy, 0, 1);
}
