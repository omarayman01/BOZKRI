import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../model/item_type_field_model.dart';
import '../../../model/item_type_model.dart';
import '../../errors/failure.dart';
import '../../provider/items_cache_provider.dart';
import '../../repos/item_types_repo.dart';
import 'item_types_state.dart';

/// Manages item types and their dynamic field schemas (Settings screen).
/// Adding a type or a field here changes the item form with no code edits.
class ItemTypesCubit extends Cubit<ItemTypesState> {
  ItemTypesCubit(this._repo) : super(const ItemTypesState());

  final ItemTypesRepo _repo;

  Future<void> load(ItemsCacheProvider cache) async {
    emit(state.copyWith(status: ItemTypesStatus.loading, clearError: true));
    try {
      final List<ItemTypeModel> types = await _repo.getTypes();
      cache.setTypes(types);
      emit(state.copyWith(status: ItemTypesStatus.success, types: types));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: ItemTypesStatus.failure,
        errorMessage: failure.message,
      ));
    }
  }

  void selectType(int? id) => id == null
      ? emit(state.copyWith(clearSelection: true))
      : emit(state.copyWith(selectedTypeId: id));

  Future<bool> addType(ItemsCacheProvider cache, String name) =>
      _mutate(cache, () => _repo.addType(name));

  Future<bool> renameType(ItemsCacheProvider cache, int id, String name) =>
      _mutate(cache, () => _repo.renameType(id, name));

  Future<bool> deleteType(ItemsCacheProvider cache, int id) async {
    final bool ok = await _mutate(cache, () => _repo.deleteType(id));
    if (ok && state.selectedTypeId == id) {
      emit(state.copyWith(clearSelection: true));
    }
    return ok;
  }

  Future<bool> addField(
    ItemsCacheProvider cache, {
    required int itemTypeId,
    required String fieldName,
    required FieldType fieldType,
    bool isRequired = false,
  }) {
    final int nextOrder = state.types
            .firstWhere(
              (ItemTypeModel t) => t.id == itemTypeId,
              orElse: () => ItemTypeModel(
                id: itemTypeId,
                name: '',
                createdAt: DateTime.now(),
              ),
            )
            .fields
            .length;

    return _mutate(
      cache,
      () => _repo.addField(
        itemTypeId: itemTypeId,
        fieldName: fieldName,
        fieldType: fieldType,
        isRequired: isRequired,
        sortOrder: nextOrder,
      ),
    );
  }

  Future<bool> updateField(ItemsCacheProvider cache, ItemTypeFieldModel field) =>
      _mutate(cache, () => _repo.updateField(field));

  Future<bool> deleteField(ItemsCacheProvider cache, int fieldId) =>
      _mutate(cache, () => _repo.deleteField(fieldId));

  Future<bool> reorderFields(
          ItemsCacheProvider cache, List<int> orderedFieldIds) =>
      _mutate(cache, () => _repo.reorderFields(orderedFieldIds));

  Future<bool> _mutate(
      ItemsCacheProvider cache, Future<void> Function() action) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await action();
      final List<ItemTypeModel> types = await _repo.getTypes();
      cache.setTypes(types);
      emit(state.copyWith(
        types: types,
        status: ItemTypesStatus.success,
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
