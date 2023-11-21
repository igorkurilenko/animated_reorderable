part of model;

abstract class ItemBuilder {
  factory ItemBuilder.adaptIndexedWidgetBuilder(
          widgets.NullableIndexedWidgetBuilder builder) =>
      NullableIndexedWidgetBuilderAdapter(builder);

  factory ItemBuilder.adaptAnimatedItemBuilder(
    widgets.AnimatedItemBuilder builder, {
    required widgets.AnimationController controller,
  }) =>
      AnimatedItemBuilderAdapter(builder, controller: controller);

  factory ItemBuilder.adaptAnimatedRemovedItemBuilder(
    widgets.AnimatedRemovedItemBuilder builder, {
    required widgets.AnimationController controller,
  }) =>
      AnimatedRemovedItemBuilderAdapter(builder, controller: controller);

  factory ItemBuilder.adaptOtherItemBuilder(Item item) =>
      OtherItemBuilderAdapter(item: item);

  widgets.Widget? build(widgets.BuildContext context, int index);

  void dispose();
}

class NullableIndexedWidgetBuilderAdapter implements ItemBuilder {
  final widgets.NullableIndexedWidgetBuilder builder;

  NullableIndexedWidgetBuilderAdapter(this.builder);

  @override
  widgets.Widget? build(widgets.BuildContext context, int index) =>
      builder(context, index);

  @override
  void dispose() {}
}

class OtherItemBuilderAdapter implements ItemBuilder {
  OtherItemBuilderAdapter({required this.item});

  final Item item;

  @override
  widgets.Widget? build(widgets.BuildContext context, int index) =>
      item.builder.build(context, index);

  @override
  void dispose() => item.builder.dispose();
}

abstract class AnimatedItemBuilder implements ItemBuilder {
  AnimatedItemBuilder({required this.controller});

  final widgets.AnimationController controller;

  double? stopAnimation() {
    final result = controller.value;
    controller.stop();
    return result;
  }

  TickerFuture forwardAnimation({double? from}) =>
      controller.forward(from: from);

  TickerFuture reverseAnimation({double? from}) =>
      controller.reverse(from: from);

  @override
  void dispose() => controller.dispose();
}

class AnimatedItemBuilderAdapter extends AnimatedItemBuilder {
  AnimatedItemBuilderAdapter(this.builder, {required super.controller});

  final widgets.AnimatedItemBuilder builder;

  @override
  widgets.Widget? build(widgets.BuildContext context, int index) =>
      builder(context, index, controller.view);
}

class AnimatedRemovedItemBuilderAdapter extends AnimatedItemBuilder {
  AnimatedRemovedItemBuilderAdapter(this.builder, {required super.controller});

  final widgets.AnimatedRemovedItemBuilder builder;

  @override
  widgets.Widget? build(widgets.BuildContext context, int index) =>
      builder(context, controller.view);
}

typedef AnimatedItemDecorator = widgets.Widget Function(
  widgets.Widget child,
  int index,
  widgets.Animation<double> animation,
);

abstract class ItemBuilderDecorator implements ItemBuilder {
  ItemBuilderDecorator(this.itemBuilder);

  final ItemBuilder itemBuilder;

  @override
  widgets.Widget? build(widgets.BuildContext context, int index) =>
      itemBuilder.build(context, index);

  @override
  void dispose() => itemBuilder.dispose();
}

class AnimatedDecoratedItemBuilder extends ItemBuilderDecorator {
  AnimatedDecoratedItemBuilder(
    super.itemBuilder, {
    required this.decoratorId,
    required this.decorator,
    required this.controller,
  });

  final String decoratorId;
  final widgets.AnimationController controller;
  final AnimatedItemDecorator decorator;

  @override
  widgets.Widget? build(widgets.BuildContext context, int index) {
    final item = super.build(context, index);
    return item != null ? decorator.call(item, index, controller.view) : null;
  }

  TickerFuture forwardDecoration({double? from}) =>
      controller.forward(from: from);

  TickerFuture reverseDecoration({double? from}) =>
      controller.reverse(from: from);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
