import 'package:flutter/widgets.dart';

import 'item.dart';
import 'item_builder.dart';

class OutgoingItem extends Item {
  OutgoingItem({
    required super.id,
    required AnimationController controller,
    required AnimatedRemovedItemBuilder removedItemBuilder,
    required super.location,
    required super.size,
  }) : super(
          builder: ItemBuilder.adaptAnimatedRemovedItemBuilder(
            removedItemBuilder,
            controller: controller,
          ),
        );

  Widget? build(BuildContext context) => builder.build(context, -1);
}
