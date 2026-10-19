import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../model/model.dart';
import '../options.dart';

/// The shuttle of [flight], which shows [to], an item's new look, with the
/// image of the look it leaves, each fitted to the shuttle, as [builder]
/// puts them together. Its look paints into the boundary [lookKey] keys.
Widget buildFlightShuttle(
  BuildContext context, {
  required ItemFlight flight,
  required ItemFlightShuttleBuilder builder,
  required GlobalKey lookKey,
  required BoxConstraints constraints,
  required Widget to,
}) => _FlightBox(
  flight: flight,
  // Its look as it shows on each frame, which a flight that turns
  // elsewhere flies from, as a hero_here flight that diverts does.
  child: LookBoundary(
    key: lookKey,
    child: builder(
      context,
      flight.animation,
      RawImage(image: flight.from, fit: BoxFit.fill),
      _Look(
        constraints: constraints,
        onLayout: (size) => flight.toSize = size,
        child: to,
      ),
    ),
  ),
);

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
/// A frame of the flight lays out the shuttle at its new size, but neither
/// of its looks: each is fitted to it.
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

/// Lays out a look of a flying item as it is, by [constraints], and fits it
/// to the shuttle by scale.
class _Look extends SingleChildRenderObjectWidget {
  const _Look({required this.constraints, this.onLayout, super.child});

  final BoxConstraints constraints;
  final ValueChanged<Size>? onLayout;

  @override
  _RenderLook createRenderObject(BuildContext context) =>
      _RenderLook(constraints, onLayout);

  @override
  void updateRenderObject(BuildContext context, _RenderLook renderObject) =>
      renderObject
        ..lookConstraints = constraints
        ..onLayout = onLayout;
}

class _RenderLook extends RenderProxyBox {
  _RenderLook(this._lookConstraints, this.onLayout);

  BoxConstraints _lookConstraints;
  ValueChanged<Size>? onLayout;
  var _lookSize = Size.zero;

  set lookConstraints(BoxConstraints value) {
    if (_lookConstraints == value) return;
    _lookConstraints = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final child = this.child;
    if (child == null) return;
    child.layout(_lookConstraints, parentUsesSize: true);
    _lookSize = child.size;
    // The flight box lays this look out as it lays itself out, so it may
    // take its size: a copy, which the box owns.
    onLayout?.call(Size.copy(_lookSize));
  }

  Matrix4 get _scale => Matrix4.diagonal3Values(
    _lookSize.width > 0 ? size.width / _lookSize.width : 1,
    _lookSize.height > 0 ? size.height / _lookSize.height : 1,
    1,
  );

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    context.pushTransform(
      needsCompositing,
      offset,
      _scale,
      (context, offset) => context.paintChild(child!, offset),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      child != null &&
      result.addWithPaintTransform(
        transform: _scale,
        position: position,
        hitTest: (result, position) =>
            child!.hitTest(result, position: position),
      );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.multiply(_scale);
}
