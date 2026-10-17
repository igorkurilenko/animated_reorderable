part of 'model.dart';

typedef AnimatedItemDecorator = widgets.Widget Function(
  widgets.Widget child,
  int index,
  Animation<double> animation,
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
