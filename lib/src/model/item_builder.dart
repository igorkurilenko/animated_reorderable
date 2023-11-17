import 'package:flutter/widgets.dart' as flutter;

import 'item.dart';

abstract class ItemBuilder {
  factory ItemBuilder.adaptIndexedWidgetBuilder(
          flutter.NullableIndexedWidgetBuilder builder) =>
      NullableIndexedWidgetBuilderAdapter(builder);

  factory ItemBuilder.adaptAnimatedItemBuilder(
    flutter.AnimatedItemBuilder builder, {
    required flutter.AnimationController controller,
  }) =>
      AnimatedItemBuilderAdapter(builder, controller: controller);

  factory ItemBuilder.adaptAnimatedRemovedItemBuilder(
    flutter.AnimatedRemovedItemBuilder builder, {
    required flutter.AnimationController controller,
  }) =>
      AnimatedRemovedItemBuilderAdapter(builder, controller: controller);

  factory ItemBuilder.adaptOtherItemBuilder(Item item) =>
      OtherItemBuilderAdapter(item: item);

  flutter.Widget? build(flutter.BuildContext context, int index);

  void dispose();
}

class NullableIndexedWidgetBuilderAdapter implements ItemBuilder {
  final flutter.NullableIndexedWidgetBuilder builder;

  NullableIndexedWidgetBuilderAdapter(this.builder);

  @override
  flutter.Widget? build(flutter.BuildContext context, int index) =>
      builder(context, index);

  @override
  void dispose() {}
}

class OtherItemBuilderAdapter implements ItemBuilder {
  OtherItemBuilderAdapter({required this.item});

  final Item item;

  @override
  flutter.Widget? build(flutter.BuildContext context, int index) =>
      item.builder.build(context, index);

  @override
  void dispose() => item.builder.dispose();
}

abstract class AnimatedItemBuilder implements ItemBuilder {
  AnimatedItemBuilder({required this.controller});

  final flutter.AnimationController controller;

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

  final flutter.AnimatedItemBuilder builder;

  @override
  flutter.Widget? build(flutter.BuildContext context, int index) =>
      builder(context, index, controller.view);

  @override
  void dispose() => controller.dispose();
}

class AnimatedRemovedItemBuilderAdapter extends AnimatedItemBuilder {
  AnimatedRemovedItemBuilderAdapter(this.builder, {required super.controller});

  final flutter.AnimatedRemovedItemBuilder builder;

  @override
  flutter.Widget? build(flutter.BuildContext context, int index) =>
      builder(context, controller.view);

  @override
  void dispose() => controller.dispose();
}
