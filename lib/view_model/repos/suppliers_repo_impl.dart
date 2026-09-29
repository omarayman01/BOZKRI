import '../../model/item_model.dart';
import '../../model/party_balance_model.dart';
import '../../model/payment_model.dart';
import '../../model/supplier_model.dart';
import '../database/local/app_database.dart';
import '../database/local/daos/suppliers_dao.dart';
import '../errors/db_failure.dart';
import '../errors/error_handler.dart';
import 'suppliers_repo.dart';

class SuppliersRepoImpl implements SuppliersRepo {
  const SuppliersRepoImpl(this._dao, this._db);

  final SuppliersDao _dao;
  final AppDatabase _db;

  @override
  Future<List<SupplierModel>> getSuppliers({bool activeOnly = false}) =>
      guard(() => _dao.getAll(activeOnly: activeOnly));

  @override
  Future<SupplierModel?> getSupplier(int id) => guard(() => _dao.getById(id));

  @override
  Future<int> addSupplier({
    required String name,
    String? phone,
    String? notes,
    bool isActive = true,
  }) =>
      guard(() => _dao.insertSupplier(
            name: name.trim(),
            phone: phone?.trim(),
            notes: notes?.trim(),
            isActive: isActive,
          ));

  @override
  Future<void> updateSupplier(SupplierModel supplier) => guard(() async {
        if (supplier.isSystemSupplier) {
          throw const ConstraintFailure(
            'This is the system\'s "no supplier" placeholder and cannot be '
            'edited.',
          );
        }
        await _dao.updateSupplier(supplier);
      });

  @override
  Future<int> getSystemSupplierId() => guard(_dao.getSystemSupplierId);

  @override
  Future<void> deleteSupplier(int id) => guard(() async {
        final int systemSupplierId = await _dao.getSystemSupplierId();
        if (id == systemSupplierId) {
          throw const ConstraintFailure(
            'This is the system\'s "no supplier" placeholder and cannot be '
            'deleted.',
          );
        }
        final int items = await _dao.countItemsFor(id);
        if (items > 0) {
          throw ConstraintFailure(
            'This supplier still has $items item(s). Deactivate the supplier '
            'instead, or remove their items first.',
          );
        }
        await _db.syncLinksDao.recordPendingDeleteIfLinked('suppliers', id);
        await _dao.deleteSupplier(id);
      });

  @override
  Future<List<ItemModel>> getSupplierItems(int supplierId,
          {bool activeOnly = false}) =>
      guard(() => _dao.getSupplierItems(supplierId, activeOnly: activeOnly));

  @override
  Future<List<SupplierTransactionSlice>> getSupplierTransactions(
          int supplierId) =>
      guard(() => _dao.getSupplierTransactions(supplierId));

  @override
  Future<List<PaymentModel>> getSupplierPayments(int supplierId) =>
      guard(() => _dao.getSupplierPayments(supplierId));

  @override
  Future<PartyBalanceModel> getSupplierBalance(int supplierId) =>
      guard(() => _dao.getSupplierBalance(supplierId));
}
