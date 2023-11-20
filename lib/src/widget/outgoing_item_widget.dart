import 'package:flutter/widgets.dart';

import '../model/model.dart';

class OutgoingItemWidget extends StatefulWidget {
  const OutgoingItemWidget({
    super.key,
    required this.item,
    this.offset = Offset.zero,
  });

  final OutgoingItem item;
  final Offset offset;

  @override
  State<OutgoingItemWidget> createState() => _OutgoingItemWidgetState();
}

class _OutgoingItemWidgetState extends State<OutgoingItemWidget> {
  OutgoingItem get item => widget.item;
  Offset get offset => widget.offset;

  @override
  void initState() {
    super.initState();
    item.addListener(rebuild);
  }

  @override
  void dispose() {
    item.removeListener(rebuild);
    super.dispose();
  }

  void rebuild() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Positioned(
        left: item.geometry.left + offset.dx,
        top: item.geometry.top + offset.dy,
        child: SizedBox(
          width: item.geometry.width,
          height: item.geometry.height,
          child: item.build(context),
        ),
      );
}
