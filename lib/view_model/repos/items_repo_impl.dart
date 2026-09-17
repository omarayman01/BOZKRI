import '../../model/item_model.dart';
import '../database/local/daos/items_dao.dart';
import '../errors/db_failure.dart';
import '../errors/error_handler.dart';
import 'items_repo.dart';

class ItemsRepoImpl implements ItemsRepo {
  const ItemsRepoImpl(this._dao);

  final ItemsDao _dao;

  @override
  Future<List<ItemModel>> getItems({bool activeOnly = false}) =>
      guard(() => _dao.getAll(activeOnly: activeOnly));

  @override
  Future<ItemModel?> getItem(int id) => guard(() => _dao.getById(id));

  @override
  Future<List<ItemModel>> getBySupplier(int supplierId) =>
      guard(() => _dao.getBySupplier(supplierId));

  @override
  Future<List<ItemModel>> getAvailableForSupplier(int supplierId) =>
      guard(() => _dao.getAvailableForSupplier(supplierId));

  @override
  Future<List<ItemModel>> getExpiringBefore(DateTime threshold) =>
      guard(() => _dao.getExpiringBefore(threshold));

  @override
  Future<int> addItem({
    required int itemTypeId,
    required int supplierId,
    required String label,
    double? defaultCost,
    double? defaultPrice,
    DateTime? expiryDate,
    bool isSingleUse = false,
    bool isAvailable = true,
    String? notes,
    bool isActive = true,
    Map<int, String> fieldValues = const <int, String>{},
  }) =>
      guard(() => _dao.createItem(
            itemTypeId: itemTypeId,
            supplierId: supplierId,
            label: label.trim(),
            defaultCost: defaultCost,
            defaultPrice: defaultPrice,
            expiryDate: expiryDate,
            isSingleUse: isSingleUse,
            isAvailable: isAvailable,
            notes: notes?.trim(),
            isActive: isActive,
            fieldValues: fieldValues,
          ));

  @override
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
    Map<int, String> fieldValues = const <int, String>{},
  }) =>
      guard(() => _dao.updateItem(
            id: id,
            itemTypeId: itemTypeId,
            supplierId: supplierId,
            label: label.trim(),
            defaultCost: defaultCost,
            defaultPrice: defaultPrice,
            expiryDate: expiryDate,
            isSingleUse: isSingleUse,
            isAvailable: isAvailable,
            notes: notes?.trim(),
            isActive: isActive,
            fieldValues: fieldValues,
          ));

  @override
  Future<void> deleteItem(int id) => guard(() async {
        final int usages = await _dao.countUsagesOf(id);
        if (usages > 0) {
          throw ConstraintFailure(
            'This item appears in $usages deal line(s). Deactivate it instead '
            'so past figures stay intact.',
          );
        }
        await _dao.deleteItem(id);
      });

  @override
  Future<void> setAvailability(int itemId, bool available) =>
      guard(() => _dao.setAvailability(itemId, available));
}
