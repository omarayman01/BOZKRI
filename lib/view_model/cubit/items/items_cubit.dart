import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../model/item_model.dart';
import '../../errors/failure.dart';
import '../../provider/expiry_provider.dart';
import '../../provider/items_cache_provider.dart';
import '../../repos/items_repo.dart';
import 'items_state.dart';

/// CRUD for dynamic items and their field values. Writes into
/// [ItemsCacheProvider] and refreshes [ExpiryProvider] after every change.
class ItemsCubit extends Cubit<ItemsState> {
  ItemsCubit(this._repo) : super(const ItemsState());

  final ItemsRepo _repo;

  Future<void> loadAll(
    ItemsCacheProvider cache,
    ExpiryProvider expiry, {
    bool activeOnly = false,
  }) async {
    emit(state.copyWith(status: ItemsStatus.loading, clearError: true));
    try {
      final List<ItemModel> items = await _repo.getItems(activeOnly: activeOnly);
      cache.setItems(items);
      expiry.setItems(items);
      emit(state.copyWith(status: ItemsStatus.success, items: items));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: ItemsStatus.failure,
        errorMessage: failure.message,
      ));
    }
  }

  Future<void> loadForSupplier(
    int supplierId,
    ItemsCacheProvider cache,
    ExpiryProvider expiry,
  ) async {
    emit(state.copyWith(
      status: ItemsStatus.loading,
      supplierId: supplierId,
      clearError: true,
    ));
    try {
      final List<ItemModel> items = await _repo.getBySupplier(supplierId);
      cache.upsertAll(items);
      expiry.setItems(cache.items);
      emit(state.copyWith(status: ItemsStatus.success, items: items));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: ItemsStatus.failure,
        errorMessage: failure.message,
      ));
    }
  }

  /// Returns the created item on success (so a caller — e.g. the deal
  /// builder's inline "new car" action — can select it immediately), or
  /// null on failure (check [state].errorMessage).
  Future<ItemModel?> addItem(
    ItemsCacheProvider cache,
    ExpiryProvider expiry, {
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
    String? updatedBy,
  }) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final int id = await _repo.addItem(
        itemTypeId: itemTypeId,
        supplierId: supplierId,
        label: label,
        defaultCost: defaultCost,
        defaultPrice: defaultPrice,
        expiryDate: expiryDate,
        isSingleUse: isSingleUse,
        isAvailable: isAvailable,
        notes: notes,
        isActive: isActive,
        fieldValues: fieldValues,
        updatedBy: updatedBy,
      );
      final ItemModel? created = await _repo.getItem(id);
      if (created != null) {
        cache.upsert(created);
        expiry.setItems(cache.items);
        emit(state.copyWith(
          items: <ItemModel>[...state.items, created],
          status: ItemsStatus.success,
          isSaving: false,
        ));
      } else {
        emit(state.copyWith(isSaving: false));
      }
      return created;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return null;
    }
  }

  Future<bool> updateItem(
    ItemsCacheProvider cache,
    ExpiryProvider expiry, {
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
    String? updatedBy,
  }) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.updateItem(
        id: id,
        itemTypeId: itemTypeId,
        supplierId: supplierId,
        label: label,
        defaultCost: defaultCost,
        defaultPrice: defaultPrice,
        expiryDate: expiryDate,
        isSingleUse: isSingleUse,
        isAvailable: isAvailable,
        notes: notes,
        isActive: isActive,
        fieldValues: fieldValues,
        updatedBy: updatedBy,
      );
      final ItemModel? updated = await _repo.getItem(id);
      if (updated != null) {
        cache.upsert(updated);
        expiry.setItems(cache.items);
        emit(state.copyWith(
          items: state.items
              .map((ItemModel i) => i.id == id ? updated : i)
              .toList(),
          status: ItemsStatus.success,
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

  Future<bool> deleteItem(
      ItemsCacheProvider cache, ExpiryProvider expiry, int id) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.deleteItem(id);
      cache.remove(id);
      expiry.setItems(cache.items);
      emit(state.copyWith(
        items: state.items.where((ItemModel i) => i.id != id).toList(),
        status: ItemsStatus.success,
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
