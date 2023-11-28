part of model;

class OutgoingItem extends Item {
  OutgoingItem({
    required super.id,
    required widgets.AnimationController controller,
    required widgets.AnimatedRemovedItemBuilder removedItemBuilder,
    required super.position,
    required super.size,
  }) : super(
          builder: ItemBuilder.adaptAnimatedRemovedItemBuilder(
            removedItemBuilder,
            controller: controller,
          ),
        );

  widgets.Widget? build(widgets.BuildContext context) => builder.build(context, -1);
}
