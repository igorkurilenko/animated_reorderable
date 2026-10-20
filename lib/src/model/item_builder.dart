part of 'model.dart';

abstract class ItemBuilder {
  factory ItemBuilder.adaptIndexedWidgetBuilder(
    widgets.NullableIndexedWidgetBuilder builder,
  ) => NullableIndexedWidgetBuilderAdapter(builder);

  factory ItemBuilder.adaptAnimatedRemovedItemBuilder(
    widgets.AnimatedRemovedItemBuilder builder, {
    required widgets.AnimationController controller,
  }) => AnimatedRemovedItemBuilderAdapter(builder, controller: controller);

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

/// Builds what an item showed last, as it leaves as it is: the list no
/// longer has it at an index for its builder to build. [controller] counts
/// the time it takes to leave.
class KeptItemBuilder implements ItemBuilder {
  KeptItemBuilder(this.child, {required this.controller});

  final widgets.Widget? child;
  final widgets.AnimationController controller;

  @override
  widgets.Widget? build(widgets.BuildContext context, int index) => child;

  @override
  void dispose() => controller.dispose();
}

class AnimatedRemovedItemBuilderAdapter implements ItemBuilder {
  AnimatedRemovedItemBuilderAdapter(this.builder, {required this.controller});

  final widgets.AnimatedRemovedItemBuilder builder;
  final widgets.AnimationController controller;

  @override
  widgets.Widget? build(widgets.BuildContext context, int index) =>
      builder(context, controller.view);

  @override
  void dispose() => controller.dispose();
}
