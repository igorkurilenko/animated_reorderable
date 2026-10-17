part of 'model.dart';

class Item {
  Item({required this.key, required this.builder, widgets.GlobalKey? childKey})
    : childKey = childKey ?? widgets.GlobalKey();

  final Key key;

  /// Keys the item's subtree, so the subtree keeps its state while it moves
  /// between the list and the overlay.
  final widgets.GlobalKey childKey;
  ItemBuilder builder;

  /// The size of the item's placeholder in the list while the overlay
  /// shows the item, or null while the list shows the item itself.
  final placeholderSize = widgets.ValueNotifier<widgets.Size?>(null);

  void dispose() {
    builder.dispose();
    placeholderSize.dispose();
  }

  @override
  String toString() => 'Item(id: $key)';
}

extension ItemAnimations on Item {
  Future animateItemBuilder({
    required widgets.AnimatedItemBuilder builder,
    required TickerProvider vsync,
    required Duration duration,
    double? from = 0,
  }) {
    final originalBuilder = this.builder;
    final controller = AnimationController(vsync: vsync, duration: duration);

    this.builder = ItemBuilder.adaptAnimatedItemBuilder(
      builder,
      controller: controller,
    );

    return controller.forward(from: from).whenComplete(() {
      this.builder = originalBuilder;
      controller.dispose();
    });
  }

  Future animateRemovedItemBuilder({
    required widgets.AnimatedRemovedItemBuilder builder,
    required TickerProvider vsync,
    required Duration duration,
  }) {
    final replaced = this.builder;
    final from = replaced.asAnimated?.stopAnimation() ?? 1.0;
    final controller = AnimationController(vsync: vsync, duration: duration);

    this.builder = ItemBuilder.adaptAnimatedRemovedItemBuilder(
      builder,
      controller: controller,
    );
    // A removed item is not built with its other builders again.
    replaced.dispose();

    return controller.reverse(from: from);
  }
}
