import 'package:freezed_annotation/freezed_annotation.dart';

part 'item_type_field_model.freezed.dart';

/// The data type a dynamic field holds. Values are persisted as text and
/// interpreted according to this enum.
enum FieldType {
  text,
  number,
  date,
  bool;

  static FieldType fromName(String value) => FieldType.values.firstWhere(
        (FieldType e) => e.name == value,
        orElse: () => FieldType.text,
      );
}

@freezed
class ItemTypeFieldModel with _$ItemTypeFieldModel {
  const factory ItemTypeFieldModel({
    required int id,
    required int itemTypeId,
    required String fieldName,
    required FieldType fieldType,
    @Default(false) bool isRequired,
    @Default(0) int sortOrder,
  }) = _ItemTypeFieldModel;
}
