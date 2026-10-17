import 'package:flutter/rendering.dart';

typedef LayoutCallback = void Function(
  SliverGridLayout layout,
  SliverConstraints constraints,
);

abstract class SliverGridDelegateDecorator implements SliverGridDelegate {
  final SliverGridDelegate gridDelegate;

  SliverGridDelegateDecorator({required this.gridDelegate});

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) =>
      gridDelegate.getLayout(constraints);

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

class SliverGridLayoutNotifier extends SliverGridDelegateDecorator {
  SliverGridLayoutNotifier({required super.gridDelegate, this.onLayout});

  final LayoutCallback? onLayout;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final layout = super.getLayout(constraints);
    onLayout?.call(layout, constraints);
    return layout;
  }
}
