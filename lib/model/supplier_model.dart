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

    /// True only for the single seeded "بوزكري (بدون مورد)" row used as the
    /// supplier of a car with no real supplier assigned — never created,
    /// renamed, or deleted by an admin.
    @Default(false) bool isSystemSupplier,
  }) = _SupplierModel;
}
