import 'package:flutter/widgets.dart';

/// Builds with [builder] as a [LayoutBuilder] does, and first calls
/// [onResize] when its extent across [scrollDirection] changed since the
/// last time. Both run while the widget lays out, before the subtree from
/// [builder] does.
class CrossAxisResizeListener extends StatefulWidget {
  const CrossAxisResizeListener({
    super.key,
    required this.scrollDirection,
    required this.onResize,
    required this.builder,
  });

  final Axis scrollDirection;
  final VoidCallback onResize;
  final WidgetBuilder builder;

  @override
  State<CrossAxisResizeListener> createState() =>
      _CrossAxisResizeListenerState();
}

class _CrossAxisResizeListenerState extends State<CrossAxisResizeListener> {
  double? _crossAxisExtent;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final crossAxisExtent = switch (widget.scrollDirection) {
        Axis.vertical => constraints.maxWidth,
        Axis.horizontal => constraints.maxHeight,
      };
      final previousCrossAxisExtent = _crossAxisExtent;
      _crossAxisExtent = crossAxisExtent;
      if (previousCrossAxisExtent != null &&
          previousCrossAxisExtent != crossAxisExtent) {
        widget.onResize();
      }
      return widget.builder(context);
    },
  );
}
