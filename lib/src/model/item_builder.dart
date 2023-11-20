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

  void forwardAnimation({required double from}) =>
      controller.forward(from: from);

  void reverseAnimation({required double from}) =>
      controller.reverse(from: from);
}

class AnimatedItemBuilderAdapter extends AnimatedItemBuilder {
  AnimatedItemBuilderAdapter(this.builder, {required super.controller});

  final widgets.AnimatedItemBuilder builder;

  @override
  widgets.Widget? build(widgets.BuildContext context, int index) =>
      builder(context, index, controller.view);

  @override
  void dispose() => controller.dispose();
}

class AnimatedRemovedItemBuilderAdapter extends AnimatedItemBuilder {
  AnimatedRemovedItemBuilderAdapter(this.builder, {required super.controller});

  final widgets.AnimatedRemovedItemBuilder builder;

  @override
  widgets.Widget? build(widgets.BuildContext context, int index) =>
      builder(context, controller.view);

  @override
  void dispose() => controller.dispose();
}
