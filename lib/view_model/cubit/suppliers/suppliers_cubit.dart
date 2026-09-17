import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../model/supplier_model.dart';
import '../../errors/failure.dart';
import '../../provider/suppliers_cache_provider.dart';
import '../../repos/suppliers_repo.dart';
import 'suppliers_state.dart';

/// Owns supplier list CRUD, mirroring results into [SuppliersCacheProvider].
class SuppliersCubit extends Cubit<SuppliersState> {
  SuppliersCubit(this._repo) : super(const SuppliersState());

  final SuppliersRepo _repo;

  Future<void> load(SuppliersCacheProvider cache,
      {bool activeOnly = false}) async {
    emit(state.copyWith(status: SuppliersStatus.loading, clearError: true));
    try {
      final List<SupplierModel> suppliers =
          await _repo.getSuppliers(activeOnly: activeOnly);
      cache.setSuppliers(suppliers);
      emit(state.copyWith(
          status: SuppliersStatus.success, suppliers: suppliers));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: SuppliersStatus.failure,
        errorMessage: failure.message,
      ));
    }
  }

  void search(String query) => emit(state.copyWith(query: query));

  Future<bool> addSupplier(
    SuppliersCacheProvider cache, {
    required String name,
    String? phone,
    String? notes,
    bool isActive = true,
  }) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final int id = await _repo.addSupplier(
        name: name,
        phone: phone,
        notes: notes,
        isActive: isActive,
      );
      final SupplierModel? created = await _repo.getSupplier(id);
      if (created != null) {
        cache.upsert(created);
        final List<SupplierModel> updated =
            <SupplierModel>[...state.suppliers, created]
              ..sort((SupplierModel a, SupplierModel b) =>
                  a.name.compareTo(b.name));
        emit(state.copyWith(
          suppliers: updated,
          status: SuppliersStatus.success,
          isSaving: false,
        ));
      } else {
        emit(state.copyWith(isSaving: false));
      }
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  Future<bool> updateSupplier(
      SuppliersCacheProvider cache, SupplierModel supplier) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.updateSupplier(supplier);
      cache.upsert(supplier);
      emit(state.copyWith(
        suppliers: state.suppliers
            .map((SupplierModel s) => s.id == supplier.id ? supplier : s)
            .toList(),
        status: SuppliersStatus.success,
        isSaving: false,
      ));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  Future<bool> deleteSupplier(SuppliersCacheProvider cache, int id) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.deleteSupplier(id);
      cache.remove(id);
      emit(state.copyWith(
        suppliers:
            state.suppliers.where((SupplierModel s) => s.id != id).toList(),
        status: SuppliersStatus.success,
        isSaving: false,
      ));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));
}
