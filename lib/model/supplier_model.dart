import 'package:freezed_annotation/freezed_annotation.dart';

part 'supplier_model.freezed.dart';

@freezed
class SupplierModel with _$SupplierModel {
  const factory SupplierModel({
    required int id,
    required String name,
    String? phone,
    String? notes,
    @Default(true) bool isActive,
    required DateTime createdAt,
  }) = _SupplierModel;
}
