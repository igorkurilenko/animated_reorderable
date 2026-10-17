import 'package:flutter/widgets.dart';

typedef ChildCountGetter = int? Function();

class OverriddenSliverChildBuilderDelegate extends SliverChildBuilderDelegate {
  factory OverriddenSliverChildBuilderDelegate.override({
    required SliverChildDelegate delegate,
    required NullableIndexedWidgetBuilder overriddenChildBuilder,
    required ChildCountGetter overriddenChildCountGetter,
    ChildIndexGetter? fallbackChildIndexGetter,
  }) => OverriddenSliverChildBuilderDelegate(
    getChildBuilder(delegate),
    overriddenBuilder: overriddenChildBuilder,
    overriddenChildCountGetter: overriddenChildCountGetter,
    findChildIndexCallback:
        getChildIndexGetter(delegate) ?? fallbackChildIndexGetter,
    childCount: overriddenChildCountGetter(),
    addAutomaticKeepAlives: getAddAutomaticKeepAlives(delegate),
    addRepaintBoundaries: getAddRepaintBoundaries(delegate),
    addSemanticIndexes: getAddSemanticIndexes(delegate),
    semanticIndexCallback: getSemanticIndexCallback(delegate),
    semanticIndexOffset: getSemanticIndexOffset(delegate),
  );

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

NullableIndexedWidgetBuilder getChildBuilder(SliverChildDelegate delegate) =>
    switch (delegate) {
      SliverChildBuilderDelegate(builder: var b) => b,
      SliverChildListDelegate(children: var xs) => (_, index) => xs[index],
      _ => throw 'Not implemented for ${delegate.runtimeType}',
    };

int? getChildCount(SliverChildDelegate delegate) => switch (delegate) {
  SliverChildBuilderDelegate(childCount: var c) => c,
  SliverChildListDelegate(children: var xs) => xs.length,
  _ => throw 'Not implemented for ${delegate.runtimeType}',
};

ChildIndexGetter? getChildIndexGetter(SliverChildDelegate delegate) =>
    switch (delegate) {
      SliverChildBuilderDelegate(findChildIndexCallback: var g) => g,
      SliverChildListDelegate() => null,
      _ => throw 'Not implemented for ${delegate.runtimeType}',
    };

bool getAddAutomaticKeepAlives(SliverChildDelegate delegate) =>
    switch (delegate) {
      SliverChildBuilderDelegate(addAutomaticKeepAlives: var x) ||
      SliverChildListDelegate(addAutomaticKeepAlives: var x) => x,
      _ => throw 'Not implemented for ${delegate.runtimeType}',
    };

bool getAddRepaintBoundaries(SliverChildDelegate delegate) =>
    switch (delegate) {
      SliverChildBuilderDelegate(addRepaintBoundaries: var x) ||
      SliverChildListDelegate(addRepaintBoundaries: var x) => x,
      _ => throw 'Not implemented for ${delegate.runtimeType}',
    };

bool getAddSemanticIndexes(SliverChildDelegate delegate) => switch (delegate) {
  SliverChildBuilderDelegate(addSemanticIndexes: var x) ||
  SliverChildListDelegate(addSemanticIndexes: var x) => x,
  _ => throw 'Not implemented for ${delegate.runtimeType}',
};

SemanticIndexCallback getSemanticIndexCallback(SliverChildDelegate delegate) =>
    switch (delegate) {
      SliverChildBuilderDelegate(semanticIndexCallback: var x) ||
      SliverChildListDelegate(semanticIndexCallback: var x) => x,
      _ => throw 'Not implemented for ${delegate.runtimeType}',
    };

int getSemanticIndexOffset(SliverChildDelegate delegate) => switch (delegate) {
  SliverChildBuilderDelegate(semanticIndexOffset: var x) ||
  SliverChildListDelegate(semanticIndexOffset: var x) => x,
  _ => throw 'Not implemented for ${delegate.runtimeType}',
};
