import 'package:flutter/widgets.dart';

import '../animated_reorderable_controller.dart';

class ItemsLayer extends StatefulWidget {
  const ItemsLayer({
    super.key,
    required this.controller,
    required this.collectionViewBuilder,
  });

  final AnimatedReorderableController controller;
  final WidgetBuilder collectionViewBuilder;

  @override
  State<ItemsLayer> createState() => ItemsLayerState();
}

class ItemsLayerState extends State<ItemsLayer> {
  AnimatedReorderableController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.attachItemsLayer(this);
  }

  @override
  void dispose() {
    controller.detachItemsLayer(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    controller.didBuildItemsLayer();

    return widget.collectionViewBuilder(context);
  }
}
