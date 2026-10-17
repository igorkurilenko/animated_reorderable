import 'package:flutter/widgets.dart';

import '../animated_reorderable_controller.dart';
import '../util/scheduling.dart';

class ItemsLayer extends StatefulWidget {
  const ItemsLayer({
    super.key,
    required this.controller,
    required this.collectionViewBuilder,
    this.didBuild,
  });

  final AnimatedReorderableController controller;
  final WidgetBuilder collectionViewBuilder;
  final VoidCallback? didBuild;

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
    addPostFrame(() => widget.didBuild?.call());

    return widget.collectionViewBuilder(context);
  }
}
