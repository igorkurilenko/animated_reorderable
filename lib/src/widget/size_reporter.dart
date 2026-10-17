import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Calls [onSizeChange] after a frame that changed its child's size.
class SizeReporter extends SingleChildRenderObjectWidget {
  const SizeReporter({super.key, required this.onSizeChange, super.child});

  final ValueChanged<Size> onSizeChange;

  @override
  RenderSizeReporter createRenderObject(BuildContext context) =>
      RenderSizeReporter(onSizeChange);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSizeReporter renderObject,
  ) => renderObject.onSizeChange = onSizeChange;
}

class RenderSizeReporter extends RenderProxyBox {
  RenderSizeReporter(this.onSizeChange);

  ValueChanged<Size> onSizeChange;
  Size? _reportedSize;
  bool _reportScheduled = false;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _reportedSize) return;
    _reportedSize = size;
    if (_reportScheduled) return;
    _reportScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (attached) onSizeChange(_reportedSize!);
    });
  }
}
