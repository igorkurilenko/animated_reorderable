import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

/// The surface an item's ink paints on, such as a `ListTile`'s tile color
/// or an `InkWell`'s splash.
///
/// Ink paints on the closest [Material] above it, and the app's is under
/// the list: it paints the ink where the item was as it last painted, so
/// the ink stays behind as the item moves on a layer of its own, and
/// neither fades nor scales with it. On a transparent [Material] of its
/// own, the item paints its ink on its own layer.
///
/// The item's text keeps the style it inherits, which a [Material] would
/// replace with its own.
class InkSurface extends StatefulWidget {
  const InkSurface({super.key, required this.child});

  final Widget child;

  @override
  State<InkSurface> createState() => _InkSurfaceState();
}

class _InkSurfaceState extends State<InkSurface> {
  /// The text style the item inherits, which the surface passes on.
  DefaultTextStyle? _text;

  /// The surface, built again only as the inherited text style changes. An
  /// item builds again on each change that moves it, and only its child
  /// builds then, under the surface.
  late Widget _surface;

  /// Where the child goes under the surface.
  Element? _content;

  @override
  void didUpdateWidget(InkSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.child, oldWidget.child)) _content?.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    final text = DefaultTextStyle.of(context);
    if (!_isSame(text, _text)) {
      _text = text;
      _surface = Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: text.style,
          textAlign: text.textAlign,
          softWrap: text.softWrap,
          overflow: text.overflow,
          maxLines: text.maxLines,
          textWidthBasis: text.textWidthBasis,
          textHeightBehavior: text.textHeightBehavior,
          child: _Content(this),
        ),
      );
    }
    return _surface;
  }

  static bool _isSame(DefaultTextStyle a, DefaultTextStyle? b) =>
      b != null &&
      a.style == b.style &&
      a.textAlign == b.textAlign &&
      a.softWrap == b.softWrap &&
      a.overflow == b.overflow &&
      a.maxLines == b.maxLines &&
      a.textWidthBasis == b.textWidthBasis &&
      a.textHeightBehavior == b.textHeightBehavior;
}

/// Builds the surface's child, when it changes.
class _Content extends StatelessWidget {
  const _Content(this.surface);

  final _InkSurfaceState surface;

  @override
  Widget build(BuildContext context) {
    surface._content = context as Element;
    return surface.widget.child;
  }
}
