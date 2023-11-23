import 'package:flutter/widgets.dart';

import '../model/model.dart';

class OutgoingItemWidget extends StatefulWidget {
  const OutgoingItemWidget({
    super.key,
    required this.item,
  });

  final OutgoingItem item;

  @override
  State<OutgoingItemWidget> createState() => _OutgoingItemWidgetState();
}

class _OutgoingItemWidgetState extends State<OutgoingItemWidget> {
  OutgoingItem get item => widget.item;

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
        left: item.geometry.left,
        top: item.geometry.top,
        child: SizedBox(
          width: item.geometry.width,
          height: item.geometry.height,
          child: item.build(context),
        ),
      );
}
