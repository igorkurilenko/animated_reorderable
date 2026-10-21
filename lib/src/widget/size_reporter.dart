import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Calls [onLayout] as its child lays out at a new size, before the frame
/// paints it, and [onSizeChange] after the frame.
class SizeReporter extends SingleChildRenderObjectWidget {
  const SizeReporter({
    super.key,
    required this.onSizeChange,
    this.onLayout,
    super.child,
  });

  final ValueChanged<Size> onSizeChange;

  /// Called in the layout of the frame. It may not build or lay anything
  /// out.
  final ValueChanged<Size>? onLayout;

  @override
  RenderSizeReporter createRenderObject(BuildContext context) =>
      RenderSizeReporter(onSizeChange, onLayout: onLayout);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSizeReporter renderObject,
  ) => renderObject
    ..onSizeChange = onSizeChange
    ..onLayout = onLayout;
}

class RenderSizeReporter extends RenderProxyBox {
  RenderSizeReporter(this.onSizeChange, {this.onLayout});

  ValueChanged<Size> onSizeChange;
  ValueChanged<Size>? onLayout;
  Size? _reportedSize;
  bool _reportScheduled = false;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _reportedSize) return;
    _reportedSize = size;
    onLayout?.call(size);
    if (_reportScheduled) return;
    _reportScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (attached) onSizeChange(_reportedSize!);
    });
  }
}
