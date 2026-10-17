part of 'model.dart';

abstract class ItemBuilder {
  factory ItemBuilder.adaptIndexedWidgetBuilder(
    widgets.NullableIndexedWidgetBuilder builder,
  ) => NullableIndexedWidgetBuilderAdapter(builder);

  factory ItemBuilder.adaptAnimatedItemBuilder(
    widgets.AnimatedItemBuilder builder, {
    required widgets.AnimationController controller,
  }) => AnimatedItemBuilderAdapter(builder, controller: controller);

  factory ItemBuilder.adaptAnimatedRemovedItemBuilder(
    widgets.AnimatedRemovedItemBuilder builder, {
    required widgets.AnimationController controller,
  }) => AnimatedRemovedItemBuilderAdapter(builder, controller: controller);

  factory ItemBuilder.proxy(Item item) => ItemBuilderProxy(item: item);

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

class ItemBuilderProxy implements ItemBuilder {
  ItemBuilderProxy({required this.item});

  final Item item;

  @override
  widgets.Widget? build(widgets.BuildContext context, int index) =>
      item.builder.build(context, index);

  /// The adapted [item] owns its builder and disposes it.
  @override
  void dispose() {}
}

abstract class AnimatedItemBuilder implements ItemBuilder {
  AnimatedItemBuilder({required this.controller});

  final widgets.AnimationController controller;

  double stopAnimation() {
    final result = controller.value;
    controller.stop();
    return result;
  }

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

extension ItemBuilderExt on ItemBuilder {
  AnimatedItemBuilder? get asAnimated => switch (this) {
    (ItemBuilderProxy b) => b.item.builder.asAnimated,
    (AnimatedItemBuilder b) => b,
    _ => null,
  };
}
