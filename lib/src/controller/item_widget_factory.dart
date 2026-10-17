import 'package:flutter/widgets.dart';

import '../model/model.dart';
import '../util/overridden_sliver_child_builder_delegate.dart';
import '../widget/item_widget.dart';

/// Builds the wrapped view's children as item widgets, which keep their
/// place in the list while the overlay shows their items.
class ItemWidgetFactory {
  ItemWidgetFactory({required this.items, required this.host});

  final ItemRegistry items;
  final ItemHost host;
  late OverriddenSliverChildBuilderDelegate _delegate;

  /// Builds the child at an index as the wrapped view would.
  NullableIndexedWidgetBuilder get originalBuilder => _delegate.originalBuilder;

  /// The wrapped view's [delegate], which builds item widgets instead and
  /// takes its child count from the registry.
  SliverChildDelegate overrideChildrenDelegate(SliverChildDelegate delegate) =>
      _delegate = OverriddenSliverChildBuilderDelegate.override(
        delegate: delegate,
        overriddenChildBuilder: _build,
        overriddenChildCountGetter: () => items.itemCount,
        fallbackChildIndexGetter: items.childIndexGetter(),
      );

  Widget _build(BuildContext context, int index) {
    final item = items.ensureItemAt(index: index);

    return ItemWidget(
      key: item.key,
      index: index,
      childKey: item.childKey,
      builder: item.builder.build,
      placeholderSize: item.placeholderSize,
      entrance: item.entrance,
      host: host,
    );
  }
}
