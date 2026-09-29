import '../../model/item_model.dart';
import '../../model/party_balance_model.dart';
import '../../model/payment_model.dart';
import '../../model/supplier_model.dart';
import '../database/local/daos/suppliers_dao.dart';

abstract class SuppliersRepo {
  Future<List<SupplierModel>> getSuppliers({bool activeOnly = false});
  Future<SupplierModel?> getSupplier(int id);
  Future<int> addSupplier({
    required String name,
    String? phone,
    String? notes,
    bool isActive,
  });
  Future<void> updateSupplier(SupplierModel supplier);
  Future<void> deleteSupplier(int id);

  /// The seeded "بوزكري (بدون مورد)" supplier used when a car has no real
  /// supplier assigned.
  Future<int> getSystemSupplierId();

  Future<List<ItemModel>> getSupplierItems(int supplierId,
      {bool activeOnly = false});
  Future<List<SupplierTransactionSlice>> getSupplierTransactions(int supplierId);
  Future<List<PaymentModel>> getSupplierPayments(int supplierId);
  Future<PartyBalanceModel> getSupplierBalance(int supplierId);
}
