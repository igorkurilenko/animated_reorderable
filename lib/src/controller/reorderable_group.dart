import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../animated_reorderable_controller.dart';
import '../animated_reorderable_group.dart';
import '../model/model.dart';
import '../util/scheduling.dart';
import 'held_item_sessions.dart';

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

  /// The list [item] is held in, while the layer shows it.
  AnimatedReorderableController? hostOf(OverlayedItem item) => _hosts[item];

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

  /// The list of the group that [point] is over, which takes the group's
  /// items. Lists of a group don't overlap.
  AnimatedReorderableController? memberAt(GlobalOffset point) => _members
      .where((x) => x.takesGroupItems)
      .where((x) => x.globalRect?.contains(point) ?? false)
      .firstOrNull;

  /// Moves the item [session] holds from its list to [to] at [index], if
  /// the app lets it: the app moves the item's data, then the two lists
  /// move their items, all in this call, so the app's data and the lists
  /// agree on every frame.
  bool moveHeldItem(
    DragSession session, {
    required AnimatedReorderableController to,
    required int index,
  }) {
    final from = session.host;
    final item = session.item;
    final fromPlace = (list: from.groupId!, index: item.index);
    final toPlace = (list: to.groupId!, index: index);
    final options = this.options();
    if (!(options.canMove?.call(fromPlace, toPlace) ?? true)) return false;

    options.onMove(fromPlace, toPlace);
    from.releaseHeldItem(item);
    to.adoptHeldItem(item, index: index, session: session);
    _hosts[item] = to;
    hostedChanges.notify();
    return true;
  }

  void dispose() {
    _disposed = true;
    hostedChanges.dispose();
  }
}
