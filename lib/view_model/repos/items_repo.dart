import '../../model/item_model.dart';

abstract class ItemsRepo {
  Future<List<ItemModel>> getItems({bool activeOnly = false});
  Future<ItemModel?> getItem(int id);
  Future<List<ItemModel>> getBySupplier(int supplierId);

  /// Picker source: active, unexpired, and reusable or still available.
  Future<List<ItemModel>> getAvailableForSupplier(int supplierId);

  Future<List<ItemModel>> getExpiringBefore(DateTime threshold);

  Future<int> addItem({
    required int itemTypeId,
    required int supplierId,
    required String label,
    double? defaultCost,
    double? defaultPrice,
    DateTime? expiryDate,
    bool isSingleUse,
    bool isAvailable,
    String? notes,
    bool isActive,
    Map<int, String> fieldValues,
    String? updatedBy,
  });

  Future<void> updateItem({
    required int id,
    required int itemTypeId,
    required int supplierId,
    required String label,
    double? defaultCost,
    double? defaultPrice,
    DateTime? expiryDate,
    required bool isSingleUse,
    required bool isAvailable,
    String? notes,
    required bool isActive,
    Map<int, String> fieldValues,
    String? updatedBy,
  });

  Future<void> deleteItem(int id);
  Future<void> setAvailability(int itemId, bool available);
}
