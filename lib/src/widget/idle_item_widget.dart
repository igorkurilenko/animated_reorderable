import 'package:flutter/widgets.dart';

import '../../animated_reorderable.dart';
import '../model/model.dart';
import '../util/misc.dart';

typedef RenderedItem = _IdleItemWidgetState;
typedef RenderedItemLifecycleCallback = void Function(RenderedItem item);

class IdleItemWidget extends StatefulWidget {
  const IdleItemWidget({
    super.key,
    required this.index,
    required this.item,
    required this.controller,
    this.onInit,
    this.didUpdate,
    this.onDispose,
    this.onDeactivate,
    this.didBuild,
  });

  final int index;
  final IdleItem item;
  final AnimatedReorderableController controller;
  final RenderedItemLifecycleCallback? onInit;
  final RenderedItemLifecycleCallback? didUpdate;
  final RenderedItemLifecycleCallback? onDispose;
  final RenderedItemLifecycleCallback? onDeactivate;
  final RenderedItemLifecycleCallback? didBuild;

  @override
  State<IdleItemWidget> createState() => _IdleItemWidgetState();
}

class _IdleItemWidgetState extends State<IdleItemWidget> {
  int get index => widget.index;
  int get id => item.id;
  IdleItem get item => widget.item;
  AnimatedReorderableController get controller => widget.controller;
  Offset get position => findRenderBox()!.localToGlobal(Offset.zero);
  Size get size => findRenderBox()!.size;

  @override
  void initState() {
    super.initState();
    widget.onInit?.call(this);
  }

  @override
  void didUpdateWidget(covariant IdleItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      widget.didUpdate?.call(this);
    }
  }

  @override
  void dispose() {
    widget.onDispose?.call(this);
    super.dispose();
  }

  @override
  void deactivate() {
    widget.onDeactivate?.call(this);
    super.deactivate();
  }

  void rebuild() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.didBuild != null) {
      addPostFrame(() {
        widget.didBuild!.call(this);
      });
    }

    return Opacity(
      opacity: item.overlayed ? 0 : 1,
      child: item.builder.build(context, widget.index),
    );
  }
}
