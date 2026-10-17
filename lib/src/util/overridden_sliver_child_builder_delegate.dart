import 'package:flutter/widgets.dart';

typedef ChildCountGetter = int? Function();

class OverriddenSliverChildBuilderDelegate extends SliverChildBuilderDelegate {
  factory OverriddenSliverChildBuilderDelegate.override({
    required SliverChildDelegate delegate,
    required NullableIndexedWidgetBuilder overriddenChildBuilder,
    required ChildCountGetter overriddenChildCountGetter,
    ChildIndexGetter? fallbackChildIndexGetter,
  }) {
    final settings = childrenDelegateSettingsOf(delegate);
    return OverriddenSliverChildBuilderDelegate(
      settings.builder,
      overriddenBuilder: overriddenChildBuilder,
      overriddenChildCountGetter: overriddenChildCountGetter,
      findChildIndexCallback:
          settings.findChildIndexCallback ?? fallbackChildIndexGetter,
      childCount: overriddenChildCountGetter(),
      addAutomaticKeepAlives: settings.addAutomaticKeepAlives,
      addRepaintBoundaries: settings.addRepaintBoundaries,
      addSemanticIndexes: settings.addSemanticIndexes,
      semanticIndexCallback: settings.semanticIndexCallback,
      semanticIndexOffset: settings.semanticIndexOffset,
    );
  }

  OverriddenSliverChildBuilderDelegate(
    super.builder, {
    this.overriddenBuilder,
    this.overriddenChildCountGetter,
    super.findChildIndexCallback,
    super.childCount,
    super.addAutomaticKeepAlives = true,
    super.addRepaintBoundaries = true,
    super.addSemanticIndexes = true,
    super.semanticIndexCallback,
    super.semanticIndexOffset = 0,
  });

  NullableIndexedWidgetBuilder? overriddenBuilder;
  ChildCountGetter? overriddenChildCountGetter;

  @override
  int? get childCount => overriddenChildCountGetter != null
      ? overriddenChildCountGetter!.call()
      : super.childCount;

  @override
  NullableIndexedWidgetBuilder get builder =>
      overriddenBuilder ?? originalBuilder;

  NullableIndexedWidgetBuilder get originalBuilder => super.builder;
}

/// The settings of a [SliverChildBuilderDelegate] or a
/// [SliverChildListDelegate].
typedef ChildrenDelegateSettings = ({
  NullableIndexedWidgetBuilder builder,
  int? childCount,
  ChildIndexGetter? findChildIndexCallback,
  bool addAutomaticKeepAlives,
  bool addRepaintBoundaries,
  bool addSemanticIndexes,
  SemanticIndexCallback semanticIndexCallback,
  int semanticIndexOffset,
});

ChildrenDelegateSettings childrenDelegateSettingsOf(
  SliverChildDelegate delegate,
) => switch (delegate) {
  SliverChildBuilderDelegate() => (
    builder: delegate.builder,
    childCount: delegate.childCount,
    findChildIndexCallback: delegate.findChildIndexCallback,
    addAutomaticKeepAlives: delegate.addAutomaticKeepAlives,
    addRepaintBoundaries: delegate.addRepaintBoundaries,
    addSemanticIndexes: delegate.addSemanticIndexes,
    semanticIndexCallback: delegate.semanticIndexCallback,
    semanticIndexOffset: delegate.semanticIndexOffset,
  ),
  SliverChildListDelegate(:final children) => (
    builder: (_, index) => children[index],
    childCount: children.length,
    // It has none, so the fallback finds its children.
    findChildIndexCallback: null,
    addAutomaticKeepAlives: delegate.addAutomaticKeepAlives,
    addRepaintBoundaries: delegate.addRepaintBoundaries,
    addSemanticIndexes: delegate.addSemanticIndexes,
    semanticIndexCallback: delegate.semanticIndexCallback,
    semanticIndexOffset: delegate.semanticIndexOffset,
  ),
  _ => throw UnsupportedError('${delegate.runtimeType} is not supported'),
};
