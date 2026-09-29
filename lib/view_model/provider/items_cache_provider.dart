import 'package:flutter/foundation.dart';

import '../../model/item_model.dart';
import '../../model/item_type_model.dart';
import '../utils/item_category.dart';

/// Shared in-memory items and item types, used by the supplier items tab and
/// the deal line editor's item cascade.
class ItemsCacheProvider extends ChangeNotifier {
  List<ItemModel> _items = <ItemModel>[];
  List<ItemTypeModel> _types = <ItemTypeModel>[];

  List<ItemModel> get items => List<ItemModel>.unmodifiable(_items);
  List<ItemTypeModel> get types => List<ItemTypeModel>.unmodifiable(_types);

  ItemModel? byId(int id) {
    for (final ItemModel i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  ItemTypeModel? typeById(int id) {
    for (final ItemTypeModel t in _types) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Every selectable car, across every supplier (including cars with no
  /// real supplier) — used by the deal builder's car picker when no
  /// supplier has been chosen, so the admin can pick a car directly without
  /// first narrowing by supplier.
  List<ItemModel> get availableCars {
    final Set<int> carTypeIds = _types
        .where((ItemTypeModel t) => categoryOf(t) == ItemCategory.car)
        .map((ItemTypeModel t) => t.id)
        .toSet();
    return _items
        .where((ItemModel i) => i.isSelectable && carTypeIds.contains(i.itemTypeId))
        .toList();
  }

  List<ItemModel> forSupplier(int supplierId) =>
      _items.where((ItemModel i) => i.supplierId == supplierId).toList();

  /// Selectable in the deal line editor: active, unexpired, and either
  /// reusable or a still-available single-use item.
  List<ItemModel> availableForSupplier(int supplierId) => _items
      .where((ItemModel i) => i.supplierId == supplierId && i.isSelectable)
      .toList();

  void setItems(List<ItemModel> items) {
    _items = List<ItemModel>.from(items);
    notifyListeners();
  }

  void setTypes(List<ItemTypeModel> types) {
    _types = List<ItemTypeModel>.from(types);
    notifyListeners();
  }

  void upsert(ItemModel item) {
    final int index = _items.indexWhere((ItemModel i) => i.id == item.id);
    if (index >= 0) {
      _items[index] = item;
    } else {
      _items.add(item);
    }
    _items.sort((ItemModel a, ItemModel b) => a.label.compareTo(b.label));
    notifyListeners();
  }

  void upsertAll(List<ItemModel> items) {
    for (final ItemModel item in items) {
      final int index = _items.indexWhere((ItemModel i) => i.id == item.id);
      if (index >= 0) {
        _items[index] = item;
      } else {
        _items.add(item);
      }
    }
    _items.sort((ItemModel a, ItemModel b) => a.label.compareTo(b.label));
    notifyListeners();
  }

  /// Reflects a single-use consume/release without a round trip to the DB.
  void setAvailability(int itemId, bool available) {
    final int index = _items.indexWhere((ItemModel i) => i.id == itemId);
    if (index < 0) return;
    if (!_items[index].isSingleUse) return;
    _items[index] = _items[index].copyWith(isAvailable: available);
    notifyListeners();
  }

  void remove(int id) {
    _items.removeWhere((ItemModel i) => i.id == id);
    notifyListeners();
  }

  void clear() {
    _items = <ItemModel>[];
    _types = <ItemTypeModel>[];
    notifyListeners();
  }
}
