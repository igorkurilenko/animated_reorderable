import 'collection_view_item.dart';
import 'outgoing_item.dart';
import 'overlayed_item.dart';

class ControllerModel {
  final _collectionViewItemById = <int, CollectionViewItem>{};
  final _overlayedItemById = <int, OverlayedItem>{};
  final _outgoingItemById = <int, OutgoingItem>{};

  Iterable<OutgoingItem> get outgoingItems => _outgoingItemById.values;

  Iterable<OverlayedItem> get overlayedItems => _overlayedItemById.values;
}
