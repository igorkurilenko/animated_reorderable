part of 'model.dart';

/// Wraps an item's [child] in a widget that [animation] drives, such as a
/// held item's decoration or an inserted item's transition. [index] is the
/// item's index.
typedef AnimatedItemDecorator = widgets.Widget Function(
  widgets.Widget child,
  int index,
  Animation<double> animation,
);

/// Scales an item up a little and fades it a little while it is held.
widgets.Widget defaultDraggedItemDecorator(
  widgets.Widget child,
  int index,
  Animation<double> animation,
) => ScaleTransition(
  scale: animation
      .drive(CurveTween(curve: Curves.easeInOut))
      .drive(Tween(begin: 1.0, end: 1.05)),
  child: FadeTransition(
    opacity: animation.drive(Tween(begin: 1, end: 0.7)),
    child: child,
  ),
);

class AnimatedItemDecoratorAdapter {
  AnimatedItemDecoratorAdapter(this.decorator, {required this.controller});

  final widgets.AnimationController controller;
  AnimatedItemDecorator decorator;

  widgets.Widget? decorate(widgets.Widget? child, int index) {
    return child != null ? decorator.call(child, index, controller.view) : null;
  }

  TickerFuture forwardAnimation({double? from}) =>
      controller.forward(from: from);

  TickerFuture reverseAnimation({double? from}) =>
      controller.reverse(from: from);

  void dispose() {
    controller.dispose();
  }
}
