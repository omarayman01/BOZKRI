import 'package:freezed_annotation/freezed_annotation.dart';

import 'item_field_value_model.dart';

part 'item_model.freezed.dart';

@freezed
class ItemModel with _$ItemModel {
  const ItemModel._();

  const factory ItemModel({
    required int id,
    required int itemTypeId,
    required int supplierId,
    required String label,
    double? defaultCost,
    double? defaultPrice,
    DateTime? expiryDate,
    @Default(false) bool isSingleUse,
    @Default(true) bool isAvailable,
    String? notes,
    @Default(true) bool isActive,
    required DateTime createdAt,
    @Default(<ItemFieldValueModel>[]) List<ItemFieldValueModel> fieldValues,
    String? itemTypeName,
    String? supplierName,
  }) = _ItemModel;

  bool get isReusable => !isSingleUse;

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  /// Selectable in the deal line editor.
  bool get isSelectable =>
      isActive && !isExpired && (isReusable || isAvailable);
}
