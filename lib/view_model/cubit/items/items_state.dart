import 'package:equatable/equatable.dart';

import '../../../model/item_model.dart';

enum ItemsStatus { initial, loading, success, failure }

class ItemsState extends Equatable {
  const ItemsState({
    this.status = ItemsStatus.initial,
    this.items = const <ItemModel>[],
    this.supplierId,
    this.errorMessage,
    this.isSaving = false,
  });

  final ItemsStatus status;
  final List<ItemModel> items;

  /// When set, [items] holds only this supplier's items.
  final int? supplierId;
  final String? errorMessage;
  final bool isSaving;

  bool get isLoading => status == ItemsStatus.loading;
  bool get isFailure => status == ItemsStatus.failure;
  bool get isEmpty => status == ItemsStatus.success && items.isEmpty;

  ItemsState copyWith({
    ItemsStatus? status,
    List<ItemModel>? items,
    int? supplierId,
    String? errorMessage,
    bool? isSaving,
    bool clearError = false,
  }) {
    return ItemsState(
      status: status ?? this.status,
      items: items ?? this.items,
      supplierId: supplierId ?? this.supplierId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSaving: isSaving ?? this.isSaving,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[status, items, supplierId, errorMessage, isSaving];
}
