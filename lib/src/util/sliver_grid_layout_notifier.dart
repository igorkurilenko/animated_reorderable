import 'package:flutter/rendering.dart';

typedef LayoutCallback = void Function(
  SliverGridLayout layout,
  SliverConstraints constraints,
);

/// A [gridDelegate] that calls [onLayout] with every layout it makes.
class SliverGridLayoutNotifier implements SliverGridDelegate {
  SliverGridLayoutNotifier({required this.gridDelegate, this.onLayout});

  final SliverGridDelegate gridDelegate;
  final LayoutCallback? onLayout;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final layout = gridDelegate.getLayout(constraints);
    onLayout?.call(layout, constraints);
    return layout;
  }

  @override
  bool shouldRelayout(covariant SliverGridDelegate oldDelegate) {
    final oldGridDelegate = oldDelegate is SliverGridLayoutNotifier
        ? oldDelegate.gridDelegate
        : oldDelegate;
    // Like RenderSliverGrid, only a delegate of the same type is asked.
    return oldGridDelegate.runtimeType != gridDelegate.runtimeType ||
        gridDelegate.shouldRelayout(oldGridDelegate);
  }
}
