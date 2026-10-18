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

  /// The widget built last for each item, kept while the view's own
  /// delegate stays the same. The package builds the view again after each
  /// change, and an item that keeps its index needs nothing new then.
  final _built = <Key, ItemWidget>{};
  SliverChildDelegate? _viewDelegate;
  ChildrenDelegateSettings? _viewSettings;

  /// Builds the child at an index as the wrapped view would.
  NullableIndexedWidgetBuilder get originalBuilder => _delegate.originalBuilder;

  /// The wrapped view's [delegate], which builds item widgets instead and
  /// takes its child count from the registry.
  SliverChildDelegate overrideChildrenDelegate(SliverChildDelegate delegate) {
    if (identical(delegate, _viewDelegate)) {
      _built.removeWhere((key, _) => items.itemBy(key: key) == null);
    } else {
      // The app built its view again, so any item may show something new.
      _built.clear();
      _viewDelegate = delegate;
      _viewSettings = childrenDelegateSettingsOf(delegate);
    }
    return _delegate = OverriddenSliverChildBuilderDelegate.override(
      delegate: delegate,
      overriddenChildBuilder: _build,
      overriddenChildCountGetter: () => items.itemCount,
      fallbackChildIndexGetter: items.childIndexGetter(),
      // Each item widget paints on a layer of its own already, which it
      // moves in place on, and gives its semantic index on that layer, so
      // that a pointer finds the item where it shows as it moves.
      addRepaintBoundaries: false,
      addSemanticIndexes: false,
    );
  }

  /// The semantic index the view's delegate gives the [child] at [index],
  /// or null for none.
  int? semanticIndexOf(Widget child, int index) {
    final settings = _viewSettings;
    if (settings == null || !settings.addSemanticIndexes) return null;
    final semanticIndex = settings.semanticIndexCallback(child, index);
    return semanticIndex == null
        ? null
        : semanticIndex + settings.semanticIndexOffset;
  }

  Widget _build(BuildContext context, int index) {
    final item = items.ensureItemAt(index: index);
    final built = _built[item.key];
    if (built != null &&
        built.index == index &&
        built.childKey == item.childKey &&
        built.builder == item.builder.build &&
        built.placeholderSize == item.placeholderSize &&
        built.entrance == item.entrance) {
      // It doesn't build again, but the host reconciles it all the same.
      if (items.renderedItemBy(key: item.key) case final renderedItem?) {
        host.didBuildItem(renderedItem);
      }
      return built;
    }

    return _built[item.key] = ItemWidget(
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
