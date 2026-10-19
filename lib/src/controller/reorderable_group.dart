import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../animated_reorderable_controller.dart';
import '../animated_reorderable_group.dart';
import '../model/model.dart';
import '../options.dart';
import '../util/scheduling.dart';

/// The lists of an [AnimatedReorderableGroup], and the items held in any of
/// them, which its layer shows above them all so that they can go from one
/// list to another.
class ReorderableGroup implements SharedOverlaySpace {
  ReorderableGroup({required this.options});

  /// The latest group widget, with the app's callbacks.
  final ValueGetter<AnimatedReorderableGroup> options;

  final _members = <AnimatedReorderableController>[];

  /// The list each item the layer shows is held in.
  final _hosts = <OverlayedItem, AnimatedReorderableController>{};

  /// Notifies when the layer shows an item more or less, or an item goes
  /// to another list.
  final hostedChanges = ChangeSignal();

  RenderBox? Function()? _layerBox;
  var _disposed = false;

  Iterable<OverlayedItem> get hostedItems => _hosts.keys;

  /// How an item flies from one list's look to another's.
  FlightOptions get flightOptions => options().flight;

  /// The list [item] is held in, while the layer shows it.
  AnimatedReorderableController? hostOf(OverlayedItem item) => _hosts[item];

  /// Where the list [item] is held in is in the layer, or null while the
  /// list doesn't show.
  Rect? listBoundsOf(OverlayedItem item) {
    final list = _hosts[item]?.globalRect;
    if (list == null) return null;
    return globalToLocal(GlobalOffset(list.topLeft)) & list.size;
  }

  /// The group's lists, in the order they joined it: the order of the
  /// tree, which is the order a screen reader reads them in.
  Iterable<AnimatedReorderableController> get members => _members;

  /// The list with the id [list], as [ReorderOptions.groupId] gives it.
  AnimatedReorderableController? memberWith(Object list) =>
      _members.where((x) => x.groupId == list).firstOrNull;

  void join(AnimatedReorderableController member) => _members.add(member);

  /// The items held in [member] go with it: it disposes them.
  void leave(AnimatedReorderableController member) {
    _members.remove(member);
    final gone = [
      for (final MapEntry(key: item, value: host) in _hosts.entries)
        if (host == member) item,
    ];
    if (gone.isEmpty) return;
    gone.forEach(_hosts.remove);
    // A list leaves as it unmounts, while the tree is locked.
    addPostFrame(() {
      if (!_disposed) hostedChanges.notify();
    });
  }

  void attachLayer(RenderBox? Function() box) => _layerBox = box;

  void detachLayer() => _layerBox = null;

  RenderBox get _box => _layerBox!()!;

  @override
  OverlayOffset globalToLocal(GlobalOffset point) =>
      OverlayOffset(_box.globalToLocal(point));

  @override
  GlobalOffset localToGlobal(OverlayOffset point) =>
      GlobalOffset(_box.localToGlobal(point));

  @override
  Size get size => _box.size;

  /// Shows [item], held in [host], from now on.
  void host(OverlayedItem item, AnimatedReorderableController host) {
    _hosts[item] = host;
    hostedChanges.notify();
  }

  @override
  void unhost(OverlayedItem item) {
    if (_hosts.remove(item) != null) hostedChanges.notify();
  }

  /// Moves the items held in the group's lists by [delta] in the layer.
  void shiftHeldItems(Offset delta) {
    for (final MapEntry(key: item, value: host) in _hosts.entries) {
      if (host.registry.isDragged(key: item.key)) item.shift(delta);
    }
  }

  /// The list of the group that [point] is over, which takes the group's
  /// items. Lists of a group don't overlap.
  AnimatedReorderableController? memberAt(GlobalOffset point) => _members
      .where((x) => x.takesGroupItems)
      .where((x) => x.globalRect?.contains(point) ?? false)
      .firstOrNull;

  /// Moves the held [item] from the list [from] to [to] at [index], if the
  /// app lets it: the app moves the item's data, then the two lists move
  /// their items, all in this call, so the app's data and the lists agree
  /// on every frame.
  bool moveHeldItem(
    OverlayedItem item, {
    required AnimatedReorderableController from,
    required AnimatedReorderableController to,
    required int index,
    bool held = true,
  }) {
    final fromPlace = (list: from.groupId!, index: item.index);
    final toPlace = (list: to.groupId!, index: index);
    if (!canMove(fromPlace, toPlace)) return false;

    options().onMove(fromPlace, toPlace);
    from.releaseHeldItem(item);
    to.adoptHeldItem(item, index: index, held: held);
    host(item, to);
    return true;
  }

  /// Whether the app lets an item go from [from] to [to].
  bool canMove(ItemPlace from, ItemPlace to) =>
      options().canMove?.call(from, to) ?? true;

  /// The index an item at [index] of another list goes to in [to] as a
  /// screen reader moves it: the same, or the end of a shorter list.
  int moveIndexIn(AnimatedReorderableController to, int index) =>
      math.min(index, to.registry.itemCount ?? 0);

  /// Moves the item at [index] of [from] to [to], as a screen reader does:
  /// to [moveIndexIn] there. It goes as a drag that lets it go there does,
  /// through the layer, and flies to the new list's look.
  ///
  /// The layer shows it for a frame first, so it flies from its look as
  /// that frame painted it.
  void moveItem({
    required AnimatedReorderableController from,
    required int index,
    required AnimatedReorderableController to,
  }) {
    final item = from.liftForMove(index);
    if (item == null) return;
    addPostFrame(() {
      // It went elsewhere meanwhile, or the lists did.
      if (_disposed || hostOf(item) != from) return;
      final moved =
          _members.contains(to) &&
          to.takesGroupItems &&
          moveHeldItem(
            item,
            from: from,
            to: to,
            index: moveIndexIn(to, item.index),
            held: false,
          );
      if (!moved) from.dropMovedItem(item);
    });
  }

  void dispose() {
    _disposed = true;
    hostedChanges.dispose();
  }
}
