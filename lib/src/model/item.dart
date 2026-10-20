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

  /// How far the item has entered: it runs forward while the item enters,
  /// and is complete otherwise. The insert transition builds every item
  /// with it, as [widgets.AnimatedList] builds its items, so an item looks
  /// the same to its subtree before, while and after it enters.
  final entrance = ProxyAnimation(kAlwaysCompleteAnimation);
  AnimationController? _entranceController;

  void dispose() {
    _entranceController?.dispose();
    builder.dispose();
    placeholderSize.dispose();
  }

  @override
  String toString() => 'Item(id: $key)';
}

extension ItemAnimations on Item {
  /// Runs the item's [Item.entrance] forward from the start.
  void enter({required TickerProvider vsync, required Duration duration}) {
    stopEntrance();
    final controller = _entranceController = AnimationController(
      vsync: vsync,
      duration: duration,
    );
    entrance.parent = controller;
    controller.forward().whenComplete(() {
      if (_entranceController == controller) stopEntrance();
    });
  }

  /// Completes the item's [Item.entrance] at once, and returns how far it
  /// had got.
  double stopEntrance() {
    final controller = _entranceController;
    if (controller == null) return 1.0;
    _entranceController = null;
    final value = controller.value;
    entrance.parent = kAlwaysCompleteAnimation;
    controller.dispose();
    return value;
  }

  /// Keeps the item showing [child], the same widget it showed last, for
  /// [duration], so it builds nothing again as it leaves as it is.
  Future leaveAsItIs(
    widgets.Widget? child, {
    required TickerProvider vsync,
    required Duration duration,
  }) {
    final replaced = builder;
    final controller = AnimationController(vsync: vsync, duration: duration);
    builder = KeptItemBuilder(child, controller: controller);
    replaced.dispose();
    return controller.forward();
  }

  Future animateRemovedItemBuilder({
    required widgets.AnimatedRemovedItemBuilder builder,
    required TickerProvider vsync,
    required Duration duration,
  }) {
    final replaced = this.builder;
    final from = stopEntrance();
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
