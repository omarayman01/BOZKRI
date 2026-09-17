import 'package:equatable/equatable.dart';

import '../../../model/item_type_model.dart';

enum ItemTypesStatus { initial, loading, success, failure }

class ItemTypesState extends Equatable {
  const ItemTypesState({
    this.status = ItemTypesStatus.initial,
    this.types = const <ItemTypeModel>[],
    this.selectedTypeId,
    this.errorMessage,
    this.isSaving = false,
  });

  final ItemTypesStatus status;
  final List<ItemTypeModel> types;
  final int? selectedTypeId;
  final String? errorMessage;
  final bool isSaving;

  bool get isLoading => status == ItemTypesStatus.loading;
  bool get isFailure => status == ItemTypesStatus.failure;
  bool get isEmpty => status == ItemTypesStatus.success && types.isEmpty;

  ItemTypeModel? get selectedType {
    if (selectedTypeId == null) return null;
    for (final ItemTypeModel t in types) {
      if (t.id == selectedTypeId) return t;
    }
    return null;
  }

  ItemTypesState copyWith({
    ItemTypesStatus? status,
    List<ItemTypeModel>? types,
    int? selectedTypeId,
    String? errorMessage,
    bool? isSaving,
    bool clearError = false,
    bool clearSelection = false,
  }) {
    return ItemTypesState(
      status: status ?? this.status,
      types: types ?? this.types,
      selectedTypeId:
          clearSelection ? null : (selectedTypeId ?? this.selectedTypeId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSaving: isSaving ?? this.isSaving,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[status, types, selectedTypeId, errorMessage, isSaving];
}
