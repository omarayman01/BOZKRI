import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../model/item_model.dart';
import '../../../model/party_balance_model.dart';
import '../../../model/payment_model.dart';
import '../../../model/supplier_model.dart';
import '../../database/local/daos/suppliers_dao.dart';
import '../../errors/failure.dart';
import '../../provider/items_cache_provider.dart';
import '../../repos/suppliers_repo.dart';
import 'supplier_detail_state.dart';

/// Loads one supplier's items, deals, payments and derived payable.
class SupplierDetailCubit extends Cubit<SupplierDetailState> {
  SupplierDetailCubit(this._repo) : super(const SupplierDetailState());

  final SuppliersRepo _repo;

  Future<void> load(int supplierId, {ItemsCacheProvider? itemsCache}) async {
    emit(state.copyWith(status: SupplierDetailStatus.loading, clearError: true));
    try {
      final SupplierModel? supplier = await _repo.getSupplier(supplierId);
      if (supplier == null) {
        emit(state.copyWith(
          status: SupplierDetailStatus.failure,
          errorMessage: 'This supplier no longer exists.',
        ));
        return;
      }

      final List<ItemModel> items = await _repo.getSupplierItems(supplierId);
      final List<SupplierTransactionSlice> transactions =
          await _repo.getSupplierTransactions(supplierId);
      final List<PaymentModel> payments =
          await _repo.getSupplierPayments(supplierId);
      final PartyBalanceModel balance =
          await _repo.getSupplierBalance(supplierId);

      itemsCache?.upsertAll(items);

      emit(state.copyWith(
        status: SupplierDetailStatus.success,
        supplier: supplier,
        items: items,
        transactions: transactions,
        payments: payments,
        balance: balance,
      ));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: SupplierDetailStatus.failure,
        errorMessage: failure.message,
      ));
    }
  }

  Future<void> refresh({ItemsCacheProvider? itemsCache}) async {
    final int? id = state.supplier?.id;
    if (id != null) await load(id, itemsCache: itemsCache);
  }
}
